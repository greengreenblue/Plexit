using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

// Keep stale callbacks from selecting a newer connection candidate.
class PlexLoginProbe {
    private var d_view;
    private var d_attempt;
    private var d_started;
    function initialize(view, attempt) {
        d_view = view;
        d_attempt = attempt;
        d_started = System.getTimer();
    }
    function response(code, data) {
        Plexit.Utils.log("Plex probe #" + d_attempt + " Garmin response: " + code
            + " after " + (System.getTimer() - d_started) + " ms");
        d_view.onProbeResponse(d_attempt, code, data);
    }

}

class PlexInternetConfirmation extends WatchUi.ConfirmationDelegate {
    private var d_view;
    function initialize(view) { ConfirmationDelegate.initialize(); d_view = view; }
    function onResponse(response) { d_view.onInternetChoice(response == WatchUi.CONFIRM_YES); }
}

class PlexHomeNetworkConfirmation extends WatchUi.ConfirmationDelegate {
    private var d_view;
    function initialize(view) { ConfirmationDelegate.initialize(); d_view = view; }
    function onResponse(response) { d_view.onHomeNetworkChoice(response == WatchUi.CONFIRM_YES); }
}

class PlexLoginView extends TextView {
    private var d_loginRequestPending = false;
    private var d_probeTimer = null;
    private var d_probeDeadline = 0;
    private var d_cancelDeadline = 0;
    private var d_probeCancelled = false;
    private var d_probeLabel = null;
    private var d_setupWaiting = false;
    private var d_setupResources = null;
    private var d_setupToken = null;
    private var d_setupIds = [];
    private var d_setupIndex = 0;
    private var d_pinId = null;
    private var d_code = null;
    private var d_pollTimer = null;
    private var d_polling = false;
    private var d_pollCount = 0;
    private var d_resources = null;
    private var d_accountToken = null;
    private var d_candidate = null;
    private var d_triedUris = [];
    private var d_active = false;
    private var d_refreshOnly = false;
    private var d_probeAttempt = 0;
    private var d_retryTimer = null;
    private var d_waitUntil = 0;
    private var d_restartAfterRecovery = false;
    private var d_internetTrialServer = null;
    private var d_offerServer = null;
    private var d_confirmationOpen = false;
    private var d_confirmationHandled = false;

    function refreshServers() {
        d_active = true;
        var token = Application.Storage.getValue(Plexit.Storage.PLEX_ACCOUNT_TOKEN);
        if (token == null) { requestPin(); return; }
        d_refreshOnly = true;
        discoverServers(token);
    }

    function initialize() {
        TextView.initialize(WatchUi.loadResource(Rez.Strings.ConnectingPlex));
    }

    function onShow() {
        d_active = true;
        if (d_setupWaiting || d_confirmationOpen || (d_retryTimer != null)) { return; }
        if (d_confirmationHandled) { d_confirmationHandled = false; return; }
        var token = Application.Storage.getValue(Plexit.Storage.PLEX_ACCOUNT_TOKEN);
        if ((token != null) && !PlexAccount.isConnected()) {
            setText(WatchUi.loadResource(Rez.Strings.FindingPlexServer));
            discoverServers(token);
        } else if (d_pinId == null) {
            requestPin();
        } else {
            startPolling();
        }
    }

    function onHide() {
        Plexit.Utils.log("Plex login onHide: cancelling all network requests");
        d_active = false;
        stopRetryTimer();
        d_resources = null;
        d_accountToken = null;
        d_candidate = null;
        stopPolling();
        stopProbe();
        if (d_loginRequestPending) {
            d_loginRequestPending = false;
            cancelLoginRequests();
        }
    }

    function requestPin() {
        d_pinId = null;
        d_code = null;
        d_pollCount = 0;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => PlexAccount.headers(null),
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        options[:headers].put("Content-Type", Communications.REQUEST_CONTENT_TYPE_URL_ENCODED);

        d_loginRequestPending = true;
        Communications.makeWebRequest(
            "https://plex.tv/api/v2/pins",
            { "strong" => "false" },
            options,
            method(:onPinCreated)
        );
    }

    function onPinCreated(responseCode, data) {
        d_loginRequestPending = false;
        if (!d_active) { return; }
        if ((responseCode != 200) && (responseCode != 201)) {
            showError(WatchUi.loadResource(Rez.Strings.PlexLoginFailed), responseCode);
            return;
        }
        if (!(data instanceof Lang.Dictionary)
            || (data["id"] == null)
            || (data["code"] == null)) {
            showError(WatchUi.loadResource(Rez.Strings.InvalidPlexResponse), responseCode);
            return;
        }

        d_pinId = data["id"];
        d_code = data["code"];
        setText(Plexit.I18n.text(Rez.Strings.PlexLinkInstructions, [d_code]));

        if (System.getDeviceSettings().phoneConnected) {
            Communications.openWebPage(
                "https://plex.tv/link/",
                { "pin" => d_code },
                null
            );
        }

        startPolling();
    }

    function startPolling() {
        stopPolling();
        d_pollTimer = new Timer.Timer();
        d_pollTimer.start(method(:pollPin), 3000, true);
    }

    function pollPin() {
        if (!d_active || d_polling || (d_pinId == null)) {
            return;
        }
        d_pollCount += 1;
        if (d_pollCount > 100) {
            stopPolling();
            setText(WatchUi.loadResource(Rez.Strings.PlexLoginExpired));
            return;
        }

        d_polling = true;
        d_loginRequestPending = true;
        Communications.makeWebRequest(
            "https://plex.tv/api/v2/pins/" + d_pinId,
            { "code" => d_code },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => PlexAccount.headers(null),
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            method(:onPinPolled)
        );
    }

    function onPinPolled(responseCode, data) {
        d_loginRequestPending = false;
        if (!d_active) { return; }
        d_polling = false;
        // Keep the same code after a temporary phone/network outage.
        if (PlexServerRequest.canRetry(responseCode) || (responseCode == 429)) { return; }
        if (responseCode != 200) {
            showError(WatchUi.loadResource(Rez.Strings.PlexLoginCheckFailed), responseCode);
            return;
        }
        if (!(data instanceof Lang.Dictionary)) {
            showError(WatchUi.loadResource(Rez.Strings.InvalidPlexResponse), responseCode);
            return;
        }

        var token = data["authToken"];
        if (!(token instanceof Lang.String) || (token.length() == 0)) {
            return;
        }

        // Authorization succeeds independently of server reachability.
        Application.Storage.setValue(Plexit.Storage.PLEX_ACCOUNT_TOKEN, token);
        stopPolling();
        setText(WatchUi.loadResource(Rez.Strings.FindingPlexServer));
        discoverServers(token);
    }

    function discoverServers(accountToken) {
        d_loginRequestPending = true;
        Communications.makeWebRequest(
            "https://clients.plex.tv/api/v2/resources",
            {
                "includeHttps" => 1,
                "includeRelay" => 1,
                "includeIPv6" => 0,
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => PlexAccount.headers(accountToken),
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                :context => accountToken,
            },
            method(:onServersDiscovered)
        );
    }

    function onServersDiscovered(responseCode, data, accountToken) {
        d_loginRequestPending = false;
        if (!d_active) { return; }
        if ((responseCode == 401) || (responseCode == 403)) {
            Application.Storage.deleteValue(Plexit.Storage.PLEX_ACCOUNT_TOKEN);
            d_refreshOnly = false;
            requestPin();
            return;
        }
        if (responseCode != 200) {
            showError(WatchUi.loadResource(Rez.Strings.ServerDiscoveryFailed), responseCode);
            return;
        }

        var resources = data;
        if ((data instanceof Lang.Dictionary) && (data["resources"] != null)) {
            resources = data["resources"];
        }
        if (!(resources instanceof Lang.Array)) {
            showError(WatchUi.loadResource(Rez.Strings.NoPlexServers), responseCode);
            return;
        }

        d_resources = resources;
        d_accountToken = accountToken;
        rememberDiscoveredServers(resources);
        if (d_refreshOnly) {
            var current = Application.Storage.getValue(Plexit.Storage.PLEX_SERVER_ID);
            if (current == null) { current = Application.Storage.getValue(Plexit.Storage.PLEX_LEGACY_SERVER_ID); }
            var preferred = PlexServers.preferredServer(PlexServers.all(), current);
            if (preferred != null) { PlexServers.select(preferred); }
            d_resources = null;
            d_accountToken = null;
            setText(WatchUi.loadResource(Rez.Strings.ServerListUpdated));
            return;
        }
        d_setupIds = [];
        for (var i = 0; i < resources.size(); i += 1) {
            var r = resources[i];
            if (!(r instanceof Lang.Dictionary)) { continue; }
            var record = PlexServers.get(r["clientIdentifier"]);
            if ((record != null) && (record["token"] != null) && (record["connectionModeChosen"] != true)) {
                d_setupIds.add(record["id"]);
            }
        }
        d_setupIndex = 0;
        d_setupResources = resources;
        d_setupToken = accountToken;
        d_setupWaiting = true;
        continueConnectionSetup();
    }

    function continueConnectionSetup() {
        stopRetryTimer();
        d_active = true;
        if (d_setupIndex < d_setupIds.size()) {
            var name = PlexServers.name(d_setupIds[d_setupIndex]);
            showHomeNetworkQuestion(name);
            return;
        }
        d_setupWaiting = false;
        d_resources = d_setupResources;
        d_accountToken = d_setupToken;
        d_setupResources = null;
        d_setupToken = null;
        d_triedUris = [];
        tryServerConnection();
    }

    function showHomeNetworkQuestion(name) {
        if (name.length() > 18) { name = name.substring(0, 17) + "…"; }
        WatchUi.pushView(new WatchUi.Confirmation(Plexit.I18n.text(Rez.Strings.ServerOnHomeNetwork, [name])),
            new PlexHomeNetworkConfirmation(self), WatchUi.SLIDE_IMMEDIATE);
    }

    function onHomeNetworkChoice(home) {
        PlexServers.setConnectionMode(d_setupIds[d_setupIndex], home
            ? PlexServers.CONNECTION_AUTO : PlexServers.CONNECTION_INTERNET);
        d_setupIndex += 1;
        d_retryTimer = new Timer.Timer();
        d_retryTimer.start(method(:continueConnectionSetup), 100, false);
    }

    function compatibilityEnabled() {
        return (d_candidate != null) && connectionModeFor(d_candidate["serverId"])
            .equals(PlexServers.CONNECTION_COMPATIBILITY);
    }

    function connectionModeFor(id) {
        if ((id != null) && (d_internetTrialServer != null) && id.equals(d_internetTrialServer)) {
            return PlexServers.CONNECTION_INTERNET;
        }
        return PlexServers.connectionMode(PlexServers.get(id));
    }

    function stopRetryTimer() {
        if (d_retryTimer != null) { d_retryTimer.stop(); d_retryTimer = null; }
    }

    function waitForConnection() {
        if (!d_active) { stopRetryTimer(); return; }
        var remaining = (d_waitUntil - connectionClock() + 999) / 1000;
        if (remaining <= 0) {
            stopRetryTimer();
            if (d_restartAfterRecovery) { d_restartAfterRecovery = false; restartConnection(); }
            else { tryServerConnection(); }
            return;
        }
        setText(Plexit.I18n.text(Rez.Strings.ConnectionRecovering, [remaining]));
    }

    function onInternetChoice(enabled) {
        d_confirmationOpen = false;
        d_confirmationHandled = true;
        d_active = true;
        if (!enabled) {
            showError(WatchUi.loadResource(Rez.Strings.NoReachablePlexServer), 0);
            return;
        }
        d_internetTrialServer = d_offerServer;
        // The preceding failed probes can leave Garmin transport busy. Allow
        // the verified recovery interval before the internet-only trial.
        d_restartAfterRecovery = true;
        d_waitUntil = connectionClock() + 60000;
        d_retryTimer = new Timer.Timer();
        d_retryTimer.start(method(:waitForConnection), 1000, true);
        waitForConnection();
    }

    function restartConnection() {
        stopRetryTimer();
        if (!d_active) { return; }
        var token = Application.Storage.getValue(Plexit.Storage.PLEX_ACCOUNT_TOKEN);
        if (token == null) { requestPin(); return; }
        setText(WatchUi.loadResource(Rez.Strings.FindingPlexServer));
        discoverServers(token);
    }

    function connectionClock() { return System.getTimer(); }
    function cancelLoginRequests() { Communications.cancelAllRequests(); }
    function sendProbe(uri, token, callback) {
        Communications.makeWebRequest(uri + "/library/sections", null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => PlexAccount.headers(token),
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        }, callback);
    }

    function probeAddressLabel() {
        var local = false;
        var position = 0;
        var total = 0;
        for (var i = 0; i < d_resources.size(); i += 1) {
            var r = d_resources[i];
            if (!(r instanceof Lang.Dictionary) || (r["clientIdentifier"] == null)
                || !r["clientIdentifier"].equals(d_candidate["serverId"])) { continue; }
            var connections = r["connections"];
            for (var j = 0; j < connections.size(); j += 1) {
                var c = connections[j];
                if ((c instanceof Lang.Dictionary) && (c["uri"] != null)
                    && c["uri"].equals(d_candidate["uri"])) { local = c["local"] == true; }
            }
            var urls = serverConnectionUrls(r);
            for (var k = 0; k < urls.size(); k += 1) {
                var urlLocal = false;
                for (var n = 0; n < connections.size(); n += 1) {
                    var c = connections[n];
                    if ((c instanceof Lang.Dictionary) && (c["uri"] != null)
                        && c["uri"].equals(urls[k])) { urlLocal = c["local"] == true; }
                }
                if (urlLocal == local) {
                    total += 1;
                    if (urls[k].equals(d_candidate["uri"])) { position = total; }
                }
            }
        }
        return Plexit.I18n.text(local ? Rez.Strings.TryLocalAddress : Rez.Strings.TryRemoteAddress, [position, total]);
    }

    function updateProbeCountdown() {
        if (!d_active || !d_loginRequestPending) { return; }
        var now = connectionClock();
        if (d_probeCancelled) {
            if (now >= d_cancelDeadline) {
                stopProbe();
                Plexit.Utils.log("Plex cancellation callback missing; no further request will be sent");
                showError(WatchUi.loadResource(Rez.Strings.ConnectionCancelFailed), 0);
                return;
            }
            setText(Plexit.I18n.text(Rez.Strings.ConnectionCancelling, [(d_cancelDeadline - now + 999) / 1000]));
            return;
        }
        if (now >= d_probeDeadline) {
            d_probeCancelled = true;
            d_cancelDeadline = now + 5000;
            Plexit.Utils.log("Plex probe deadline reached; cancelling and waiting up to 5 s for callback");
            cancelLoginRequests();
            return;
        }
        setText(d_probeLabel + "\n" + Plexit.I18n.text(Rez.Strings.ConnectionStepDeadline,
            [(d_probeDeadline + 5000 - now + 999) / 1000]));
    }

    function tryServerConnection() {
        if (!d_active) { return; }
        d_candidate = selectServer(d_resources, d_triedUris);
        if (d_candidate == null) {
            d_resources = null;
            d_accountToken = null;
            showError(WatchUi.loadResource(Rez.Strings.NoReachablePlexServer), 0);
            if ((d_internetTrialServer == null) && (d_offerServer != null)
                && connectionModeFor(d_offerServer).equals(PlexServers.CONNECTION_AUTO)) {
                d_confirmationOpen = true;
                WatchUi.pushView(new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.TryInternetConnection)),
                    new PlexInternetConfirmation(self), WatchUi.SLIDE_IMMEDIATE);
            }
            return;
        }

        d_offerServer = d_candidate["serverId"];
        d_triedUris.add(d_candidate["uri"]);
        Plexit.Utils.log("Plex connection probe: " + d_candidate["uri"] + "/library/sections");
        // Discovery advertises addresses; it does not prove they are reachable
        // from this phone/watch. Probe with the server token before saving one.
        d_probeAttempt += 1;
        d_probeLabel = probeAddressLabel();
        var local = PlexServers.isLocalConnection(PlexServers.get(d_candidate["serverId"]), d_candidate["uri"]);
        d_probeDeadline = connectionClock() + (local ? 2000 : 8000);
        d_probeCancelled = false;
        d_probeTimer = new Timer.Timer();
        d_probeTimer.start(method(:updateProbeCountdown), 1000, true);
        var probe = new PlexLoginProbe(self, d_probeAttempt);
        d_loginRequestPending = true;
        sendProbe(d_candidate["uri"], d_candidate["token"], probe.method(:response));
        updateProbeCountdown();
    }

    function continueProbe() {
        stopRetryTimer();
        if (d_active) { tryServerConnection(); }
    }

    function stopProbe() {
        d_probeAttempt += 1;
        if (d_probeTimer != null) { d_probeTimer.stop(); d_probeTimer = null; }
    }

    function onProbeResponse(attempt, code, data) {
        if (!d_active || (attempt != d_probeAttempt)) { return; }
        d_loginRequestPending = false;
        var expired = d_probeCancelled;
        stopProbe();
        onServerConnectionChecked((expired && code != 200) ? Communications.NETWORK_REQUEST_TIMED_OUT : code, data);
    }

    function onServerConnectionChecked(responseCode, data) {
        if (!d_active) { return; }
        if ((responseCode != 200) || !(data instanceof Lang.Dictionary)
            || !(data["MediaContainer"] instanceof Lang.Dictionary)) {
            Plexit.Utils.log("Plex connection probe failed: " + responseCode + " at "
                + ((d_candidate != null) ? d_candidate["uri"] : "unknown") + "/library/sections");
            if (compatibilityEnabled() && (selectServer(d_resources, d_triedUris) != null)) {
                Plexit.Utils.log("Plex connection recovery: waiting 60 seconds before next address");
                d_waitUntil = connectionClock() + 60000;
                d_retryTimer = new Timer.Timer();
                d_retryTimer.start(method(:waitForConnection), 1000, true);
                waitForConnection();
            } else {
                d_retryTimer = new Timer.Timer();
                d_retryTimer.start(method(:continueProbe), 100, false);
            }
            return;
        }

        var selected = d_candidate;
        if (selected == null) {
            showError(WatchUi.loadResource(Rez.Strings.NoReachablePlexServer), responseCode);
            return;
        }

        Plexit.Utils.log("Plex connection probe succeeded: " + selected["uri"] + "/library/sections");
        PlexAccount.saveServer(
            selected["name"],
            selected["uri"],
            selected["token"],
            d_accountToken,
            selected["artworkUri"],
            selected["urls"],
            selected["serverId"]
        );
        if ((d_internetTrialServer != null) && d_internetTrialServer.equals(selected["serverId"])) {
            PlexServers.setConnectionMode(selected["serverId"], PlexServers.CONNECTION_INTERNET);
            d_internetTrialServer = null;
        }
        Plexit.Utils.log("Plex artwork connection: "
            + ((selected["artworkUri"] != null) ? selected["artworkUri"] : "none; using local fallback"));
        setText(Plexit.I18n.text(Rez.Strings.ConnectedPlex, [selected["name"]]));
        d_resources = null;
        d_accountToken = null;
        d_candidate = null;
    }

    function selectServer(resources, triedUris) {
        var best = null;
        var bestScore = 1000;

        for (var resourceIndex = 0; resourceIndex < resources.size(); resourceIndex += 1) {
            var resource = resources[resourceIndex];
            if (!(resource instanceof Lang.Dictionary)
                || !providesServer(resource["provides"])
                || !(resource["accessToken"] instanceof Lang.String)
                || !(resource["connections"] instanceof Lang.Array)) {
                continue;
            }

            var id = resource["clientIdentifier"];
            if ((d_internetTrialServer != null) && ((id == null) || !id.equals(d_internetTrialServer))) { continue; }
            var mode = connectionModeFor(id);
            var ownedPenalty = (resource["owned"] == true) ? 0 : 100;
            var connections = resource["connections"];
            for (var connectionIndex = 0; connectionIndex < connections.size(); connectionIndex += 1) {
                var connection = connections[connectionIndex];
                if (!(connection instanceof Lang.Dictionary) || (connection["uri"] == null)
                    || (triedUris.indexOf(connection["uri"]) >= 0)) {
                    continue;
                }

                if (mode.equals(PlexServers.CONNECTION_INTERNET) && (connection["local"] == true)) { continue; }
                var score = ownedPenalty;
                score += ((connection["protocol"] instanceof Lang.String)
                    && connection["protocol"].equals("https")) ? 0 : 30;
                // Prefer direct local addresses, then remote, then relay.
                score += (connection["local"] == true) ? 0 : 10;
                score += (connection["relay"] == true) ? 20 : 0;
                if (score < bestScore) {
                    bestScore = score;
                    best = {
                        "name" => resource["name"],
                        "uri" => connection["uri"],
                        "token" => resource["accessToken"],
                        "artworkUri" => findArtworkConnection(connections),
                        "urls" => serverConnectionUrls(resource),
                        "serverId" => resource["clientIdentifier"],
                    };
                }
            }
        }
        return best;
    }

    function rememberDiscoveredServers(resources) {
        var records = [];
        for (var i = 0; i < resources.size(); i += 1) {
            var resource = resources[i];
            if (!(resource instanceof Lang.Dictionary) || !providesServer(resource["provides"])
                || !(resource["clientIdentifier"] instanceof Lang.String)
                || !(resource["accessToken"] instanceof Lang.String)
                || !(resource["connections"] instanceof Lang.Array)) { continue; }
            var urls = serverConnectionUrls(resource);
            if (urls.size() == 0) { continue; }
            records.add({ "id" => resource["clientIdentifier"], "name" => resource["name"],
                "token" => resource["accessToken"], "urls" => urls, "uri" => urls[0],
                "localUrls" => PlexServers.localConnectionUrls(resource["connections"]),
                "artwork" => findArtworkConnection(resource["connections"]),
                "custom" => null, "enabled" => true, "status" => "unknown" });
        }
        PlexServers.remember(records);
    }

    function serverConnectionUrls(resource) {
        var urls = [];
        // Use the same ranking as initial selection, but restrict candidates
        // to this resource so a retry can never switch to a different server.
        var candidate = selectServerWithoutUrls(resource, urls);
        while (candidate != null) {
            urls.add(candidate);
            candidate = selectServerWithoutUrls(resource, urls);
        }
        return urls;
    }

    function selectServerWithoutUrls(resource, tried) {
        var best = null;
        var bestScore = 1000;
        var connections = resource["connections"];
        for (var i = 0; i < connections.size(); i += 1) {
            var connection = connections[i];
            if (!(connection instanceof Lang.Dictionary)
                || !(connection["uri"] instanceof Lang.String)) { continue; }
            var used = false;
            for (var j = 0; j < tried.size(); j += 1) {
                if (tried[j].equals(connection["uri"])) { used = true; break; }
            }
            if (used) { continue; }
            var protocol = connection["protocol"];
            var score = ((protocol instanceof Lang.String) && protocol.equals("https")) ? 0 : 30;
            // Prefer direct local addresses, then remote, then relay.
            score += (connection["local"] == true) ? 0 : 10;
            score += (connection["relay"] == true) ? 20 : 0;
            if (score < bestScore) { best = connection["uri"]; bestScore = score; }
        }
        return best;
    }

    function findArtworkConnection(connections) {
        var relay = null;
        for (var index = 0; index < connections.size(); index += 1) {
            var connection = connections[index];
            if (!(connection instanceof Lang.Dictionary)
                || (connection["uri"] == null)
                || !(connection["protocol"] instanceof Lang.String)
                || !connection["protocol"].equals("https")
                || (connection["local"] == true)) {
                continue;
            }
            if (connection["relay"] != true) {
                return connection["uri"];
            }
            relay = connection["uri"];
        }
        return relay;
    }

    function providesServer(provides) {
        if (!(provides instanceof Lang.String)) {
            return false;
        }
        return provides.find("server") != null;
    }

    function stopPolling() {
        if (d_pollTimer != null) {
            d_pollTimer.stop();
            d_pollTimer = null;
        }
        d_polling = false;
    }

    function showError(message, responseCode) {
        stopPolling();
        setText(message + "\n" + Plexit.I18n.text(Rez.Strings.ErrorCode, [responseCode]));
    }
}

class PlexServerRefreshView extends PlexLoginView {
    private var d_started = false;
    function initialize() { PlexLoginView.initialize(); }
    function onShow() {
        if (!d_started) { d_started = true; refreshServers(); }
    }
}
