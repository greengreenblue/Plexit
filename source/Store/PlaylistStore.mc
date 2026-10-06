using Plexit.Storage;
using Toybox.Application;
using Toybox.Lang;
using Toybox.System;

module PlaylistStore {
    var d_store = new ObjectStore(Storage.PLAYLISTS);

    function get(id) {
		d_store.reload();
        return d_store.get(id);
    }

    function getIds() {
		d_store.reload();
        return d_store.getIds();
    }

    function save(playlist) {
		// Merge with the latest persistent value instead of a possibly stale
		// dictionary retained by another native view/runtime context.
		d_store.reload();
        return d_store.save(playlist);
    }

    function remove(playlist) {
		d_store.reload();
        return d_store.remove(playlist);
    }

	function reset() {
		d_store.reset();
	}

	function reload() {
		d_store.reload();
	}

	function debugState(context) {
		var stored = Application.Storage.getValue(Storage.PLAYLISTS);
		if (!(stored instanceof Lang.Dictionary)) {
			System.println("PlaylistStore[" + context + "]: no persisted dictionary");
			return;
		}
		var values = stored.values();
		var localCount = 0;
		for (var idx = 0; idx < values.size(); ++idx) {
			var value = values[idx];
			if ((value instanceof Lang.Dictionary) && (value["local"] == true)) {
				localCount += 1;
				System.println("PlaylistStore[" + context + "]: local id=" + value["id"]
					+ ", synced=" + value["synced"]);
			}
		}
		System.println("PlaylistStore[" + context + "]: total=" + values.size()
			+ ", local=" + localCount);
	}
}
