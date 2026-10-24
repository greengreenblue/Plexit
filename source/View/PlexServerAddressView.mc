using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.Timer;
using Toybox.WatchUi;

class PlexServerAddressDelegate extends WatchUi.TextPickerDelegate {
    private var d_timer;
    private var d_url;
    private var d_serverId;

    function initialize() {
        TextPickerDelegate.initialize();
        d_serverId = Application.Storage.getValue(Plexit.Storage.PLEX_SERVER_ID);
    }

    function setServerId(id) { d_serverId = id; }

    function onTextEntered(text, changed) {
        if (!changed) { return true; }
        d_url = text;
        // Let Garmin close its native picker before pushing another view.
        d_timer = new Timer.Timer();
        d_timer.start(method(:checkAddress), 100, false);
        return true;
    }

    function onCancel() { return true; }

    function checkAddress() {
        d_timer = null;
        WatchUi.pushView(new PlexServerAddressView(d_url, d_serverId),
            new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }
}

// Keep the existing account and downloaded music; only replace the server URL
// after identity and library access checks succeed with the saved server token.
class PlexServerAddressView extends TextView {
    private var d_url;
    private var d_serverId;
    private var d_token;
    private var d_active = false;
    private var d_started = false;

    function initialize(url, serverId) {
        TextView.initialize(WatchUi.loadResource(Rez.Strings.FindingPlexServer));
        d_url = url;
        d_serverId = serverId;
        var record = PlexServers.get(serverId);
        d_token = (record != null) ? record["token"]
            : Application.Storage.getValue(Plexit.Storage.PLEX_SERVER_TOKEN);
    }

    function onShow() {
        d_active = true;
        if (d_started) { return; }
        d_started = true;
        if ((d_url instanceof Lang.String) && d_url.equals("")) {
            var cleared = PlexAccount.clearServerAddressFor(d_serverId);
            setText(WatchUi.loadResource(cleared ? Rez.Strings.AutomaticAddressEnabled : Rez.Strings.NoReachablePlexServer));
            return;
        }
        if (!isValidAddress(d_url)) {
            setText(WatchUi.loadResource(Rez.Strings.PlexInvalidServerAddress));
            return;
        }
        while (d_url.substring(d_url.length() - 1, d_url.length()).equals("/")) {
            d_url = d_url.substring(0, d_url.length() - 1);
        }
        requestIdentity(d_token, method(:onIdentity));
    }

    static function isValidAddress(url) {
        return (url instanceof Lang.String) && (url.length() > 8)
            && (url.find("https://") == 0) && (url.find(" ") == null)
            && (url.find("\n") == null) && (url.find("\r") == null)
            && (url.find("@") == null) && (url.find("?") == null)
            && (url.find("#") == null) && !url.substring(8, 9).equals("/");
    }

    function onHide() { d_active = false; }

    function requestIdentity(token, callback) {
        Communications.makeWebRequest(d_url + "/identity", null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => PlexAccount.headers(token),
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        }, callback);
    }

    function identityId(code, data) {
        if ((code == 200) && (data instanceof Lang.Dictionary)
            && (data["MediaContainer"] instanceof Lang.Dictionary)) {
            return data["MediaContainer"]["machineIdentifier"];
        }
        return null;
    }

    function onIdentity(code, data) {
        if (!d_active) { return; }
        var id = identityId(code, data);
        if (!(id instanceof Lang.String)) {
            failed(code);
            return;
        }
        // /identity itself may be public. Verify access to a protected endpoint
        // before replacing the previously saved connection.
        Communications.makeWebRequest(d_url + "/library/sections", null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => PlexAccount.headers(d_token),
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        }, method(:onAuthorized));
    }

    function onAuthorized(code, data) {
        if (!d_active) { return; }
        if ((code != 200) || !(data instanceof Lang.Dictionary)
            || !(data["MediaContainer"] instanceof Lang.Dictionary)) {
            failed(code);
            return;
        }
        PlexAccount.setServerAddressFor(d_serverId, d_url);
        setText(WatchUi.loadResource(Rez.Strings.PlexServerAddressSaved));
    }

    function failed(code) {
        setText(WatchUi.loadResource(Rez.Strings.NoReachablePlexServer)
            + "\n" + Plexit.I18n.text(Rez.Strings.ErrorCode, [code]));
    }
}
