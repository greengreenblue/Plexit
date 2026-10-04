using Toybox.Application;

module SubMusic {
    module Provider {
        var d_provider = null;

        function get() {
            if (d_provider != null) {
                return d_provider;
            }

            return createProvider(getProviderSettings());
        }

        function getProviderSettings() {
            return {
                "api_url" => Application.Properties.getValue("plex_server_url"),
                "api_usr" => null,
                "api_key" => Application.Properties.getValue("plex_token"),
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
