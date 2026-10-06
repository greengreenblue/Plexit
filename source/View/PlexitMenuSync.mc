using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Time;

using Plexit.Menu;
using Plexit.Storage;

module Plexit {
	module Menu {
		class Sync extends MenuBase {
			
			hidden var d_items = [];

			function initialize() {
				MenuBase.initialize(WatchUi.loadResource(Rez.Strings.confSync_Title), false);
			}

			function load() {
				return MenuBase.load([
					{
						LABEL => Menu.AddMusic.getSyncLabel(),
						SUBLABEL => Menu.AddMusic.getSyncStatus(),
						METHOD => method(:onStartSync),
					},
					new Menu.PlaylistsRemoteToggle(WatchUi.loadResource(Rez.Strings.Playlists_label)),
				]);
			}
			
			function getLastSyncString() {
				var lastsync = Application.Storage.getValue(Storage.LAST_SYNC);
		        var sublabel = null;
		        if ((lastsync != null) && (lastsync["time"] instanceof Lang.Number)) {
		        	var moment = new Time.Moment(lastsync["time"]);
			        var info = Time.Gregorian.info(moment, Time.FORMAT_MEDIUM);
			        sublabel = Lang.format("$1$ $2$ $3$ - $4$:$5$", [ info.day, info.month, info.year, info.hour, info.min ]);
	        	}
	        	return sublabel;
			}
			
			function onStartSync() {
				if (!PlexAccount.isConnected()) {
					WatchUi.pushView(new PlexLoginView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_IMMEDIATE);
					return;
				}
				// store sync request, refer to bug https://forums.garmin.com/developer/connect-iq/i/bug-reports/bug-media-communications-syncdelegate-blocks-charging
				Application.Storage.setValue(Storage.SYNC_REQUEST, true);
				// var syncrequest  = Application.Storage.getValue(Storage.SYNC_REQUEST);
				
				// start the sync
				if (Communications has :startSync2) {
					Communications.startSync2({
						:message => WatchUi.loadResource(Rez.Strings.SyncingMusicMessage),
					});
				} else {
					Communications.startSync();
				}
			}

			// 
			function delegate() {
				return new SyncDelegate(method(:onBack));
			}
			
			function onBack() { return false; }

			// pop the view method for onBack behaviour
			function pop() {
				WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
			}
		}

		class SyncDelegate extends MenuDelegate {
			function initialize(callOnBack) {
				MenuDelegate.initialize(null, callOnBack);
				// all ids are methods and action on Back is given
			}
		}
	}
}
