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

        function summary() {
            return Plexit.I18n.text(Rez.Strings.MixSummary, [Plexit.I18n.songs(trackLimit()), sizeLimitMb()]);
        }

        function name(id) {
            if (id.equals("mix:recent-added")) { return WatchUi.loadResource(Rez.Strings.RecentlyAdded_label); }
            if (id.equals("mix:recent-played")) { return WatchUi.loadResource(Rez.Strings.RecentlyPlayed_label); }
            if (id.equals("mix:most-played")) { return WatchUi.loadResource(Rez.Strings.MostPlayed_label); }
            if (id.equals("mix:unplayed")) { return WatchUi.loadResource(Rez.Strings.Unplayed_label); }
            return WatchUi.loadResource(Rez.Strings.Favorites_label);
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
                    playlist.setCount(trackLimit());
                    playlist.setSubtitle(summary());
                    playlist.setSynced(false);
                }
            }
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
                items.add(new Menu.MixSettings());
                return MenuBase.load(items);
            }

            function mixSummary() { return DynamicMix.summary(); }

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

        class MixSettings extends MenuBase {
            function initialize() {
                MenuBase.initialize(WatchUi.loadResource(Rez.Strings.MixSettings_label), false);
            }

            function sublabel() { return DynamicMix.summary(); }

            function load() {
                return MenuBase.load([
                    new Menu.TrackLimitSettings(),
                    new Menu.SizeLimitSettings(),
                ]);
            }
        }

        class TrackLimitSettings extends MenuBase {
            private var d_values = [ 25, 50, 100, 200 ];

            function initialize() {
                MenuBase.initialize(WatchUi.loadResource(Rez.Strings.TrackLimit_label), false);
            }

            function sublabel() { return Plexit.I18n.songs(DynamicMix.trackLimit()); }

            function load() {
                var items = [];
                var current = DynamicMix.trackLimit();
                for (var idx = 0; idx < d_values.size(); ++idx) {
                    var value = d_values[idx];
                    items.add({
                        LABEL => Plexit.I18n.songs(value),
                        SUBLABEL => null,
                        METHOD => value,
                        OPTION => (value == current),
                    });
                }
                return MenuBase.load(items);
            }

            function onSelect(item) {
                Application.Storage.setValue(Storage.DYNAMIC_TRACK_LIMIT, item.getId());
                DynamicMix.invalidateSelectedMixes();
                unload();
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }

            function delegate() { return new MenuDelegate(method(:onSelect), null); }
        }

        class SizeLimitSettings extends MenuBase {
            private var d_values = [ 250, 500, 1000, 2000 ];

            function initialize() {
                MenuBase.initialize(WatchUi.loadResource(Rez.Strings.MaximumDownloadSize_label), false);
            }

            function sublabel() { return DynamicMix.sizeLimitMb() + " MB"; }

            function load() {
                var items = [];
                var current = DynamicMix.sizeLimitMb();
                for (var idx = 0; idx < d_values.size(); ++idx) {
                    var value = d_values[idx];
                    items.add({
                        LABEL => value + " MB",
                        SUBLABEL => null,
                        METHOD => value,
                        OPTION => (value == current),
                    });
                }
                return MenuBase.load(items);
            }

            function onSelect(item) {
                Application.Storage.setValue(Storage.DYNAMIC_SIZE_LIMIT_MB, item.getId());
                DynamicMix.invalidateSelectedMixes();
                unload();
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }

            function delegate() { return new MenuDelegate(method(:onSelect), null); }
        }
    }
}
