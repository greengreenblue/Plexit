using Toybox.Communications;
using Toybox.Timer;

// Each network attempt owns its callback, so a late response after the
// application deadline cannot finish a newer attempt.
class PlexServerAttempt {
    private var d_request;
    private var d_number;
    function initialize(request, number) { d_request = request; d_number = number; }
    function response(code, data) { d_request.onAttemptResponse(d_number, code, data); }
    function expired() {
        d_request.onAttemptResponse(d_number, Communications.NETWORK_REQUEST_TIMED_OUT, null);
    }
}

// One bounded retry chain per request. The original path, parameters and
// download options survive a change of server address unchanged.
class PlexServerRequest {
    private var d_urls;
    private var d_path;
    private var d_params;
    private var d_options;
    private var d_callback;
    private var d_selected;
    private var d_retry;
    private var d_index = 0;
    private var d_failure = null;
    private var d_timer = null;
    private var d_attempt = 0;

    function setFailureCallback(callback) { d_failure = callback; }

    function initialize(urls, path, params, options, callback, selected, retry) {
        d_urls = urls;
        d_path = path;
        d_params = params;
        d_options = options;
        d_callback = callback;
        d_selected = selected;
        d_retry = retry;
    }

    function start() {
        if (d_callback == null) { return; }
        sendRequest(d_urls[d_index] + d_path, d_params, d_options);
    }

    function cancel() { stopTimer(); d_callback = null; }

    function stopTimer() {
        if (d_timer != null) { d_timer.stop(); d_timer = null; }
    }

    function sendRequest(url, params, options) {
        d_attempt += 1;
        var attempt = new PlexServerAttempt(self, d_attempt);
        // Fetch metadata has a short deadline. Audio downloads retain the
        // host timeout because transferring a song can legitimately take longer.
        if ((options[:responseType] == null)
            || (options[:responseType] == Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON)) {
            d_timer = new Timer.Timer();
            d_timer.start(attempt.method(:expired), 15000, false);
        }
        Communications.makeWebRequest(url, params, options, attempt.method(:response));
    }

    function onAttemptResponse(number, code, data) {
        if ((number != d_attempt) || (d_callback == null)) { return; }
        // Invalidate this attempt even when its timer fired before the host
        // completed the underlying request.
        d_attempt += 1;
        onResponse(code, data);
    }

    static function canRetry(code) {
        // Never turn cancellation, response-size limits, invalid media or
        // authentication errors into a new network request.
        return (code == Communications.UNKNOWN_ERROR)
            || (code == Communications.BLE_ERROR)
            || (code == Communications.BLE_NO_DATA)
            || (code == Communications.BLE_HOST_TIMEOUT)
            || (code == Communications.BLE_SERVER_TIMEOUT)
            || (code == Communications.BLE_CONNECTION_UNAVAILABLE)
            || (code == Communications.NETWORK_REQUEST_TIMED_OUT)
            || (code == Communications.REQUEST_CONNECTION_DROPPED)
            || (code == Communications.SECURE_CONNECTION_REQUIRED)
            || (code == 502) || (code == 503) || (code == 504);
    }

    function onResponse(code, data) {
        if (d_callback == null) { return; }
        stopTimer();
        // An unreachable endpoint can surface as HTTP 404 in the simulator
        // or an intermediary. Try the same read on the other addresses of
        // this server before declaring the item missing. A final 404 still
        // reaches the caller unchanged; writes are never replayed.
        if (d_retry && (canRetry(code) || (code == 404)) && ((d_index + 1) < d_urls.size())) {
            d_index += 1;
            System.println("Plex connection failed (" + code + "); trying address "
                + (d_index + 1) + "/" + d_urls.size());
            start();
            return;
        }
        var callback = d_callback;
        d_callback = null;
        if ((code >= 200) && (code < 300)) { d_selected.invoke(d_urls[d_index]); }
        else if (d_failure != null) { d_failure.invoke(code); }
        callback.invoke(code, data);
    }
}
