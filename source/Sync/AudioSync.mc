class AudioSync extends Deferrable {

	private var d_provider = SubMusic.Provider.get();
	private var d_audio = null;		// front of the todos
	
	private var d_failed = [];		// array of all failed
	
	private var f_progress; 		// callback on progress
	
	// store sync size
	private var d_pendingAudio = [];	// array of IAudio objects
	private var d_pendingTotal;		// the number of items that had to be synced

	function initialize(progress, done, fail) {
		Deferrable.initialize(method(:sync), done, fail);		// make sync the deferred task
		
		f_progress = progress;
		
        d_provider.setFallback(method(:onError));
		d_provider.setProgressCallback(method(:onProgress));

		// first delete the todeletes
		var ids = SongStore.getDeletes();
		for (var idx = 0; idx < ids.size(); ++idx) {
			var id = ids[idx];
			var isong = new ISong(id);
			isong.remove();					// remove from Store
		}
		
		// now get songs that have not yet been downloaded
		ids = SongStore.getIds();
		for (var idx = 0; idx != ids.size(); ++idx) {
				var audio = new Audio(ids[idx], Audio.SONG);

				// only add to todo if not yet stored
				if (audio.refId() == null) {
					d_pendingAudio.add(audio);
				}
		}
		d_pendingTotal = d_pendingAudio.size();
	}
	
	function sync() {
		// if songs all finished, complete this task
		if (d_pendingAudio.size() == 0) {
	   		return Deferrable.complete();				// set complete
		}

		// update progress
		f_progress.invoke(progress());
		
		// start download
		d_provider.getRefId(
			d_pendingAudio[0].id(),
			d_pendingAudio[0].mime(),
			d_pendingAudio[0].mediaKey(),
			d_pendingAudio[0].type(),
			method(:onDownloaded)
		);
		return Deferrable.defer();
	}

	function progress() {
		// determine what is left to do
		var todo = 0;
		if (d_pendingAudio != null) { todo = d_pendingAudio.size(); }
		
		var done = d_pendingTotal - todo;
		var progress = (100 * done) / d_pendingTotal.toFloat();
		return progress;
	}

	// handle callback on intermediate progress
	function onProgress(progress) {
		progress /= d_pendingTotal.toFloat();
		f_progress.invoke(progress() + progress);
	}
	
    // Callback for when a song is downloaded
	function onDownloaded(refId) {
		// update refId
		d_pendingAudio[0].setRefId(refId);

		// continue to next song
		d_pendingAudio.removeAll(d_pendingAudio[0]);
	
		sync();
	}
    
	function onError(error) {
		// check if song in progress
		if ((d_pendingAudio.size() == 0) || (d_pendingAudio[0] == null)) {
			Deferrable.cancel(error);
			return;
		}

		// indicate failed sync
//   	d_playlist.setError(error); TODO
		d_failed.add(d_pendingAudio[0]);
		// record the cause of failure
//		d_pendingAudio[0].setError(error);				TODO
		
		// remove first element from todo list
		d_pendingAudio.removeAll(d_pendingAudio[0]);

		sync();
		return;
	}
}
