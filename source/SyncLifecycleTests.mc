using Toybox.Application;

(:test)
class DownloadProgressProbe extends Api {
    var values = [];
    function initialize() { Api.initialize(""); setProgressCallback(method(:progressValue)); }
    function progressValue(value) { values.add(value); }
}

(:test)
function estimatedDownloadMovesWithBytesAndNeverCompletesEarly(logger) {
    var api = new DownloadProgressProbe();
    api.setDownloadEstimate(1000);
    api.beginDownloadProgress();
    api.onProgress(250, null);
    api.onProgress(500, null);
    api.onProgress(1100, null);
    api.onProgress(100, null);
    var ok = (api.values.size() == 3) && (api.values[0] == 25)
        && (api.values[1] == 50) && (api.values[2] == 95) && (api.downloadBytes() == null);
    api.finishDownloadProgress();
    return ok && (api.downloadBytes() == 100);
}

(:test)
function knownDownloadSizeOverridesEstimateAndSurvivesMissingLength(logger) {
    var api = new DownloadProgressProbe();
    api.setDownloadEstimate(2000);
    api.beginDownloadProgress();
    api.onProgress(500, 1000);
    api.onProgress(750, null);
    api.onProgress(1000, null);
    return (api.values[0] == 50) && (api.values[1] == 75)
        && (api.values[2] == 99) && (api.downloadBytes() == 1000);
}

(:test)
class SyncTaskProbe extends Deferrable {
    var writes = 0;
    var completed = 0;
    var failed = 0;
    function initialize() { Deferrable.initialize(method(:work), method(:done), method(:fail)); }
    function work() { return Deferrable.defer(); }
    function deliver() { if (!isActive()) { return; } writes += 1; Deferrable.complete(); }
    function done() { completed += 1; }
    function fail(error) { failed += 1; }
}

(:test)
function stoppedAndReplacedSyncIgnoreOldTaskCallbacks(logger) {
    PlexSyncSession.begin();
    var old = new SyncTaskProbe();
    old.run();
    PlexSyncSession.stop();
    old.deliver();
    PlexSyncSession.begin();
    var current = new SyncTaskProbe();
    current.run();
    old.deliver();
    current.deliver();
    current.deliver();
    var ok = (old.writes == 0) && (old.completed == 0)
        && (current.writes == 1) && (current.completed == 1);
    PlexSyncSession.stop();
    return ok;
}

(:test)
function stoppedSyncIgnoresLateTransportAndProgress(logger) {
    PlexSyncSession.begin();
    var api = new DownloadProgressProbe();
    api.setDownloadEstimate(1000);
    api.beginDownloadProgress();
    var request = new ServerRequestProbe(["https://local", "https://remote"], true);
    request.start();
    PlexSyncSession.stop();
    api.onProgress(500, null);
    request.onResponse(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    return (api.values.size() == 0) && (request.sent.size() == 1) && (request.callbacks == 0);
}

(:test)
function metadataCompletionDoesNotClaimMissingAudioIsDownloaded(logger) {
    var state = new MultiServerTestState();
    var song = new Song({"id" => "sync-status-song", "title" => "Test"});
    SongStore.save(song);
    var selection = new IPlaylist("sync-status-playlist");
    selection.updateMeta(new Playlist({"id" => "sync-status-playlist", "name" => "Test", "remote" => true}));
    selection.setLocal(true);
    selection.link();
    selection.update([song]);
    selection.setMetadataSynced(true);
    var missing = !selection.synced() && !selection.refreshSyncState();
    var stored = new ISong(song.id());
    stored.setRefId(12345);
    var complete = selection.refreshSyncState();
    selection.setMetadataSynced(false);
    var metadataFailure = !selection.refreshSyncState();
    state.restore();
    return missing && complete && metadataFailure;
}

(:test)
class LoginDeadlineProbe extends PlexLoginView {
    var now = 0;
    var sent = [];
    var reply = null;
    var cancellations = 0;
    var acknowledgeCancel = true;
    var errors = 0;
    var questions = 0;
    var internetQuestions = 0;
    var text = "";
    function initialize() { PlexLoginView.initialize(); }
    function requestPin() {}
    function discoverServers(token) {}
    function connectionClock() { return now; }
    function setText(value) { text = value; }
    function showError(message, code) { errors += 1; }
    function showHomeNetworkQuestion(name) { questions += 1; }
    function showInternetQuestion(name) { internetQuestions += 1; }
    function sendProbe(uri, token, callback) { sent.add(uri); reply = callback; }
    function cancelLoginRequests() {
        cancellations += 1;
        if (acknowledgeCancel && (reply != null)) {
            var callback = reply;
            reply = null;
            callback.invoke(Toybox.Communications.REQUEST_CANCELLED, null);
        }
    }
}

(:test)
class DeadlineTestFixture {
static function resources() {
    return [{"name" => "Deadline test", "clientIdentifier" => "deadline-server",
        "provides" => "server", "owned" => true, "accessToken" => "test-token",
        "connections" => [
            {"uri" => "https://local", "protocol" => "https", "local" => true},
            {"uri" => "https://remote", "protocol" => "https", "local" => false},
            {"uri" => "https://relay", "protocol" => "https", "local" => false, "relay" => true}
        ]}];
}
}

(:test)
function loginCancelsBeforeFallbackAndLabelsAddressGroups(logger) {
    var state = new MultiServerTestState();
    var login = new LoginDeadlineProbe();
    var resources = DeadlineTestFixture.resources();
    login.rememberDiscoveredServers(resources);
    PlexServers.setConnectionMode("deadline-server", PlexServers.CONNECTION_AUTO);
    login.onShow();
    login.onServersDiscovered(200, resources, "test-token");
    var localLabel = Plexit.I18n.text(Rez.Strings.TryLocalAddress, [1, 1]);
    var local = (login.sent.size() == 1) && (login.text.find(localLabel) == 0);
    login.now = 2000;
    login.updateProbeCountdown();
    var waited = (login.cancellations == 1) && (login.sent.size() == 1);
    login.continueProbe();
    var remoteLabel = Plexit.I18n.text(Rez.Strings.TryRemoteAddress, [1, 2]);
    var remote = (login.sent.size() == 2) && (login.text.find(remoteLabel) == 0);
    login.onHide();
    state.restore();
    return local && waited && remote;
}

(:test)
function missingCancellationCallbackStopsInsteadOfOverlapping(logger) {
    var state = new MultiServerTestState();
    var login = new LoginDeadlineProbe();
    var resources = DeadlineTestFixture.resources();
    login.rememberDiscoveredServers(resources);
    PlexServers.setConnectionMode("deadline-server", PlexServers.CONNECTION_AUTO);
    login.onShow();
    login.onServersDiscovered(200, resources, "test-token");
    login.acknowledgeCancel = false;
    login.now = 2000;
    login.updateProbeCountdown();
    login.now = 7000;
    login.updateProbeCountdown();
    var ok = (login.sent.size() == 1) && (login.errors == 1) && (login.cancellations == 1);
    login.onHide();
    state.restore();
    return ok;
}

(:test)
function newServerAsksBeforeSendingAndNoSelectsInternetOnly(logger) {
    var state = new MultiServerTestState();
    var login = new LoginDeadlineProbe();
    login.onShow();
    login.onServersDiscovered(200, DeadlineTestFixture.resources(), "test-token");
    var before = (login.questions == 1) && (login.sent.size() == 0);
    login.onHomeNetworkChoice(false);
    login.continueConnectionSetup();
    var after = (login.sent.size() == 1) && login.sent[0].equals("https://remote")
        && PlexServers.connectionMode(PlexServers.get("deadline-server")).equals(PlexServers.CONNECTION_INTERNET);
    login.onHide();
    state.restore();
    return before && after;
}

(:test)
class TwoServerLoginFixture {
    static function resources() {
        return [DeadlineTestFixture.resources()[0], {
            "name" => "Offline share", "clientIdentifier" => "second-server",
            "provides" => "server", "owned" => false, "accessToken" => "second-token",
            "connections" => [
                {"uri" => "https://second-remote", "protocol" => "https", "local" => false},
                {"uri" => "https://second-relay", "protocol" => "https", "local" => false, "relay" => true}
            ]}];
    }
    static function prepare(login, resources, secondMode) {
        login.rememberDiscoveredServers(resources);
        PlexServers.setConnectionMode("deadline-server", PlexServers.CONNECTION_AUTO);
        PlexServers.setConnectionMode("second-server", secondMode);
        login.onShow();
        login.onServersDiscovered(200, resources, "account-token");
        login.reply.invoke(200, {"MediaContainer" => {}});
        login.continueConnectionSetup();
        login.reply.invoke(Toybox.Communications.NETWORK_REQUEST_TIMED_OUT, null);
        login.continueProbe();
        login.reply.invoke(Toybox.Communications.NETWORK_REQUEST_TIMED_OUT, null);
        login.continueProbe();
    }
}

(:test)
function offlineInternetOnlyShareKeepsWorkingServerWithoutRepeatQuestion(logger) {
    var state = new MultiServerTestState();
    var login = new LoginDeadlineProbe();
    TwoServerLoginFixture.prepare(login, TwoServerLoginFixture.resources(), PlexServers.CONNECTION_INTERNET);
    login.continueConnectionSetup();
    var first = PlexServers.get("deadline-server");
    var second = PlexServers.get("second-server");
    var ok = (login.errors == 0) && (login.internetQuestions == 0) && (login.sent.size() == 3)
        && first["status"].equals("online") && second["status"].equals("offline")
        && Application.Storage.getValue(Plexit.Storage.PLEX_SERVER_ID).equals("deadline-server");
    login.onHide();
    state.restore();
    return ok;
}

(:test)
function internetRetryIsRestrictedToFailedServerAndPreservesFirstSuccess(logger) {
    var state = new MultiServerTestState();
    var login = new LoginDeadlineProbe();
    TwoServerLoginFixture.prepare(login, TwoServerLoginFixture.resources(), PlexServers.CONNECTION_AUTO);
    var offered = (login.internetQuestions == 1);
    login.onInternetChoice(true);
    login.now += 60000;
    login.waitForConnection();
    var scoped = (login.sent.size() == 4) && login.sent[3].equals("https://second-remote");
    login.reply.invoke(200, {"MediaContainer" => {}});
    login.continueConnectionSetup();
    var ok = offered && scoped && (login.errors == 0)
        && PlexServers.connectionMode(PlexServers.get("second-server")).equals(PlexServers.CONNECTION_INTERNET)
        && PlexServers.connectionMode(PlexServers.get("deadline-server")).equals(PlexServers.CONNECTION_AUTO)
        && Application.Storage.getValue(Plexit.Storage.PLEX_SERVER_ID).equals("deadline-server")
        && PlexServers.get("deadline-server")["status"].equals("online")
        && PlexServers.get("second-server")["status"].equals("online");
    login.onHide();
    state.restore();
    return ok;
}
