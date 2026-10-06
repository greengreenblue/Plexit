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
            var serverUrl = Application.Storage.getValue(Storage.PLEX_SERVER_URL);
            var serverToken = Application.Storage.getValue(Storage.PLEX_SERVER_TOKEN);
            var artworkUrl = Application.Storage.getValue(Storage.PLEX_ARTWORK_URL);
            return {
                "api_url" => serverUrl,
                "api_usr" => null,
                "api_key" => serverToken,
                "artwork_url" => artworkUrl,
            };
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
