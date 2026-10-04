using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Media;
using SubMusic.Storage;

module SubMusic {
	module Menu {
		class AppSettings extends MenuBase {

			function initialize() {
				MenuBase.initialize(WatchUi.loadResource(Rez.Strings.PlexPlayback_label), false);
			}

			function load() {
				return MenuBase.load([
					{
						LABEL => WatchUi.loadResource(Rez.Strings.PlexSignIn),
						SUBLABEL => method(:plexStatus),
						METHOD => method(:onPlexSignIn),
					},
					{
						LABEL => WatchUi.loadResource(Rez.Strings.skip_30s),
						SUBLABEL => WatchUi.loadResource(Rez.Strings.skip_30s_sublabel),
						METHOD => method(:onToggleSkip30s),
						OPTION => method(:stateSkip30s),
					},
				]);
			}

			function plexStatus() {
				var serverName = Application.Storage.getValue(Storage.PLEX_SERVER_NAME);
				if (serverName == null) {
					return WatchUi.loadResource(Rez.Strings.PlexNotConnected);
				}
				return serverName;
			}

			function onPlexSignIn() {
				WatchUi.pushView(new PlexLoginView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_IMMEDIATE);
			}

			function onDetail(item as WatchUi.MenuItem) {
				WatchUi.pushView(new TextView(item.getSubLabel()), null, WatchUi.SLIDE_IMMEDIATE);
			}

			function stateSkip30s() {
				return Application.Properties.getValue("skip_30s");
			}

			function onToggleSkip30s() {
				var skip30s_new = !Application.Properties.getValue("skip_30s");

				Application.Properties.setValue("skip_30s", !Application.Properties.getValue("skip_30s"));
				Media.requestPlaybackProfileUpdate();
			}

			function delegate() {
				return new MenuDelegate(method(:onDetail), null);
			}
			
			static function onDonate() {
				WatchUi.pushView(new DonateView(), new DonateDelegate(), WatchUi.SLIDE_IMMEDIATE);
			}
		}
	}
}
