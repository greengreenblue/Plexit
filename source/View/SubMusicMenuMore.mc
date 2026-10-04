using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Time;
using SubMusic.Storage;

module SubMusic {
	module Menu {
		class AddMusic extends MenuBase {

			function initialize() {
				MenuBase.initialize(WatchUi.loadResource(Rez.Strings.AddMusic_label), false);
			}

			function load() {
				if ($.debug) {
					System.println("Menu.AddMusic::load()");
				}
				return MenuBase.load([
					{
						LABEL => method(:getSyncLabel),
						SUBLABEL => method(:getSyncStatus),
						METHOD => method(:onStartSync),
					},
					new Menu.PlaylistsRemoteToggle(WatchUi.loadResource(Rez.Strings.Playlists_label)),
				]);
			}

			function sublabel() {
				return getPendingSummary();
			}

			static function getSyncLabel() {
				if (hasPendingChanges()) {
					return WatchUi.loadResource(Rez.Strings.SyncPending_label);
				}
				return WatchUi.loadResource(Rez.Strings.SyncNow_label);
			}

			static function getSyncStatus() {
				var pending = getPendingSummary();
				if (pending != null) {
					return pending;
				}
				return getLastSyncString();
			}

			static function getPendingSummary() {
				var songs = 0;
				var changes = false;
				var ids = PlaylistStore.getIds();
				for (var idx = 0; idx < ids.size(); ++idx) {
					var playlist = new IPlaylist(ids[idx]);
					if (playlist.local() && !playlist.synced()) {
						songs += playlist.count();
						changes = true;
					} else if (!playlist.local() && playlist.linked()) {
						changes = true;
					}
				}

				// Before playlist metadata is fetched, playlist.count() is the best
				// estimate. During/after a partial sync, the todo store is exact.
				var todoSongs = SongStore.getTodos().size();
				if (todoSongs > songs) {
					songs = todoSongs;
				}
				if (songs > 0) {
					return songs + " songs waiting";
				}
				if (changes || (SongStore.getDeletes().size() > 0)) {
					return WatchUi.loadResource(Rez.Strings.SyncChangesWaiting);
				}
				return null;
			}

			static function hasPendingChanges() {
				return getPendingSummary() != null;
			}
			
			static function getLastSyncString() {
				var lastsync = Application.Storage.getValue(Storage.LAST_SYNC);
		        var sublabel = null;
		        if ((lastsync != null) && (lastsync["time"] instanceof Lang.Number)) {
		        	var moment = new Time.Moment(lastsync["time"]);
			        var info = Time.Gregorian.info(moment, Time.FORMAT_MEDIUM);
			        sublabel = Lang.format("$1$ $2$ $3$ - $4$:$5$", [ info.day, info.month, info.year, info.hour, info.min.format("%02d") ]);
	        	}
	        	return sublabel;
			}
			
			static function onStartSync() {
				// store sync request, refer to bug https://forums.garmin.com/developer/connect-iq/i/bug-reports/bug-media-communications-syncdelegate-blocks-charging
				Application.Storage.setValue(Storage.SYNC_REQUEST, true);
				// var syncrequest  = Application.Storage.getValue(Storage.SYNC_REQUEST);
				// if ($.debug) {
				// 	System.println(syncrequest);
				// }
				
				// start the sync
				Communications.startSync();
			}
			
		}
	}
}
