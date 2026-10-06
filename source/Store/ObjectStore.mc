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
		return items.get(id);
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

		Store.value().remove(id);
		return Store.update();
	}
}
