using Plexit.ScrobbleStore;

module Plexit {

	class ScrobbleSync extends Deferrable {
		
		private var d_provider = null;
		
		private var f_progress;
		
		private var d_scrobble = null;
		private var d_idx = 0;
		private var d_todo = ScrobbleStore.size();
		private var d_todo_total = ScrobbleStore.size();	// store initial size
		
		function initialize(progress, done, fail) {
			Deferrable.initialize(method(:sync), done, fail);		// make sync the deferred task
			
			f_progress = progress;
		}
		
		function sync() {
			if (d_todo == 0) {
				return Deferrable.complete();
			}
			
			// update progress
			f_progress.invoke(progress());
			
			// record first play on the list
			var storage = ScrobbleStore.get(d_idx);
			d_scrobble = new Scrobble(storage);
            if (PlexServers.skipSync(PlexSource.serverId(d_scrobble.id()))) {
                d_idx += 1; d_todo -= 1; return sync();
            }
            d_provider = Plexit.Provider.forItem(d_scrobble.id());
            d_provider.setFallback(method(:onError));
			d_provider.recordPlay(d_scrobble.id(), d_scrobble.time(), method(:onRecordPlay));
			return Deferrable.defer();
		}
		
		function onRecordPlay(response) {
			// decrement todos
			d_todo -= 1;
			
			// remove front as it is done now
			ScrobbleStore.remove(d_scrobble);
			
			// sync next
			sync();
		}
		
        function onError(error) {
            // Retain failed events for their own source; continue other servers.
            d_idx += 1;
            d_todo -= 1;
            sync();
        }

		function progress() {
			var done = d_todo_total - d_todo;
			var progress = (100 * done) / d_todo_total.toFloat();
			return progress;
		}
	}
}