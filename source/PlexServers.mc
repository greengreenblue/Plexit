using Toybox.Application;
using Toybox.Lang;
using Plexit.Storage;

module PlexServers {
    function all() {
        var records = Application.Storage.getValue(Storage.PLEX_SERVERS);
        if (records instanceof Lang.Array) { return records; }
        // Upgrade the existing single-server account without changing any media IDs.
        var id = Application.Storage.getValue(Storage.PLEX_SERVER_ID);
        var token = Application.Storage.getValue(Storage.PLEX_SERVER_TOKEN);
        var uri = Application.Storage.getValue(Storage.PLEX_SERVER_URL);
        if ((id != null) && (token != null) && (uri != null)) {
            if (Application.Storage.getValue(Storage.PLEX_LEGACY_SERVER_ID) == null) {
                Application.Storage.setValue(Storage.PLEX_LEGACY_SERVER_ID, id);
            }
            return [{ "id" => id, "name" => Application.Storage.getValue(Storage.PLEX_SERVER_NAME),
                "token" => token, "uri" => uri, "urls" => Application.Storage.getValue(Storage.PLEX_SERVER_URLS),
                "artwork" => Application.Storage.getValue(Storage.PLEX_ARTWORK_URL),
                "custom" => Application.Storage.getValue(Storage.PLEX_CUSTOM_SERVER_URL),
                "enabled" => true, "status" => "unknown" }];
        }
        return [];
    }

    function findIn(records, id) {
        if (!(id instanceof Lang.String)) { return null; }
        for (var i = 0; i < records.size(); i += 1) {
            if ((records[i]["id"] instanceof Lang.String) && records[i]["id"].equals(id)) { return records[i]; }
        }
        return null;
    }

    function get(id) { return findIn(all(), id); }

    function hasMultiple() {
        var records = all();
        var count = 0;
        for (var i = 0; i < records.size(); i += 1) {
            if (records[i]["token"] != null) { count += 1; }
        }
        return count > 1;
    }

    function preferredServer(records, currentId) {
        var current = findIn(records, currentId);
        if ((current != null) && (current["token"] != null) && (current["enabled"] != false)) {
            return currentId;
        }
        var single = null;
        for (var i = 0; i < records.size(); i += 1) {
            if ((records[i]["token"] == null) || (records[i]["enabled"] == false)) { continue; }
            if (single != null) { return null; }
            single = records[i]["id"];
        }
        return single;
    }

    function save(record) {
        var records = all();
        var found = false;
        for (var i = 0; i < records.size(); i += 1) {
            if (records[i]["id"].equals(record["id"])) { records[i] = record; found = true; break; }
        }
        if (!found) { records.add(record); }
        Application.Storage.setValue(Storage.PLEX_SERVERS, records);
    }

    function remember(records) {
        var previous = all();
        var currentId = Application.Storage.getValue(Storage.PLEX_SERVER_ID);
        var currentName = Application.Storage.getValue(Storage.PLEX_SERVER_NAME);
        var currentToken = Application.Storage.getValue(Storage.PLEX_SERVER_TOKEN);
        for (var i = 0; i < records.size(); i += 1) {
            var record = records[i];
            var old = findIn(previous, record["id"]);
            if (old != null) {
                record["enabled"] = old["enabled"];
                record["custom"] = old["custom"];
                record["uri"] = old["uri"];
            }
            var wasCurrent = (currentId instanceof Lang.String) && currentId.equals(record["id"]);
            if ((currentId == null) && (currentName instanceof Lang.String)
                && currentName.equals(record["name"])) {
                var matchingNames = 0;
                for (var nameIdx = 0; nameIdx < records.size(); nameIdx += 1) {
                    if (currentName.equals(records[nameIdx]["name"])) { matchingNames += 1; }
                }
                var currentUri = Application.Storage.getValue(Storage.PLEX_SERVER_URL);
                var knownUri = false;
                for (var uriIdx = 0; uriIdx < record["urls"].size(); uriIdx += 1) {
                    if (record["urls"][uriIdx].equals(currentUri)) { knownUri = true; }
                }
                // A rotating token can be matched by the previous endpoint;
                // a name alone must never reassign already downloaded music.
                wasCurrent = (matchingNames == 1) && (knownUri
                    || ((currentToken instanceof Lang.String) && currentToken.equals(record["token"])));
            }
            if (wasCurrent) {
                record["custom"] = Application.Storage.getValue(Storage.PLEX_CUSTOM_SERVER_URL);
                record["uri"] = Application.Storage.getValue(Storage.PLEX_SERVER_URL);
                if (Application.Storage.getValue(Storage.PLEX_LEGACY_SERVER_ID) == null) {
                    Application.Storage.setValue(Storage.PLEX_LEGACY_SERVER_ID, record["id"]);
                }
            }
        }
        // Missing shares retain their downloaded item ownership, but cannot be
        // contacted with credentials no longer supplied by account discovery.
        for (var j = 0; j < previous.size(); j += 1) {
            if (findIn(records, previous[j]["id"]) == null) {
                var missing = previous[j];
                missing["token"] = null;
                missing["status"] = "unavailable";
                records.add(missing);
            }
        }
        Application.Storage.setValue(Storage.PLEX_SERVERS, records);
    }

    function select(id) {
        var record = get(id);
        if (record == null) { return false; }
        Application.Storage.setValue(Storage.PLEX_SERVER_ID, id);
        Application.Storage.setValue(Storage.PLEX_SERVER_NAME, record["name"]);
        Application.Storage.setValue(Storage.PLEX_SERVER_URL, record["uri"]);
        Application.Storage.setValue(Storage.PLEX_SERVER_TOKEN, record["token"]);
        Application.Storage.setValue(Storage.PLEX_SERVER_URLS, record["urls"]);
        Application.Storage.setValue(Storage.PLEX_ARTWORK_URL, record["artwork"]);
        Application.Storage.setValue(Storage.PLEX_CUSTOM_SERVER_URL, record["custom"]);
        Plexit.Provider.onSettingsChanged();
        return true;
    }

    function settings(record) {
        return { "server_id" => record["id"], "api_url" => record["uri"],
            "api_usr" => null, "api_key" => record["token"], "artwork_url" => record["artwork"] };
    }

    function urls(record) {
        return PlexAccount.orderedConnectionUrls(record["custom"], record["uri"], null, record["urls"]);
    }

    function status(id, status) {
        var record = get(id);
        if ((record != null) && !status.equals(record["status"])) { record["status"] = status; save(record); }
    }

    function skipSync(id) {
        var record = get(id);
        if (record == null) { return false; }
        return (record["enabled"] == false) || (record["token"] == null)
            || "offline".equals(record["status"]) || "unavailable".equals(record["status"]);
    }

    function isEnabled(id) {
        var record = get(id);
        return (record == null) || (record["enabled"] != false);
    }

    function beginSync() {
        var records = all();
        for (var i = 0; i < records.size(); i += 1) {
            records[i]["status"] = "unknown";
        }
        Application.Storage.setValue(Storage.PLEX_SERVERS, records);
    }

    function name(id) {
        var record = get(id);
        return (record != null) ? record["name"] : "";
    }
}
