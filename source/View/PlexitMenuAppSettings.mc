using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Media;
using Plexit.Storage;

module Plexit {
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
						LABEL => WatchUi.loadResource(Rez.Strings.PlexServerAddress),
						SUBLABEL => method(:serverAddress),
						METHOD => method(:onServerAddress),
					},
					{
                        LABEL => WatchUi.loadResource(Rez.Strings.UseAutomaticAddress),
                        SUBLABEL => null,
                        METHOD => method(:onAutomaticAddress),
                    },
					{
						LABEL => WatchUi.loadResource(Rez.Strings.skip_30s),
						SUBLABEL => WatchUi.loadResource(Rez.Strings.skip_30s_sublabel),
						METHOD => method(:onToggleSkip30s),
						OPTION => method(:stateSkip30s),
					},
					{
						LABEL => WatchUi.loadResource(Rez.Strings.prefer_musicbrainz_artwork),
						SUBLABEL => null,
						METHOD => method(:onToggleMusicBrainzArtwork),
						OPTION => method(:stateMusicBrainzArtwork),
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

			function serverAddress() {
				var custom = Application.Storage.getValue(Storage.PLEX_CUSTOM_SERVER_URL);
				if (custom != null) { return custom; }
				return Application.Storage.getValue(Storage.PLEX_SERVER_URL);
			}

			function onServerAddress() {
				if (!PlexAccount.isConnected()) { onPlexSignIn(); return; }
				WatchUi.pushView(new WatchUi.TextPicker(serverAddress()),
					new PlexServerAddressDelegate(), WatchUi.SLIDE_IMMEDIATE);
			}

            function onAutomaticAddress() {
                Plexit.Menu.clearServerAddress(Application.Storage.getValue(Storage.PLEX_SERVER_ID));
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
				Application.Properties.setValue(
					"skip_30s", 
					!Application.Properties.getValue("skip_30s"));
				Media.requestPlaybackProfileUpdate();
			}

			function stateMusicBrainzArtwork() {
				return Application.Properties.getValue("prefer_musicbrainz_artwork");
			}

			function onToggleMusicBrainzArtwork() {
				Application.Properties.setValue(
					"prefer_musicbrainz_artwork",
					!stateMusicBrainzArtwork());
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
