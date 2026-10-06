using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

class PlexLoginView extends TextView {
    private var d_pinId = null;
    private var d_code = null;
    private var d_pollTimer = null;
    private var d_polling = false;
    private var d_pollCount = 0;

    function initialize() {
        TextView.initialize("Connecting to Plex...");
    }

    function onShow() {
        if (d_pinId == null) {
            requestPin();
        }
    }

    function onHide() {
        stopPolling();
        Communications.cancelAllRequests();
    }

    function requestPin() {
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
        if ((responseCode != 200) && (responseCode != 201)) {
            showError("Plex login failed", responseCode);
            return;
        }
        if (!(data instanceof Lang.Dictionary)
            || (data["id"] == null)
            || (data["code"] == null)) {
            showError("Invalid Plex response", responseCode);
            return;
        }

        d_pinId = data["id"];
        d_code = data["code"];
        setText("Open plex.tv/link\nand enter:\n\n" + d_code);

        if (System.getDeviceSettings().phoneConnected) {
            Communications.openWebPage(
                "https://plex.tv/link/",
                { "pin" => d_code },
                null
            );
        }

        d_pollTimer = new Timer.Timer();
        d_pollTimer.start(method(:pollPin), 3000, true);
    }

    function pollPin() {
        if (d_polling || (d_pinId == null)) {
            return;
        }
        d_pollCount += 1;
        if (d_pollCount > 100) {
            stopPolling();
            setText("Plex login expired.\nGo back and try again.");
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
        d_polling = false;
        if (responseCode != 200) {
            showError("Plex login check failed", responseCode);
            return;
        }
        if (!(data instanceof Lang.Dictionary)) {
            showError("Invalid Plex response", responseCode);
            return;
        }

        var token = data["authToken"];
        if (token == null) {
            return;
        }

        stopPolling();
        setText("Signed in.\nFinding Plex server...");
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
        if (responseCode != 200) {
            showError("Server discovery failed", responseCode);
            return;
        }

        var resources = data;
        if ((data instanceof Lang.Dictionary) && (data["resources"] != null)) {
            resources = data["resources"];
        }
        if (!(resources instanceof Lang.Array)) {
            showError("No Plex servers found", responseCode);
            return;
        }

        var selected = selectServer(resources);
        if (selected == null) {
            showError("No reachable Plex server", responseCode);
            return;
        }

        PlexAccount.saveServer(
            selected["name"],
            selected["uri"],
            selected["token"],
            accountToken,
            selected["artworkUri"]
        );
        System.println("Plex artwork connection: "
            + ((selected["artworkUri"] != null) ? selected["artworkUri"] : "none; using local fallback"));
        setText("Connected to Plex:\n" + selected["name"]);
    }

    function selectServer(resources) {
        var best = null;
        var bestScore = 1000;

        for (var resourceIndex = 0; resourceIndex < resources.size(); resourceIndex += 1) {
            var resource = resources[resourceIndex];
            if (!(resource instanceof Lang.Dictionary)
                || !providesServer(resource["provides"])
                || !(resource["connections"] instanceof Lang.Array)) {
                continue;
            }

            var ownedPenalty = (resource["owned"] == true) ? 0 : 100;
            var connections = resource["connections"];
            for (var connectionIndex = 0; connectionIndex < connections.size(); connectionIndex += 1) {
                var connection = connections[connectionIndex];
                if (!(connection instanceof Lang.Dictionary) || (connection["uri"] == null)) {
                    continue;
                }

                var score = ownedPenalty;
                score += (connection["protocol"] == "https") ? 0 : 30;
                score += (connection["local"] == true) ? 0 : 10;
                score += (connection["relay"] == true) ? 20 : 0;
                if (score < bestScore) {
                    bestScore = score;
                    best = {
                        "name" => resource["name"],
                        "uri" => connection["uri"],
                        "token" => resource["accessToken"],
                        "artworkUri" => findArtworkConnection(connections),
                    };
                }
            }
        }
        return best;
    }

    function findArtworkConnection(connections) {
        var relay = null;
        for (var index = 0; index < connections.size(); index += 1) {
            var connection = connections[index];
            if (!(connection instanceof Lang.Dictionary)
                || (connection["uri"] == null)
                || (connection["protocol"] != "https")
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
        setText(message + "\nError " + responseCode);
    }
}
