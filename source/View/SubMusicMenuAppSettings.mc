using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Media;
using SubMusic.Storage;

module SubMusic {
	module Menu {
		class AppSettings extends MenuBase {

			function initialize() {
				MenuBase.initialize(WatchUi.loadResource(Rez.Strings.AppSettings_label), false);
			}

			function load() {
				if ($.debug) {
					System.println("Menu.AppSettings::load()");
				}
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
					{
						LABEL => WatchUi.loadResource(Rez.Strings.debug),
						SUBLABEL => WatchUi.loadResource(Rez.Strings.debug_sublabel),
						METHOD => method(:onToggleDebug),
						OPTION => method(:stateDebug),
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
				if ($.debug) {
					System.println("Setting skip_30s from " + Application.Properties.getValue("skip_30s") + " to " + skip30s_new);
				}

				Application.Properties.setValue("skip_30s", !Application.Properties.getValue("skip_30s"));
				Media.requestPlaybackProfileUpdate();
			}

			function stateDebug() {
				return Application.Properties.getValue("debug");
			}

			function onToggleDebug() {
				var debug_new = !Application.Properties.getValue("debug");
				if ($.debug) {
					System.println("Setting debug from " + Application.Properties.getValue("debug") + " to " + debug_new);
				}

				Application.Properties.setValue("debug", debug_new);
				$.debug = debug_new;	// update the global debug flag
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
