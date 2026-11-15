using Toybox.Lang;
using Toybox.Media;
using Toybox.System;
using Toybox.WatchUi;
using Plexit;

class Api {

    private var d_client;    // the client name

    // callbacks
    hidden var d_callback;  // callback for finished request
    hidden var d_fallback;  // fallback for failed request
    hidden var d_progress;  // intermediate callback to update request progress

    // settings
    private var d_url_add;  // specific addition to the base url
    private var d_url;      // the base url for the api
    private var d_usr;      // the user 
    private var d_key;      // the key used to login
	private var d_lastProgressBytes = 0;
    private var d_progressLogTime = null;
    private var d_estimatedDownloadBytes = null;
    private var d_reportedDownloadProgress = 0;
    private var d_progressSession = null;
	private var d_downloadBytes = null;


    function initialize(url_add) {
        d_url_add = url_add;
        d_client = (WatchUi.loadResource(Rez.Strings.AppName) + "-v" + (new PlexitVersion(null).toString()));
    }

    function client() {
        return d_client;
    }

    function url() {
        return d_url + d_url_add;
    }

    function usr() {
        return d_usr;
    }

    function key() {
        return d_key;
    }

    function update(settings) {
        updateUrl(settings.get("api_url"));
        updateUsr(settings.get("api_usr"));
        updateKey(settings.get("api_key"));
    }
    
    function updateUrl(url) {
        d_url = url;
    }

    function updateUsr(usr) {
        d_usr = usr;
    }

    function updateKey(key) {
        d_key = key;
    }

    /*
	 * checkResponse
	 *
	 * returns http/sdk errors if found
	 */
	function checkResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) {
		var error = Plexit.HttpError.is(responseCode);
		if (error) { return error; }
		error = Plexit.GarminSdkError.is(responseCode);
        if (error) { return error; }
        return self.checkApiError(responseCode, data);
    }

    function checkApiError(responseCode, data) {
        return null;
    }

    function checkDictionaryResponse(responseCode as Lang.Number, data as Lang.Dictionary or Null) {
        var error = checkResponse(responseCode, data);
        if (error) { return error; }
        return isDictionary(data);      // check type of received object
    }

    function checkArrayResponse(responseCode, data) {
        var error = checkResponse(responseCode, data);
        if (error) { return error; }
        return isArray(data);           // check type of received object
    }

    static function isDictionary(data) {
        // check type of received object
        if (data instanceof Lang.Dictionary) { return null; }
        return new Plexit.ApiError(Plexit.ApiError.BADRESPONSE);
    }

    static function isArray(data) {
        // check type of received object
        if (data instanceof Lang.Array) { return null; }
        return new Plexit.ApiError(Plexit.ApiError.BADRESPONSE);
    }

    function checkContentResponse(responseCode, data) {
        var error = checkResponse(responseCode, data);
        if (error) { return error; }

        // check type of received object
        if (data instanceof Media.ContentRef) { return null; }
        return new Plexit.ApiError(Plexit.ApiError.BADRESPONSE);
    }

	function checkImageResponse(responseCode, data) {
        var error = checkResponse(responseCode, data);
        if (error) { return error; }

        // check type of received object
		// makeImageRequest returns BitmapResource on older devices and
		// BitmapReference on API 4+ devices. Avoid a static reference to the newer
		// class so this PRG remains loadable on API 3 devices.
		if (data != null) { return null; }
        return new Plexit.ApiError(Plexit.ApiError.BADRESPONSE);
    }

    function setDownloadEstimate(bytes) {
        d_estimatedDownloadBytes = ((bytes != null) && (bytes > 0)) ? bytes : null;
    }

    function onProgress(totalBytesTransferred, fileSize) {
        if (!PlexSyncSession.valid(d_progressSession)) { return; }
        if (totalBytesTransferred < d_lastProgressBytes) { d_downloadBytes = null; }
        d_lastProgressBytes = totalBytesTransferred;
        var total = (d_downloadBytes != null) ? d_downloadBytes : d_estimatedDownloadBytes;
        var limit = (d_downloadBytes != null) ? 99 : 95;
        if ((fileSize != null) && (fileSize > 0)) {
            d_downloadBytes = fileSize;
            total = fileSize;
            limit = 99;
        }
        if ((total != null) && (total > 0)) {
            var progress = 100.0 * totalBytesTransferred / total.toFloat();
            if (progress > limit) { progress = limit; }
            if (progress > d_reportedDownloadProgress) {
                d_reportedDownloadProgress = progress;
                if (d_progress != null) { d_progress.invoke(progress); }
            }
        }
        var now = System.getTimer();
        if ((d_progressLogTime == null) || ((now - d_progressLogTime) >= 10000)) {
            Plexit.Utils.log("Audio download: " + totalBytesTransferred + " bytes; "
                + ((fileSize != null && fileSize > 0) ? "total=" + fileSize
                    : ((total != null) ? "estimated total=" + total : "total unknown")));
            d_progressLogTime = now;
        }
    }

    function beginDownloadProgress() {
        d_progressSession = PlexSyncSession.token();
        d_lastProgressBytes = 0;
        d_downloadBytes = null;
        d_progressLogTime = null;
        d_reportedDownloadProgress = 0;
    }

    function finishDownloadProgress() {
        if (d_downloadBytes == null && d_lastProgressBytes > 0) { d_downloadBytes = d_lastProgressBytes; }
        // Item completion is reported by AudioSync after the ContentRef is saved.
    }

	function downloadBytes() {
		return d_downloadBytes;
	}

    function setCallback(callback) {
        d_callback = callback;
    }

    function setFallback(fallback) {
        d_fallback = fallback;
    }

    function setProgressCallback(progress) {
        d_progress = progress;
    }
}
