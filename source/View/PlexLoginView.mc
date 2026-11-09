using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

// Bind each probe response to its attempt so timed-out requests cannot
// select the candidate belonging to a newer request.
class PlexLoginProbe {
    private var d_view;
    private var d_attempt;
    function initialize(view, attempt) { d_view = view; d_attempt = attempt; }
    function response(code, data) { d_view.onProbeResponse(d_attempt, code, data); }
    function expired() { response(Communications.NETWORK_REQUEST_TIMED_OUT, null); }
}

class PlexLoginView extends TextView {
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
    private var d_probeTimer = null;
    private var d_probeAttempt = 0;

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
        d_active = false;
        d_resources = null;
        d_accountToken = null;
        d_candidate = null;
        stopPolling();
        stopProbe();
        Communications.cancelAllRequests();
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

        Communications.makeWebRequest(
            "https://plex.tv/api/v2/pins",
            { "strong" => "false" },
            options,
            method(:onPinCreated)
        );
    }

    function onPinCreated(responseCode, data) {
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
        d_triedUris = [];
        tryServerConnection();
    }

    function tryServerConnection() {
        if (!d_active) { return; }
        d_candidate = selectServer(d_resources, d_triedUris);
        if (d_candidate == null) {
            d_resources = null;
            d_accountToken = null;
            showError(WatchUi.loadResource(Rez.Strings.NoReachablePlexServer), 0);
            return;
        }

        d_triedUris.add(d_candidate["uri"]);
        System.println("Plex connection probe: " + d_candidate["uri"] + "/library/sections");
        // Discovery advertises addresses; it does not prove they are reachable
        // from this phone/watch. Probe with the server token before saving one.
        d_probeAttempt += 1;
        var probe = new PlexLoginProbe(self, d_probeAttempt);
        d_probeTimer = new Timer.Timer();
        d_probeTimer.start(probe.method(:expired), 8000, false);
        Communications.makeWebRequest(
            d_candidate["uri"] + "/library/sections",
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => PlexAccount.headers(d_candidate["token"]),
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            },
            probe.method(:response)
        );
    }

    function stopProbe() {
        d_probeAttempt += 1;
        if (d_probeTimer != null) { d_probeTimer.stop(); d_probeTimer = null; }
    }

    function onProbeResponse(attempt, code, data) {
        if (!d_active || (attempt != d_probeAttempt)) { return; }
        stopProbe();
        onServerConnectionChecked(code, data);
    }

    function onServerConnectionChecked(responseCode, data) {
        if (!d_active) { return; }
        if ((responseCode != 200) || !(data instanceof Lang.Dictionary)
            || !(data["MediaContainer"] instanceof Lang.Dictionary)) {
            System.println("Plex connection probe failed: " + responseCode + " at "
                + ((d_candidate != null) ? d_candidate["uri"] : "unknown") + "/library/sections");
            tryServerConnection();
            return;
        }

        var selected = d_candidate;
        if (selected == null) {
            showError(WatchUi.loadResource(Rez.Strings.NoReachablePlexServer), responseCode);
            return;
        }

        System.println("Plex connection probe succeeded: " + selected["uri"] + "/library/sections");
        PlexAccount.saveServer(
            selected["name"],
            selected["uri"],
            selected["token"],
            d_accountToken,
            selected["artworkUri"],
            selected["urls"],
            selected["serverId"]
        );
        System.println("Plex artwork connection: "
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

            var ownedPenalty = (resource["owned"] == true) ? 0 : 100;
            var connections = resource["connections"];
            for (var connectionIndex = 0; connectionIndex < connections.size(); connectionIndex += 1) {
                var connection = connections[connectionIndex];
                if (!(connection instanceof Lang.Dictionary) || (connection["uri"] == null)
                    || (triedUris.indexOf(connection["uri"]) >= 0)) {
                    continue;
                }

                var score = ownedPenalty;
                score += ((connection["protocol"] instanceof Lang.String)
                    && connection["protocol"].equals("https")) ? 0 : 30;
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
