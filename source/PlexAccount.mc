using Toybox.Application;
using Toybox.System;
using Plexit.Storage;

module PlexAccount {
    function clientId() {
        var id = Application.Storage.getValue(Storage.PLEX_CLIENT_ID);
        if (id != null) {
            return id;
        }

        var settings = System.getDeviceSettings();
        id = settings.uniqueIdentifier;
        if (id == null) {
            id = settings.partNumber + "-plexit";
        }
        Application.Storage.setValue(Storage.PLEX_CLIENT_ID, id);
        return id;
    }

    function headers(token) {
        var values = {
            "Accept" => "application/json",
            "X-Plex-Product" => "Plexit",
            "X-Plex-Version" => "0.3.0",
            "X-Plex-Client-Identifier" => clientId(),
            "X-Plex-Platform" => "Garmin Connect IQ",
            "X-Plex-Device" => "Garmin Watch",
            "X-Plex-Device-Name" => System.getDeviceSettings().partNumber,
        };
        if (token != null) {
            values.put("X-Plex-Token", token);
        }
        return values;
    }

    function saveServer(name, uri, token, accountToken) {
        Application.Storage.setValue(Storage.PLEX_SERVER_NAME, name);
        Application.Storage.setValue(Storage.PLEX_SERVER_URL, uri);
        Application.Storage.setValue(Storage.PLEX_SERVER_TOKEN, token);
        Application.Storage.setValue(Storage.PLEX_ACCOUNT_TOKEN, accountToken);
        Plexit.Provider.onSettingsChanged();
    }
}
