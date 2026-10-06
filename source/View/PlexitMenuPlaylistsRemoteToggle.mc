using Toybox.Lang;
using Toybox.WatchUi;

module Plexit {
    module Menu {
        class CollectionSearchDelegate extends WatchUi.TextPickerDelegate {
            private var d_menu;

            function initialize(menu) {
                TextPickerDelegate.initialize();
                d_menu = menu;
            }

            function onTextEntered(text, changed) {
                d_menu.setSearch(text);
                return true;
            }

            function onCancel() {
                return true;
            }
        }

        class PlaylistsRemoteToggle extends MenuBase {
            private var d_provider = Plexit.Provider.get();
            private var d_loading = false;
            private var d_collectionType = null;
            private var d_allCollections = [];
            private var d_search = "";
            private var d_visibleStart = 0;
            private const PAGE_SIZE = 40;

            function initialize(title, collectionType) {
                MenuBase.initialize(title, false);
                d_collectionType = collectionType;
                d_provider.setFallback(method(:onError));
            }

            function playlist_to_item(playlist) {
                var sublabel = playlist.count().toString() + " songs";
                if ((d_collectionType != null) && d_collectionType.equals("album")
                    && (playlist.subtitle() != null)) {
                    sublabel = playlist.subtitle();
				} else if ((d_collectionType != null) && (playlist.count() == 0)) {
					if (d_collectionType.equals("album")) { sublabel = "Album"; }
					else if (d_collectionType.equals("artist")) { sublabel = "Artist"; }
					else { sublabel = "Genre"; }
                }
                if (!playlist.remote()) { sublabel += " - local only"; }
                var storedPlaylist = new IPlaylist(playlist.id());
                var enabled = storedPlaylist.stored()
                    ? storedPlaylist.local() : playlist.local();
                return {
                    LABEL => playlist.name(),
                    SUBLABEL => sublabel,
                    // Native menus should only carry stable primitive IDs. The
                    // matching remote object is resolved from d_allCollections.
                    METHOD => playlist.id(),
                    OPTION => enabled,
                };
            }

            function load() {
                if (!PlexAccount.isConnected()) {
                    d_loading = false;
                    return MenuBase.load([]);
                }
                // Re-entering this cached menu must reflect selections persisted
                // by the previous native menu instance immediately.
                PlaylistStore.reload();
                if (d_allCollections.size() > 0) {
                    rebuildItems();
                    return true;
                }
                if (d_loading) { return false; }
                d_loading = true;
                if (d_collectionType == null) {
                    d_provider.getAllPlaylists(method(:onGetAllCollections));
                } else if (d_collectionType.equals("album")) {
                    d_provider.getAllAlbums(method(:onGetAllCollections));
				} else if (d_collectionType.equals("genre")) {
					d_provider.getAllGenres(method(:onGetAllCollections));
                } else {
                    d_provider.getAllArtists(method(:onGetAllCollections));
                }
                return false;
            }

            function managesId(id) {
                if (!(id instanceof Lang.String)) { return false; }
                if (d_collectionType == null) {
                    return (id.find("album:") != 0) && (id.find("artist:") != 0);
                }
                return id.find(d_collectionType + ":") == 0;
            }

            function onGetAllCollections(collections) {
                var ids = PlaylistStore.getIds();
                var relevantIds = [];
                for (var storedIdx = 0; storedIdx < ids.size(); ++storedIdx) {
                    if (managesId(ids[storedIdx])) { relevantIds.add(ids[storedIdx]); }
                }

                var stored = [];
                var remote = [];
                for (var idx = 0; idx < collections.size(); ++idx) {
                    var collection = collections[idx];
                    var id = collection.id();
                    if (relevantIds.indexOf(id) < 0) {
                        remote.add(collection);
                        continue;
                    }
                    var localCollection = new IPlaylist(id);
                    localCollection.setRemote(collection.remote());
                    localCollection.updateMeta(collection);
                    stored.add(localCollection);
                    relevantIds.remove(id);
                }

                for (var missingIdx = 0; missingIdx < relevantIds.size(); ++missingIdx) {
                    var missing = new IPlaylist(relevantIds[missingIdx]);
                    missing.setRemote(false);
                    stored.add(missing);
                }

                stored.addAll(remote);
                d_allCollections = stored;
                rebuildItems();
                d_loading = false;
                MenuBase.onLoaded(null);
            }

            function matchesSearch(playlist) {
                if (d_search.equals("")) { return true; }
                var query = d_search.toLower();
                if (playlist.name().toLower().find(query) != null) { return true; }
                return (playlist.subtitle() != null)
                    && (playlist.subtitle().toLower().find(query) != null);
            }

            function rebuildItems() {
                var menuItems = [];
                if (d_collectionType != null) {
                    menuItems.add({
                        LABEL => WatchUi.loadResource(Rez.Strings.Search_label),
                        SUBLABEL => d_search.equals("")
                            ? WatchUi.loadResource(Rez.Strings.Search_hint) : d_search,
                        METHOD => method(:onSearch),
                    });
                    if (!d_search.equals("")) {
                        menuItems.add({
                            LABEL => WatchUi.loadResource(Rez.Strings.ClearSearch_label),
                            SUBLABEL => d_search,
                            METHOD => method(:onClearSearch),
                        });
                    }
                }
                if (d_visibleStart > 0) {
                    menuItems.add({
                        LABEL => WatchUi.loadResource(Rez.Strings.PreviousResults_label),
                        SUBLABEL => null,
                        METHOD => method(:onShowPrevious),
                    });
                }
                var matched = 0;
                for (var idx = 0; idx < d_allCollections.size(); ++idx) {
                    if (matchesSearch(d_allCollections[idx])) {
                        if ((matched >= d_visibleStart)
                            && (matched < (d_visibleStart + PAGE_SIZE))) {
                            menuItems.add(playlist_to_item(d_allCollections[idx]));
                        }
                        matched += 1;
                    }
                }
                if (matched > (d_visibleStart + PAGE_SIZE)) {
                    menuItems.add({
                        LABEL => WatchUi.loadResource(Rez.Strings.ShowMore_label),
                        SUBLABEL => (matched - d_visibleStart - PAGE_SIZE) + " remaining",
                        METHOD => method(:onShowMore),
                    });
                }
                MenuBase.load(menuItems);
            }

            function onShowMore() {
                d_visibleStart += PAGE_SIZE;
                rebuildItems();
                replaceMenuView();
            }

            function onShowPrevious() {
                d_visibleStart -= PAGE_SIZE;
                if (d_visibleStart < 0) { d_visibleStart = 0; }
                rebuildItems();
                replaceMenuView();
            }

            function replaceMenuView() {
                WatchUi.switchToView(
                    new MenuView(self),
                    delegate(),
                    WatchUi.SLIDE_IMMEDIATE
                );
            }

            function onSearch() {
                WatchUi.pushView(
                    new WatchUi.TextPicker(d_search),
                    new CollectionSearchDelegate(self),
                    WatchUi.SLIDE_IMMEDIATE
                );
            }

            function setSearch(search) {
                d_search = (search == null) ? "" : search;
                d_visibleStart = 0;
                rebuildItems();
            }

            function onClearSearch() {
                d_search = "";
                d_visibleStart = 0;
                rebuildItems();
                replaceMenuView();
            }

            function placeholder() {
                if (!PlexAccount.isConnected()) {
                    return WatchUi.loadResource(Rez.Strings.PlexNotConnected);
                }
                if (d_loading) {
                    if (d_collectionType == null) {
                        return WatchUi.loadResource(Rez.Strings.fetchingPlaylists);
                    }
					if (d_collectionType.equals("album")) {
                        return WatchUi.loadResource(Rez.Strings.fetchingAlbums);
                    }
					if (d_collectionType.equals("genre")) {
						return WatchUi.loadResource(Rez.Strings.fetchingGenres);
					}
                    return WatchUi.loadResource(Rez.Strings.fetchingArtists);
                }
                return WatchUi.loadResource(Rez.Strings.placeholder_noRemotePlaylists);
            }

            function onError(error) {
                d_loading = false;
                MenuBase.onLoaded(error);
            }

            function onPlaylistToggle(item) {
                var id = item.getId();
                var playlist = findCollection(id);
                if (playlist == null) {
                    System.println("Offline selection ignored: missing collection " + id);
                    return;
                }
                var localPlaylist = new IPlaylist(id);
                if (item.isEnabled()) {
                    // Persist the remote metadata first, then mark it local. This
                    // makes the synthetic album/artist visible to pending-sync
                    // readers immediately, even when Plex omitted leafCount.
                    localPlaylist.updateMeta(playlist);
                }
                var saved = localPlaylist.setLocal(item.isEnabled());
                var persisted = new IPlaylist(id);
                System.println("Offline selection: id=" + id
                    + ", enabled=" + item.isEnabled()
                    + ", saved=" + saved
                    + ", stored=" + persisted.stored()
                    + ", local=" + persisted.local());
                PlaylistStore.debugState("after-toggle");
            }

            function findCollection(id) {
                for (var idx = 0; idx < d_allCollections.size(); ++idx) {
                    if (d_allCollections[idx].id().equals(id)) {
                        return d_allCollections[idx];
                    }
                }
                return null;
            }

            function onBrowseBack() {
                // AddMusic keeps its child menu objects alive for fast navigation.
                // Do not let a complete Plex album/artist catalogue survive into
                // an immediate audio sync, where it substantially increases the
                // memory peak while Garmin commits downloaded media metadata.
                d_allCollections = [];
                d_search = "";
                d_visibleStart = 0;
                d_loading = false;
                unload();
                return false;
            }

            function delegate() {
                return new MenuDelegate(method(:onPlaylistToggle), method(:onBrowseBack));
            }
        }
    }
}
