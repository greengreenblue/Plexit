using Toybox.Application;
using Toybox.WatchUi;
using Plexit.Storage;

module Plexit {
    module Menu {
        function clearServerAddress(id) {
            var cleared = PlexAccount.clearServerAddressFor(id);
            WatchUi.pushView(new TextView(WatchUi.loadResource(cleared
                ? Rez.Strings.AutomaticAddressEnabled : Rez.Strings.NoReachablePlexServer)),
                new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
        function serverStatus(record) {
            if (record["enabled"] == false) { return WatchUi.loadResource(Rez.Strings.ServerDisabled_label); }
            if (record["token"] == null) { return WatchUi.loadResource(Rez.Strings.ServerUnavailable_label); }
            if ("online".equals(record["status"])) { return WatchUi.loadResource(Rez.Strings.ServerOnline_label); }
            if ("offline".equals(record["status"])) { return WatchUi.loadResource(Rez.Strings.ServerOffline_label); }
            if ("unavailable".equals(record["status"])) { return WatchUi.loadResource(Rez.Strings.ServerUnavailable_label); }
            return WatchUi.loadResource(Rez.Strings.ServerUnknown_label);
        }

        class ServerChooser extends MenuBase {
            function getItem(idx) { if (idx == 0) { load(); } return MenuBase.getItem(idx); }
            function initialize() {
                MenuBase.initialize(WatchUi.loadResource(Rez.Strings.MusicServer_label), false);
            }
            function sublabel() { return Application.Storage.getValue(Storage.PLEX_SERVER_NAME); }
            function load() {
                var records = PlexServers.all();
                var items = [];
                var current = Application.Storage.getValue(Storage.PLEX_SERVER_ID);
                for (var i = 0; i < records.size(); i += 1) {
                    var record = records[i];
                    items.add({ LABEL => record["name"], SUBLABEL => serverStatus(record),
                        METHOD => record["id"], OPTION => record["id"].equals(current) });
                }
                if (records.size() == 0) {
                    items.add({ LABEL => WatchUi.loadResource(Rez.Strings.PlexSignIn),
                        SUBLABEL => null, METHOD => method(:signIn) });
                }
                return MenuBase.load(items);
            }
            function signIn() {
                WatchUi.pushView(new PlexLoginView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_IMMEDIATE);
            }
            function onSelect(item) {
                var record = PlexServers.get(item.getId());
                if (record == null) { return; }
                record["enabled"] = true;
                PlexServers.save(record);
                PlexServers.select(record["id"]);
                unload();
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            function delegate() { return new MenuDelegate(method(:onSelect), null); }
        }

        class MusicServers extends MenuBase {
            function getItem(idx) { if (idx == 0) { load(); } return MenuBase.getItem(idx); }
            function initialize() {
                MenuBase.initialize(WatchUi.loadResource(Rez.Strings.MusicServers_label), false);
            }
            function load() {
                var records = PlexServers.all();
                var items = [];
                for (var i = 0; i < records.size(); i += 1) {
                    items.add(new ServerSettings(records[i]["id"]));
                }
                items.add({ LABEL => WatchUi.loadResource(Rez.Strings.PlexSignIn),
                    SUBLABEL => null, METHOD => method(:signIn) });
                items.add({ LABEL => WatchUi.loadResource(Rez.Strings.RefreshServers_label),
                    SUBLABEL => null, METHOD => method(:refresh) });
                return MenuBase.load(items);
            }
            function signIn() {
                WatchUi.pushView(new PlexLoginView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_IMMEDIATE);
            }
            function refresh() {
                WatchUi.pushView(new PlexServerRefreshView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_IMMEDIATE);
            }
        }

        class ServerSettings extends MenuBase {
            function getItem(idx) { if (idx == 0) { load(); } return MenuBase.getItem(idx); }
            private var d_id;
            function initialize(id) {
                d_id = id;
                MenuBase.initialize(PlexServers.name(id), false);
            }
            function sublabel() {
                var record = PlexServers.get(d_id);
                return (record != null) ? serverStatus(record) : null;
            }
            function load() {
                var record = PlexServers.get(d_id);
                if (record == null) { return MenuBase.load([]); }
                return MenuBase.load([
                    { LABEL => WatchUi.loadResource(Rez.Strings.ServerEnabled_label),
                        SUBLABEL => null, METHOD => method(:toggleEnabled), OPTION => record["enabled"] != false },
                    { LABEL => WatchUi.loadResource(Rez.Strings.ChooseServer_label),
                        SUBLABEL => record["name"], METHOD => method(:choose) },
                    { LABEL => WatchUi.loadResource(Rez.Strings.PlexServerAddress),
                        SUBLABEL => (record["custom"] != null) ? record["custom"] : record["uri"],
                        METHOD => method(:customAddress) },
                    { LABEL => WatchUi.loadResource(Rez.Strings.UseAutomaticAddress),
                        SUBLABEL => null, METHOD => method(:automaticAddress) }
                ]);
            }
            function toggleEnabled() {
                var record = PlexServers.get(d_id);
                record["enabled"] = record["enabled"] == false;
                PlexServers.save(record);
            }
            function choose() {
                var record = PlexServers.get(d_id);
                record["enabled"] = true;
                PlexServers.save(record);
                PlexServers.select(d_id);
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            function customAddress() {
                var record = PlexServers.get(d_id);
                var uri = (record["custom"] != null) ? record["custom"] : record["uri"];
                var delegate = new PlexServerAddressDelegate();
                delegate.setServerId(d_id);
                WatchUi.pushView(new WatchUi.TextPicker(uri), delegate, WatchUi.SLIDE_IMMEDIATE);
            }
            function automaticAddress() { Plexit.Menu.clearServerAddress(d_id); }
        }
    }
}
