using Toybox.WatchUi;
using Plexit.Menu;

module Plexit {
	module Menu {
		class Playback extends MenuBase {

			function initialize() {
				MenuBase.initialize(WatchUi.loadResource(Rez.Strings.confPlayback_Title), false);
			}

			function load() {
				return MenuBase.load([
					{
						LABEL => WatchUi.loadResource(Rez.Strings.confPlayback_PlayAll_label),
						SUBLABEL => null,
						METHOD => method(:onPlayAll),
					},
					{
						LABEL => WatchUi.loadResource(Rez.Strings.Menu_PlayShuffle_label),
						SUBLABEL => WatchUi.loadResource(Rez.Strings.ShuffleAll_sublabel),
						METHOD => method(:onShuffleAll),
					},
					new Menu.PlaylistsLocal(WatchUi.loadResource(Rez.Strings.playbackMenuTitle)),
					new Menu.AddMusic(),
					new Menu.Settings(),
				]);
			}

			// plays all songs
			static function onPlayAll() {
				var iplayable = new Plexit.IPlayable();
				iplayable.loadSongIds(SongStore.getIds());
				Media.startPlayback(null);
			}

			static function onShuffleAll() {
				var iplayable = new Plexit.IPlayable();
				iplayable.loadSongIds(SongStore.getIds());
				iplayable.shuffleIdcs(true);
				Media.startPlayback(null);
			}
		}
	}
}
