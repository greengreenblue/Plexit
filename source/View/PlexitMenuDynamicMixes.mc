using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Plexit.Storage;

module Plexit {
    module DynamicMix {
        enum { DEFAULT_TRACK_LIMIT = 50, DEFAULT_SIZE_LIMIT_MB = 500 }

        function trackLimit() {
            var value = Application.Storage.getValue(Storage.DYNAMIC_TRACK_LIMIT);
            return (value instanceof Lang.Number) ? value : DEFAULT_TRACK_LIMIT;
        }

        function sizeLimitMb() {
            var value = Application.Storage.getValue(Storage.DYNAMIC_SIZE_LIMIT_MB);
            return (value instanceof Lang.Number) ? value : DEFAULT_SIZE_LIMIT_MB;
        }

        function name(id) {
            if (id.equals("mix:recent-added")) { return WatchUi.loadResource(Rez.Strings.RecentlyAdded_label); }
            if (id.equals("mix:recent-played")) { return WatchUi.loadResource(Rez.Strings.RecentlyPlayed_label); }
            if (id.equals("mix:most-played")) { return WatchUi.loadResource(Rez.Strings.MostPlayed_label); }
            if (id.equals("mix:unplayed")) { return WatchUi.loadResource(Rez.Strings.Unplayed_label); }
            return WatchUi.loadResource(Rez.Strings.Favorites_label);
        }
    }

    module Menu {
        class DynamicMixes extends MenuBase {
            private var d_ids = [
                "mix:recent-added",
                "mix:recent-played",
                "mix:most-played",
                "mix:unplayed",
                "mix:favorites"
            ];

            function initialize() {
                MenuBase.initialize(WatchUi.loadResource(Rez.Strings.Mixes_label), false);
            }

            function load() {
                var items = [];
                for (var idx = 0; idx < d_ids.size(); ++idx) {
                    var id = d_ids[idx];
                    items.add({
                        LABEL => DynamicMix.name(id),
                        SUBLABEL => method(:mixSummary),
                        METHOD => id,
                        OPTION => (new IPlaylist(id)).local(),
                    });
                }
				items.add(new Menu.PlaylistsRemoteToggle(
					WatchUi.loadResource(Rez.Strings.Genres_label), "genre"));
                items.add({
                    LABEL => WatchUi.loadResource(Rez.Strings.TrackLimit_label),
                    SUBLABEL => method(:trackLimitSummary),
                    METHOD => method(:cycleTrackLimit),
                });
                items.add({
                    LABEL => WatchUi.loadResource(Rez.Strings.SizeLimit_label),
                    SUBLABEL => method(:sizeLimitSummary),
                    METHOD => method(:cycleSizeLimit),
                });
                return MenuBase.load(items);
            }

            function mixSummary() {
                return DynamicMix.trackLimit() + " songs / " + DynamicMix.sizeLimitMb() + " MB max";
            }

            function trackLimitSummary() { return DynamicMix.trackLimit() + " songs"; }
            function sizeLimitSummary() { return DynamicMix.sizeLimitMb() + " MB"; }

            function cycleTrackLimit() {
                var current = DynamicMix.trackLimit();
                var next = (current == 25) ? 50 : ((current == 50) ? 100 : ((current == 100) ? 200 : 25));
                Application.Storage.setValue(Storage.DYNAMIC_TRACK_LIMIT, next);
				invalidateSelectedMixes();
                refresh();
            }

            function cycleSizeLimit() {
                var current = DynamicMix.sizeLimitMb();
                var next = (current == 250) ? 500 : ((current == 500) ? 1000 : ((current == 1000) ? 2000 : 250));
                Application.Storage.setValue(Storage.DYNAMIC_SIZE_LIMIT_MB, next);
				invalidateSelectedMixes();
                refresh();
            }

			function invalidateSelectedMixes() {
				var storedIds = PlaylistStore.getIds();
				for (var idx = 0; idx < storedIds.size(); ++idx) {
					var id = storedIds[idx];
					if (!(id instanceof Lang.String)
						|| ((id.find("mix:") != 0) && (id.find("genre:") != 0))) {
						continue;
					}
					var playlist = new IPlaylist(id);
					if (playlist.local()) {
						playlist.setCount(DynamicMix.trackLimit());
						playlist.setSubtitle(mixSummary());
						playlist.setSynced(false);
					}
				}
			}

            function refresh() {
                load();
                WatchUi.switchToView(new MenuView(self), delegate(), WatchUi.SLIDE_IMMEDIATE);
            }

            function onToggle(item) {
                var id = item.getId();
                var playlist = new IPlaylist(id);
                if (item.isEnabled()) {
                    playlist.updateMeta(new Playlist({
                        "id" => id,
                        "name" => DynamicMix.name(id),
                        "subtitle" => mixSummary(),
                        "songCount" => DynamicMix.trackLimit(),
                        "remote" => true,
                    }));
                }
                playlist.setLocal(item.isEnabled());
            }

            function delegate() {
                return new MenuDelegate(method(:onToggle), null);
            }
        }
    }
}
