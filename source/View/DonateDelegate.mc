 class DonateDelegate extends TapDelegate {
 	
	function initialize() {
		TapDelegate.initialize(method(:openLink));
	}

	function openLink() {
		Communications.openWebPage(
			"https://ko-fi.com/martinbernat",
			null,
			null
		);
	}
}
