/*
 * Store number of items in a Dictionary by id
 * Item class should have a function id()
 * Item class should have a function toStorage()
 */
class ObjectStore extends Store {

	function initialize(key) {
		Store.initialize(key, {});		// initialize with empty object
	}

	// returns a connected item
	function get(id) {
		var items = Store.value();
		if (id == null)  {
			return null;
		}
		var item = items.get(id);
		if (item != null) {
			return item;
		}

		// Persisted dictionaries can recreate String keys as different runtime
		// objects between native audio-provider view contexts. Fall back to the
		// canonical ID stored inside each value instead of relying solely on the
		// Dictionary key lookup.
		var values = items.values();
		for (var idx = 0; idx < values.size(); ++idx) {
			var value = values[idx];
			if ((value instanceof Toybox.Lang.Dictionary)
				&& (value["id"] != null)
				&& value["id"].toString().equals(id.toString())) {
				return value;
			}
		}
		return null;
	}

	function getIds() {
		return Store.value().keys();
	}

	function getValues() {
		return Store.value().values();
	}

	function reset() {
		Store.reset({});
	}

	function reload() {
		Store.reload({});
	}
	
	function save(item) {
		// return false if failed save
		var id = item.id();
		if (id == null) {
			return false;
		}
		
		// save details of the item
		Store.value().put(id, item.toStorage());
		return Store.update();
	}

	// returns true if item id entry removed from storage or is not in storage
	function remove(item) {        
		var id = item.id();
        if (id == null)  {
			return true;
		}

		var items = Store.value();
		var storageKey = id;
		if (items.get(storageKey) == null) {
			// Storage can reconstruct String dictionary keys as distinct runtime
			// objects. Resolve the actual key through the canonical id embedded in
			// the stored value, just like get() does.
			var keys = items.keys();
			for (var idx = 0; idx < keys.size(); ++idx) {
				var candidate = items.get(keys[idx]);
				if ((candidate instanceof Toybox.Lang.Dictionary)
					&& (candidate["id"] != null)
					&& candidate["id"].toString().equals(id.toString())) {
					storageKey = keys[idx];
					break;
				}
			}
		}

		items.remove(storageKey);
		return Store.update();
	}
}
