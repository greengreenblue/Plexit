using Toybox.Application;
using Toybox.Lang;
using Plexit.Storage;

// All fixtures use reserved example domains. Restore account state even when a
// test fails; use a separate ObjectStore key for any persisted test media.
(:test)
class MultiServerTestState {
    private var d_keys = [Storage.PLEX_SERVERS, Storage.PLEX_LEGACY_SERVER_ID,
        Storage.PLEX_SERVER_ID, Storage.PLEX_SERVER_NAME, Storage.PLEX_SERVER_URL,
        Storage.PLEX_SERVER_TOKEN, Storage.PLEX_SERVER_URLS, Storage.PLEX_ARTWORK_URL,
        Storage.PLEX_CUSTOM_SERVER_URL, Storage.PLAYLISTS, Storage.SONGS, Storage.PLEX_ACCOUNT_TOKEN];
    private var d_values = [];
    function initialize() {
        for (var i = 0; i < d_keys.size(); i += 1) {
            d_values.add(Application.Storage.getValue(d_keys[i]));
        }
        Application.Storage.setValue(Storage.PLEX_SERVERS, []);
        Application.Storage.setValue(Storage.PLEX_LEGACY_SERVER_ID, "test-server-a");
        Application.Storage.setValue(Storage.PLEX_SERVER_ID, "test-server-a");
        Application.Storage.setValue(Storage.PLEX_CUSTOM_SERVER_URL, null);
    }
    function restore() {
        for (var i = 0; i < d_keys.size(); i += 1) {
            if (d_values[i] == null) { Application.Storage.deleteValue(d_keys[i]); }
            else { Application.Storage.setValue(d_keys[i], d_values[i]); }
        }
        PlaylistStore.reload();
        Plexit.Provider.onSettingsChanged();
    }
    function records() {
        return [
            { "id" => "test-server-a", "name" => "Server A", "token" => "token-a",
                "uri" => "https://a.example", "urls" => ["https://a.example"],
                "custom" => null, "artwork" => null, "enabled" => true, "status" => "online" },
            { "id" => "test-server-b", "name" => "Server B", "token" => "token-b",
                "uri" => "https://b.example", "urls" => ["https://b.example"],
                "custom" => null, "artwork" => null, "enabled" => true, "status" => "unknown" }
        ];
    }
}

(:test)
function itemNamespacesRoundTripAndPreserveCollectionPrefixes(logger) {
    var ids = ["42", "album:42", "artist:42", "collection:42", "genre:3:7",
        "mix:recent-played", "/library/metadata/42/thumb/1"];
    for (var i = 0; i < ids.size(); i += 1) {
        var a = PlexSource.encode("server-a", ids[i]);
        var b = PlexSource.encode("server-b", ids[i]);
        if (a.equals(b) || !PlexSource.raw(a).equals(ids[i])
            || !PlexSource.explicitServer(a).equals("server-a")
            || !PlexSource.explicitServer(b).equals("server-b")
            || (PlexSource.prefixLength(a) != PlexSource.prefixLength(ids[i]))) { return false; }
    }
    return true;
}

(:test)
function originalDownloadedMediaKeepsLegacyIds(logger) {
    return PlexSource.qualifyWithLegacy("original", "42", "original").equals("42")
        && PlexSource.qualifyWithLegacy("original", "album:42", "original").equals("album:42")
        && PlexSource.qualifyWithLegacy("original", "/library/metadata/42/thumb", "original")
            .equals("/library/metadata/42/thumb")
        && !PlexSource.qualifyWithLegacy("shared", "42", "original").equals("42");
}

(:test)
function identicalPlexIdsRemainSeparateInStorage(logger) {
    var key = "multiserver-fixture-items";
    var store = new ObjectStore(key);
    var a = new Song({ "id" => PlexSource.encode("server-a", "42"), "title" => "Song A" });
    var b = new Song({ "id" => PlexSource.encode("server-b", "42"), "title" => "Song B" });
    store.save(a);
    store.save(b);
    store.reload();
    var ok = (store.getIds().size() == 2) && store.get(a.id())["title"].equals("Song A")
        && store.get(b.id())["title"].equals("Song B")
        && !Artwork.compute_id(PlexSource.encode("server-a", "/thumb/42"), Artwork.SONG)
            .equals(Artwork.compute_id(PlexSource.encode("server-b", "/thumb/42"), Artwork.SONG));
    Application.Storage.deleteValue(key);
    return ok;
}

(:test)
function serverSelectionDoesNotChangeExistingItemsSource(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        PlexServers.select("test-server-b");
        var oldSong = Plexit.Provider.settingsForItem("42");
        var sharedSong = Plexit.Provider.settingsForItem(PlexSource.encode("test-server-b", "42"));
        var missing = Plexit.Provider.settingsForItem(PlexSource.encode("missing-server", "42"));
        ok = oldSong["server_id"].equals("test-server-a") && oldSong["api_key"].equals("token-a")
            && sharedSong["server_id"].equals("test-server-b") && sharedSong["api_key"].equals("token-b")
            && (missing["api_key"] == null) && (missing["api_url"] == null);
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function customAddressesBelongToIndividualServers(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        PlexServers.select("test-server-a");
        PlexAccount.setServerAddress("https://custom-a.example");
        PlexServers.select("test-server-b");
        PlexAccount.setServerAddress("https://custom-b.example");
        PlexServers.select("test-server-a");
        var a = PlexServers.urls(PlexServers.get("test-server-a"));
        var b = PlexServers.urls(PlexServers.get("test-server-b"));
        ok = a[0].equals("https://custom-a.example") && a[1].equals("https://a.example")
            && b[0].equals("https://custom-b.example") && b[1].equals("https://b.example")
            && Application.Storage.getValue(Storage.PLEX_CUSTOM_SERVER_URL).equals("https://custom-a.example");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function offlineServerDoesNotDisableOtherServersAndRetriesNextSync(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        PlexServers.status("test-server-b", "offline");
        var skipped = PlexServers.skipSync("test-server-b") && !PlexServers.skipSync("test-server-a");
        PlexServers.beginSync();
        ok = skipped && !PlexServers.skipSync("test-server-b");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function missingShareKeepsOwnershipWithoutReusingItsCredentials(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        var records = state.records();
        PlexServers.remember(records);
        PlexServers.remember([records[0]]);
        var missing = PlexServers.get("test-server-b");
        ok = (PlexServers.all().size() == 2) && (missing["token"] == null)
            && PlexServers.skipSync("test-server-b") && !PlexServers.skipSync("test-server-a");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
class MultiServerProviderProbe extends PlexProvider {
    var songs = null;
    function initialize(id) {
        PlexProvider.initialize({ "server_id" => id, "api_url" => "https://server.example",
            "api_key" => "fixture-token", "api_usr" => null, "artwork_url" => null });
    }
    function do_() { }
    function receivedSongs(items) { songs = items; }
}

(:test)
function trackAndArtworkResponsesCarryTheirServerIdentity(logger) {
    var a = new MultiServerProviderProbe("fixture-a");
    var b = new MultiServerProviderProbe("fixture-b");
    var response = { "Metadata" => [{ "ratingKey" => "42", "title" => "Track", "duration" => 120000,
        "thumb" => "/library/metadata/42/thumb", "Media" => [{ "Part" => [
            { "container" => "mp3", "key" => "/library/parts/42/file.mp3" }] }] }] };
    a.getPlaylistSongs(PlexSource.encode("fixture-a", "album:7"), a.method(:receivedSongs));
    a.on_do_playlist_songs(response);
    b.getPlaylistSongs(PlexSource.encode("fixture-b", "album:7"), b.method(:receivedSongs));
    b.on_do_playlist_songs(response);
    return !a.songs[0].id().equals(b.songs[0].id())
        && PlexSource.explicitServer(a.songs[0].art_id()).equals("fixture-a")
        && PlexSource.raw(a.songs[0].art_id()).equals("/library/metadata/42/thumb")
        && a.songs[0].mediaKey().equals("/library/parts/42/file.mp3");
}

(:test)
class MultiServerSyncProbe {
    var failures = 0;
    function progress(value) { }
    function done() { }
    function fail(error) { failures += 1; }
}

(:test)
function offlinePlaylistKeepsDownloadedSongReferences(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        PlexServers.status("test-server-b", "offline");
        var id = PlexSource.encode("test-server-b", "album:42");
        var song = PlexSource.encode("test-server-b", "7");
        var stored = {};
        stored.put(id, { "id" => id, "name" => "Offline album", "songs" => [song],
            "songCount" => 1, "local" => true, "linked" => true, "remote" => true, "synced" => true });
        Application.Storage.setValue(Storage.PLAYLISTS, stored);
        PlaylistStore.reload();
        var probe = new MultiServerSyncProbe();
        var task = new PlaylistSync(id, probe.method(:progress), probe.method(:done), probe.method(:fail));
        var finished = task.run();
        var playlist = new IPlaylist(id);
        ok = finished && (probe.failures == 0) && playlist.local() && playlist.linked()
            && playlist.remote() && !playlist.synced() && (playlist.count() == 1)
            && playlist.songs()[0].equals(song);
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function refreshingDiscoveryPreservesPerServerPreferences(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        var b = PlexServers.get("test-server-b");
        b["enabled"] = false;
        b["custom"] = "https://custom-b.example";
        PlexServers.save(b);
        PlexServers.select("test-server-a");
        PlexAccount.setServerAddress("https://custom-a.example");
        PlexServers.remember(state.records());
        var refreshed = PlexServers.get("test-server-b");
        ok = (refreshed["enabled"] == false) && refreshed["custom"].equals("https://custom-b.example")
            && PlexServers.get("test-server-a")["custom"].equals("https://custom-a.example");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function editingInactiveServersCustomAddressDoesNotSwitchBrowsing(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        PlexServers.select("test-server-a");
        PlexAccount.setServerAddressFor("test-server-b", "https://custom-b.example");
        ok = Application.Storage.getValue(Storage.PLEX_SERVER_ID).equals("test-server-a")
            && Application.Storage.getValue(Storage.PLEX_SERVER_TOKEN).equals("token-a")
            && PlexServers.get("test-server-b")["custom"].equals("https://custom-b.example");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function legacySourceIsIdentifiedWhenItsTokenRotates(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        Application.Storage.deleteValue(Storage.PLEX_LEGACY_SERVER_ID);
        Application.Storage.deleteValue(Storage.PLEX_SERVER_ID);
        Application.Storage.setValue(Storage.PLEX_SERVER_NAME, "Server A");
        Application.Storage.setValue(Storage.PLEX_SERVER_TOKEN, "old-token-a");
        Application.Storage.setValue(Storage.PLEX_SERVER_URL, "https://a.example");
        PlexServers.remember(state.records());
        ok = PlexSource.serverId("42").equals("test-server-a")
            && Plexit.Provider.settingsForItem("42")["api_key"].equals("token-a");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function unidentifiedLegacyItemsNeverUseSelectedOtherServer(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        Application.Storage.deleteValue(Storage.PLEX_LEGACY_SERVER_ID);
        PlexServers.select("test-server-b");
        var settings = Plexit.Provider.settingsForItem("42");
        ok = (settings["api_key"] == null) && (settings["api_url"] == null);
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function singleServerIsSelectedAutomaticallyWithoutAChoice(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        var only = state.records()[0];
        Application.Storage.setValue(Storage.PLEX_SERVERS, [only]);
        var chosen = PlexServers.preferredServer([only], null);
        ok = chosen.equals("test-server-a") && !PlexServers.hasMultiple();
        PlexServers.select(chosen);
        var menu = new Plexit.Menu.AddMusic();
        menu.load();
        ok = ok && menu.getItem(1).getLabel().equals(Toybox.WatchUi.loadResource(Rez.Strings.Playlists_label));
        var unavailable = state.records()[1];
        unavailable["token"] = null;
        Application.Storage.setValue(Storage.PLEX_SERVERS, [only, unavailable]);
        ok = ok && PlexServers.preferredServer([only, unavailable], "test-server-b").equals("test-server-a")
            && !PlexServers.hasMultiple();
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function multipleServersPreserveExplicitSelection(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        var records = state.records();
        Application.Storage.setValue(Storage.PLEX_SERVERS, records);
        ok = PlexServers.hasMultiple() && (PlexServers.preferredServer(records, null) == null)
            && PlexServers.preferredServer(records, "test-server-b").equals("test-server-b");
        var menu = new Plexit.Menu.AddMusic();
        menu.load();
        ok = ok && menu.getItem(1).getLabel().equals(Toybox.WatchUi.loadResource(Rez.Strings.Playlists_label));
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
class MultiServerBrowseProbe extends Plexit.Menu.PlaylistsRemoteToggle {
    var notifications = 0;
    function initialize() { PlaylistsRemoteToggle.initialize("Fixture playlists", null); }
    function startPage() { }
    function loadedPage(error) { if (error == null) { notifications += 1; } }
}

(:test)
function loadingCallbackSurvivesInitialAndChangedServer(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        PlexServers.select("test-server-a");
        var menu = new MultiServerBrowseProbe();
        menu.setOnLoaded(menu.method(:loadedPage));
        menu.load();
        menu.onPage([], null);
        PlexServers.select("test-server-b");
        menu.setOnLoaded(menu.method(:loadedPage));
        menu.load();
        menu.onPage([], null);
        ok = menu.notifications == 2;
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function signingIntoOtherServerDoesNotReassignUnidentifiedDownloads(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        Application.Storage.deleteValue(Storage.PLEX_LEGACY_SERVER_ID);
        Application.Storage.deleteValue(Storage.PLEX_SERVER_ID);
        Application.Storage.setValue(Storage.PLEX_SERVER_NAME, "Old server");
        Application.Storage.setValue(Storage.PLEX_SERVER_TOKEN, "old-token");
        Application.Storage.setValue(Storage.PLEX_SERVER_URL, "https://old.example");
        Application.Storage.setValue(Storage.SONGS, { "42" => {
            "id" => "42", "title" => "Existing song", "refId" => "fixture-cache-reference" } });
        Application.Storage.setValue(Storage.PLEX_SERVERS, state.records());
        PlexAccount.saveServer("Server B", "https://b.example", "token-b", "fixture-account-token",
            null, ["https://b.example"], "test-server-b");
        ok = (Application.Storage.getValue(Storage.PLEX_LEGACY_SERVER_ID) == null)
            && (Plexit.Provider.settingsForItem("42")["api_key"] == null)
            && Application.Storage.getValue(Storage.SONGS)["42"]["refId"].equals("fixture-cache-reference");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}

(:test)
function clearingCustomAddressRestoresOnlyDiscoveredAddresses(logger) {
    var state = new MultiServerTestState();
    var ok = false;
    try {
        PlexServers.remember(state.records());
        PlexServers.select("test-server-a");
        PlexAccount.setServerAddressFor("test-server-a", "https://custom-a.example");
        PlexAccount.setServerAddressFor("test-server-b", "https://custom-b.example");
        var cleared = PlexAccount.clearServerAddressFor("test-server-a");
        var a = PlexServers.get("test-server-a");
        var urls = PlexServers.urls(a);
        ok = cleared && (a["custom"] == null) && (urls.size() == 1)
            && urls[0].equals("https://a.example") && a["uri"].equals("https://a.example")
            && (Application.Storage.getValue(Storage.PLEX_CUSTOM_SERVER_URL) == null)
            && Application.Storage.getValue(Storage.PLEX_SERVER_URL).equals("https://a.example")
            && PlexServers.get("test-server-b")["custom"].equals("https://custom-b.example");
    } catch (error) { logger.debug(error.toString()); }
    state.restore();
    return ok;
}
