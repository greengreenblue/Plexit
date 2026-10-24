using Toybox.Application;

module Plexit {
    module Provider {
        var d_provider = null;

        function get() {
            if (d_provider != null) {
                return d_provider;
            }

            return createProvider(getProviderSettings());
        }

        function getProviderSettings() {
            var record = PlexServers.get(Application.Storage.getValue(Storage.PLEX_SERVER_ID));
            if (record != null) { return PlexServers.settings(record); }
            var serverUrl = Application.Storage.getValue(Storage.PLEX_SERVER_URL);
            var serverToken = Application.Storage.getValue(Storage.PLEX_SERVER_TOKEN);
            var artworkUrl = Application.Storage.getValue(Storage.PLEX_ARTWORK_URL);
            return {
                "server_id" => Application.Storage.getValue(Storage.PLEX_SERVER_ID),
                "api_url" => serverUrl,
                "api_usr" => null,
                "api_key" => serverToken,
                "artwork_url" => artworkUrl,
            };
        }

        function forItem(id) {
            return new PlexProvider(settingsForItem(id));
        }

        function settingsForItem(id) {
            var serverId = PlexSource.serverId(id);
            var record = PlexServers.get(serverId);
            if (record != null) { return PlexServers.settings(record); }
            var settings = getProviderSettings();
            // Never send a namespaced item's key to the selected other server.
            var explicit = PlexSource.explicitServer(id);
            if ((explicit != null) || ((serverId == null) && (settings["server_id"] != null))
                || ((serverId != null) && (settings["server_id"] != null)
                && !serverId.equals(settings["server_id"]))) {
                settings = { "server_id" => serverId, "api_url" => null,
                    "api_usr" => null, "api_key" => null, "artwork_url" => null };
            }
            return settings;
        }

        function createProvider(settings) {
            d_provider = new PlexProvider(settings);
            return d_provider;
        }

        function onSettingsChanged() {
            if (d_provider == null) {
                return null;
            }

            d_provider.onSettingsChanged(getProviderSettings());
            return null;
        }
    }
}
