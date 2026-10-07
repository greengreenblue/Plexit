using Toybox.WatchUi;
using Plexit;

module Plexit {
    module Menu {
        class PlaylistSettingsRemote extends MenuBase {

            private var d_id;
            private var d_playlist;

            function initialize(playlist) {
                MenuBase.initialize(playlist.name(), false);

                d_playlist = playlist;
                d_id = playlist.id();
            }

            function load() {
                return MenuBase.load([
                    {
                        LABEL => WatchUi.loadResource(Rez.Strings.MakeOffline_label),
                        SUBLABEL => null,
                        METHOD => "offline",
                        OPTION => method(:isOffline),
                    },
                    new Menu.SongsRemote(
                        WatchUi.loadResource(Rez.Strings.Songs_label),
                        d_id
                    ),
                ]);
            }

            function isOffline() {
                var iplaylist = new IPlaylist(d_id);
                return iplaylist.local();
            }

            function sublabel() {
                var iplaylist = new IPlaylist(d_id);
                if (iplaylist.local() && iplaylist.synced()) {
                    return WatchUi.loadResource(Rez.Strings.LocalSynced_label);
                }
                if (iplaylist.local()) {
                    return WatchUi.loadResource(Rez.Strings.LocalNeedsSync_label);
                }

                // not synced or local? use remote playlist object
                return Plexit.I18n.songs(d_playlist.count());
            }

            function onOfflineToggle(item) {
                var iplaylist = new IPlaylist(d_id);
                iplaylist.setLocal(item.isEnabled());
                if (item.isEnabled()) { iplaylist.updateMeta(d_playlist); }
            }

            function delegate() {
                return new MenuDelegate(method(:onOfflineToggle), null);
            }
        }
    }
}