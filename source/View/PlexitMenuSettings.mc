using Toybox.WatchUi;
using Toybox.Communications;
using Toybox.Application;
using Plexit.Menu;

module Plexit {
	module Menu {
		class Settings extends MenuBase {

			function initialize() {
				MenuBase.initialize(WatchUi.loadResource(Rez.Strings.Settings_label), false);
			}

			function load() {
				return MenuBase.load([
					new Menu.AppSettings(),
					new Menu.Storage(),
					{
						LABEL => WatchUi.loadResource(Rez.Strings.Donate_label), 
						SUBLABEL => null, 
						METHOD => method(:onDonate),
					},
				]);
			}
			
			static function onDonate() {
				WatchUi.pushView(new DonateView(), new DonateDelegate(), WatchUi.SLIDE_IMMEDIATE);
			}
		}
	}
}
