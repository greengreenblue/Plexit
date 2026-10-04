using Toybox.System;
using Toybox.Application;
using SubMusic.Storage;

/**
 * module ArtworkStore
 * 
 * access to application storage for songs
 */

module ArtworkStore {

	var d_artworks = new ObjectStore(Storage.ARTWORK);			// allows fast indexing by id
	var d_delete = new ArrayStore(Storage.ARTWORK_DELETE);	// allows fast access 

	function get(id) {
		return d_artworks.get(id);
	}

	// returns artwork ids
	function getIds() {
		return d_artworks.getIds();
	}

	// returns artwork objects
	function getAll(options) {
		var artworks = [];
		var objects = d_artworks.getValues();
		for (var idx = 0; idx != objects.size(); ++idx) {
			var artwork = new Artwork(objects[idx]);
			if ((options.get(:condition) != null)
				&& !(options.get(:condition).invoke(artwork))) {
				continue;
			}
			// return integrated artwork instance
			artworks.add(new IArtwork(artwork.art_id(), artwork.type()));
		}
		return artworks;
	}

	function getDeletes() {
		var ret = new [d_delete.size()];
		for (var idx = 0; idx < d_delete.size(); ++idx) {
			ret[idx] = d_delete.get(idx);
		}
		return ret;
	}

    // these functions should be used only internally by IArtwork class
	function save(artwork) {
		// update delete tracking
		var id = new Id(artwork.id());
		var delete = (artwork.refCount() <= 0);
		var ondelete = (d_delete.indexOf(id) >= 0);
		if (delete && !ondelete) {
			d_delete.add(id);
		} else if (!delete && ondelete) {
			d_delete.remove(id);
		}

		// save details of the song
		return d_artworks.save(artwork);
	}

	function remove(artwork) {
		// remove from storage
		d_artworks.remove(artwork);

        // if not on delete, nothing to do
        var id = new Id(artwork.id());
        if (d_delete.indexOf(id) < 0) {
            return;
        }

		// remove from delete
        d_delete.remove(id);
	}
}