using Toybox.WatchUi;
using Plexit.Menu;

module Plexit {
    module Menu {
        class SongsRemote extends MenuBase {

            private var d_loading = false;
	        private var d_provider = Plexit.Provider.get();
            private var d_id;       // store id of podcast channel

            function initialize(title, id) {
                // initialize base as not loaded
                MenuBase.initialize(title, false);

                d_id = id;
                d_provider = Plexit.Provider.forItem(id);

                // items should be lazy loaded by a menu loader
                // this prevents multiple concurrent requests
            }

            function load() {
				if (!PlexAccount.isConnected()) {
					d_loading = false;
					return MenuBase.load([]);
				}
                // if already loading, do nothing, wait for response
                if (d_loading) {
                    return false;
                }

                // start loading
                d_loading = true;

                // set fallback before request. future: fix with request object
                d_provider.setFallback(method(:onError));
                d_provider.getPlaylistSongs(d_id, method(:onGetPlaylistSongs));
                return loaded();
            }

            function onGetPlaylistSongs(songs) {
                var items = [];
                for (var idx = 0; idx != songs.size(); ++idx) {
                    //d_items.add(new Menu.SongSettingsRemote(songs[idx]));
                    items.add({
                        LABEL => songs[idx].title(),
                        SUBLABEL => songs[idx].artist(),
                        METHOD => songs[idx].id(),
                    });
                }
                MenuBase.load(items);
                
                // loading finished
                d_loading = false;
                MenuBase.onLoaded(null);
            }

            function placeholder() {
				if (!PlexAccount.isConnected()) {
					return WatchUi.loadResource(Rez.Strings.PlexNotConnected);
				}
                if (d_loading) {
                    return WatchUi.loadResource(Rez.Strings.fetchingSongs);
                }
                return WatchUi.loadResource(Rez.Strings.placeholder_noRemoteSongs);
            }

            function onError(error) {
                // loading finished
                d_loading = false;
                MenuBase.onLoaded(error);
            }
        }
    }
}
