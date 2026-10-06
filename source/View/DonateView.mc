using Toybox.Graphics;
using Toybox.WatchUi;

class DonateView extends WatchUi.View {

	private var d_qrCode;

	function initialize() {
		View.initialize();
		d_qrCode = WatchUi.loadResource(Rez.Drawables.SponsorsQrCode);
	}

	function onUpdate(dc) {
		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
		dc.clear();

		var centerX = dc.getWidth() / 2;
		var qrWidth = d_qrCode.getWidth();
		var qrHeight = d_qrCode.getHeight();
		var qrY = (dc.getHeight() - qrHeight) / 2;

		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
		dc.drawText(
			centerX,
			qrY - 24,
			Graphics.FONT_TINY,
			WatchUi.loadResource(Rez.Strings.Donate_title),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

		dc.drawBitmap(centerX - (qrWidth / 2), qrY, d_qrCode);

		dc.drawText(
			centerX,
			qrY + qrHeight + 16,
			Graphics.FONT_XTINY,
			WatchUi.loadResource(Rez.Strings.Donate_scan),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
}
