// Compile with monkeyc -t and run with monkeydo ... -t.
(:test)
function selectsHttpsConnection(logger) {
    var login = new PlexLoginView();
    // Construct a network-like string instead of reusing the HTTPS literal.
    var protocol = "xhttps".substring(1, 6);
    var resources = [{
        "name" => "Test", "provides" => "server", "owned" => true,
        "accessToken" => "test-token",
        "connections" => [
            { "uri" => "http://local", "protocol" => "http", "local" => true },
            { "uri" => "https://public", "protocol" => protocol, "local" => false },
        ],
    }];
    return login.selectServer(resources, [])["uri"].equals("https://public");
}

(:test)
function skipsFailedServerConnections(logger) {
    var login = new PlexLoginView();
    var resources = [{
        "name" => "Test", "provides" => "server", "owned" => true,
        "accessToken" => "test-token",
        "connections" => [
            { "uri" => "https://local", "protocol" => "https", "local" => true },
            { "uri" => "https://public", "protocol" => "https", "local" => false },
        ],
    }];
    var next = login.selectServer(resources, ["https://local"]);
    return next["uri"].equals("https://public")
        && (login.selectServer(resources, ["https://local", "https://public"]) == null);
}

(:test)
function selectsNetworkHttpsArtwork(logger) {
    var login = new PlexLoginView();
    return login.findArtworkConnection([
        { "uri" => "https://public", "protocol" => "xhttps".substring(1, 6), "local" => false },
    ]).equals("https://public");
}

(:test)
function validatesCustomServerAddress(logger) {
    return PlexServerAddressView.isValidAddress("https://plex.example")
        && PlexServerAddressView.isValidAddress("https://server.example:32400/")
        && !PlexServerAddressView.isValidAddress("http://server.example")
        && !PlexServerAddressView.isValidAddress("https:///missing-host")
        && !PlexServerAddressView.isValidAddress("https://user:secret@server.example")
        && !PlexServerAddressView.isValidAddress("https://server.example?token=secret")
        && !PlexServerAddressView.isValidAddress("https://server.example\n")
        && !PlexServerAddressView.isValidAddress(null);
}

// Transport double: exercise the real retry chain without contacting a server.
(:test)
class ServerRequestProbe extends PlexServerRequest {
    var sent = [];
    var parameters;
    var options;
    var result = null;
    var selected = null;
    var callbacks = 0;

    function initialize(urls, retry) {
        parameters = { "X-Plex-Token" => "test-token", "X-Plex-Container-Start" => 20 };
        options = { :responseType => Toybox.Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON };
        PlexServerRequest.initialize(urls, "/library/sections/3/all", parameters,
            options, method(:finished), method(:working), retry);
        setCompatibility(false);
    }

    function sendRequest(url, params, requestOptions) {
        sent.add(url);
        if ((params != parameters) || (requestOptions != options)) { callbacks = -100; }
    }
    function finished(code, data) { result = code; callbacks += 1; }
    function working(uri) { selected = uri; }
}

(:test)
function retriesAnotherAddressAndRemembersSuccess(logger) {
    var probe = new ServerRequestProbe(["https://local", "https://remote"], true);
    probe.start();
    probe.onResponse(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    probe.onResponse(200, {});
    probe.onResponse(200, {});
    return (probe.sent.size() == 2)
        && probe.sent[1].equals("https://remote/library/sections/3/all")
        && probe.selected.equals("https://remote")
        && (probe.result == 200) && (probe.callbacks == 1);
}

(:test)
function stopsAfterAllAddressesFail(logger) {
    var probe = new ServerRequestProbe(["https://local", "https://remote"], true);
    probe.start();
    probe.onResponse(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    probe.onResponse(504, null);
    return (probe.sent.size() == 2) && (probe.result == 504)
        && (probe.callbacks == 1) && (probe.selected == null);
}

(:test)
function doesNotRetryAuthenticationCancellationOrOversize(logger) {
    var codes = [401, 403, Toybox.Communications.REQUEST_CANCELLED,
        Toybox.Communications.NETWORK_RESPONSE_TOO_LARGE];
    for (var i = 0; i < codes.size(); i += 1) {
        var probe = new ServerRequestProbe(["https://local", "https://remote"], true);
        probe.start();
        probe.onResponse(codes[i], null);
        if ((probe.sent.size() != 1) || (probe.callbacks != 1)
            || (probe.result != codes[i])) { return false; }
    }
    return true;
}

(:test)
function cancelledBrowseStopsRetry(logger) {
    var probe = new ServerRequestProbe(["https://local", "https://remote"], true);
    probe.start();
    probe.cancel();
    probe.onResponse(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    return (probe.sent.size() == 1) && (probe.callbacks == 0) && (probe.selected == null);
}

(:test)
function doesNotReplayWrites(logger) {
    var probe = new ServerRequestProbe(["https://local", "https://remote"], false);
    probe.start();
    probe.onResponse(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    return (probe.sent.size() == 1) && (probe.callbacks == 1);
}

(:test)
function retriesNotFoundButPreservesFinalMissingItem(logger) {
    var recovered = new ServerRequestProbe(["https://local", "https://remote"], true);
    recovered.start();
    recovered.onResponse(404, null);
    recovered.onResponse(200, {});
    var missing = new ServerRequestProbe(["https://local", "https://remote"], true);
    missing.start();
    missing.onResponse(404, null);
    missing.onResponse(404, null);
    var write = new ServerRequestProbe(["https://local", "https://remote"], false);
    write.start();
    write.onResponse(404, null);
    return (recovered.sent.size() == 2) && (recovered.result == 200)
        && recovered.selected.equals("https://remote") && (recovered.callbacks == 1)
        && (missing.sent.size() == 2) && (missing.result == 404)
        && (missing.callbacks == 1) && (missing.selected == null)
        && (write.sent.size() == 1) && (write.result == 404);
}

(:test)
function lateTimedOutAttemptCannotCompleteNextRequest(logger) {
    var probe = new ServerRequestProbe(["https://local", "https://remote"], true);
    probe.start();
    probe.onAttemptResponse(0, Toybox.Communications.NETWORK_REQUEST_TIMED_OUT, null);
    probe.onAttemptResponse(0, 404, null);
    if ((probe.sent.size() != 2) || (probe.callbacks != 0)) { return false; }
    probe.onAttemptResponse(1, 200, {});
    probe.onAttemptResponse(0, 200, {});
    return (probe.callbacks == 1) && (probe.result == 200)
        && probe.selected.equals("https://remote");
}

(:test)
function storesOnlySelectedServersAddresses(logger) {
    var login = new PlexLoginView();
    var servers = [
        { "name" => "Owned", "provides" => "server", "owned" => true,
          "accessToken" => "test-token", "connections" => [
            { "uri" => "https://local", "protocol" => "https", "local" => true },
            { "uri" => "https://remote", "protocol" => "https", "local" => false },
            { "uri" => "https://local", "protocol" => "https", "local" => true }] },
        { "name" => "Other", "provides" => "server", "owned" => false,
          "accessToken" => "other-token", "connections" => [
            { "uri" => "https://other", "protocol" => "https", "local" => true }] }
    ];
    var urls = login.selectServer(servers, [])["urls"];
    return (urls.size() == 2) && urls[0].equals("https://local")
        && urls[1].equals("https://remote");
}

(:test)
function customAddressComesFirstWithoutRemovingDiscoveredAddresses(logger) {
    var urls = PlexAccount.orderedConnectionUrls("https://custom", "https://remote",
        "https://remote", ["https://local", "https://remote", "https://relay"]);
    return (urls.size() == 4) && urls[0].equals("https://custom")
        && urls[1].equals("https://remote") && urls[2].equals("https://local")
        && urls[3].equals("https://relay");
}

(:test)
function legacySingleAddressStillWorks(logger) {
    var urls = PlexAccount.orderedConnectionUrls(null, "https://legacy", "https://legacy", null);
    return (urls.size() == 1) && urls[0].equals("https://legacy");
}

(:test)
class LoginFlowProbe extends PlexLoginView {
    var pins = 0;
    var discoveredToken = null;
    var errors = 0;
    function initialize() { PlexLoginView.initialize(); }
    function requestPin() { pins += 1; }
    function discoverServers(token) { discoveredToken = token; }
    function setText(text) {}
    function showError(message, code) { errors += 1; }
}

(:test)
function authorizedAccountSurvivesUnreachableServer(logger) {
    var state = new MultiServerTestState();
    Toybox.Application.Storage.deleteValue(Plexit.Storage.PLEX_ACCOUNT_TOKEN);
    Toybox.Application.Storage.deleteValue(Plexit.Storage.PLEX_SERVER_URL);
    var login = new LoginFlowProbe();
    login.onShow();
    login.onPinPolled(200, { "authToken" => "authorized-test-token" });
    var retry = new LoginFlowProbe();
    retry.onShow();
    var passed = (login.pins == 1) && (retry.pins == 0)
        && "authorized-test-token".equals(retry.discoveredToken)
        && !PlexAccount.isConnected();
    state.restore();
    return passed;
}

(:test)
function temporaryPinPollingFailureCanStillAuthorize(logger) {
    var state = new MultiServerTestState();
    Toybox.Application.Storage.deleteValue(Plexit.Storage.PLEX_ACCOUNT_TOKEN);
    var login = new LoginFlowProbe();
    login.onShow();
    login.onPinPolled(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    login.onPinPolled(503, null);
    login.onPinPolled(200, { "authToken" => "authorized-test-token" });
    var passed = (login.errors == 0)
        && "authorized-test-token".equals(login.discoveredToken);
    state.restore();
    return passed;
}

// Capture recovery scheduling without a real minute-long timer or network call.
(:test)
class CompatibilityRequestProbe extends ServerRequestProbe {
    var waitMs = null;
    function initialize() {
        ServerRequestProbe.initialize(["https://local", "https://remote"], true);
        setCompatibility(true);
    }
    function waitBeforeRetry(milliseconds) { waitMs = milliseconds; }
}

(:test)
function compatibilityWaitsBeforeFallbackAndRemembersWorkingAddress(logger) {
    var probe = new CompatibilityRequestProbe();
    probe.start();
    probe.onResponse(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    if ((probe.waitMs != 60000) || (probe.sent.size() != 1) || (probe.callbacks != 0)) { return false; }
    probe.start();
    probe.onResponse(200, {});
    return (probe.sent.size() == 2) && (probe.callbacks == 1)
        && probe.selected.equals("https://remote");
}

(:test)
function cancellingRecoveryPreventsNextRequest(logger) {
    var probe = new CompatibilityRequestProbe();
    probe.start();
    probe.onResponse(Toybox.Communications.BLE_HOST_TIMEOUT, null);
    probe.cancel();
    probe.start();
    return (probe.waitMs == 60000) && (probe.sent.size() == 1) && (probe.callbacks == 0);
}

(:test)
function compatibilityDoesNotRetryAuthenticationFailure(logger) {
    var probe = new CompatibilityRequestProbe();
    probe.start();
    probe.onResponse(401, null);
    return (probe.waitMs == null) && (probe.sent.size() == 1)
        && (probe.callbacks == 1) && (probe.result == 401);
}

(:test)
function internetModeSkipsSavedLocalAndKeepsRemoteRelay(logger) {
    var state = new MultiServerTestState();
    var record = state.records()[0];
    record["urls"] = ["https://local", "https://remote", "https://relay"];
    record["localUrls"] = ["https://local"];
    record["uri"] = "https://local";
    record["custom"] = "https://local";
    record["connectionMode"] = PlexServers.CONNECTION_INTERNET;
    PlexServers.save(record);
    var urls = PlexServers.urls(record);
    var stored = PlexServers.get(record["id"]);
    var passed = (urls.size() == 2) && urls[0].equals("https://remote")
        && urls[1].equals("https://relay") && (stored["urls"].size() == 3);
    PlexServers.setConnectionMode(record["id"], PlexServers.CONNECTION_AUTO);
    passed = passed && (PlexServers.urls(PlexServers.get(record["id"])).size() == 3);
    state.restore();
    return passed;
}

(:test)
function connectionModesBelongToIndividualServersAndSurviveDiscovery(logger) {
    var state = new MultiServerTestState();
    PlexServers.remember(state.records());
    PlexServers.setConnectionMode("test-server-a", PlexServers.CONNECTION_INTERNET);
    PlexServers.setConnectionMode("test-server-b", PlexServers.CONNECTION_COMPATIBILITY);
    PlexServers.remember(state.records());
    var passed = PlexServers.connectionMode(PlexServers.get("test-server-a")).equals(PlexServers.CONNECTION_INTERNET)
        && PlexServers.connectionMode(PlexServers.get("test-server-b")).equals(PlexServers.CONNECTION_COMPATIBILITY);
    state.restore();
    return passed;
}

(:test)
function internetModeFiltersLoginUsingPlexFlags(logger) {
    var state = new MultiServerTestState();
    PlexServers.remember(state.records());
    PlexServers.setConnectionMode("test-server-a", PlexServers.CONNECTION_INTERNET);
    var login = new PlexLoginView();
    var resources = [{ "name" => "Test", "clientIdentifier" => "test-server-a",
        "provides" => "server", "owned" => true, "accessToken" => "token-a",
        "connections" => [
            { "uri" => "https://local", "protocol" => "https", "local" => true },
            { "uri" => "https://remote", "protocol" => "https", "local" => false },
            { "uri" => "https://relay", "protocol" => "https", "local" => false, "relay" => true }
        ] }];
    login.rememberDiscoveredServers(resources);
    var first = login.selectServer(resources, []);
    var second = login.selectServer(resources, ["https://remote"]);
    var passed = first["uri"].equals("https://remote") && second["uri"].equals("https://relay")
        && (login.selectServer(resources, ["https://remote", "https://relay"]) == null)
        && (PlexServers.get("test-server-a")["localUrls"].size() == 1)
        && (first["urls"].size() == 3);
    state.restore();
    return passed;
}

(:test)
function legacyCompatibilityMigratesWithoutOverridingExplicitAutomatic(logger) {
    var previous = Toybox.Application.Properties.getValue("connection_compatibility");
    Toybox.Application.Properties.setValue("connection_compatibility", true);
    var passed = PlexServers.connectionMode({}).equals(PlexServers.CONNECTION_COMPATIBILITY)
        && PlexServers.connectionMode({"connectionMode" => PlexServers.CONNECTION_AUTO}).equals(PlexServers.CONNECTION_AUTO)
        && PlexServers.connectionMode(null).equals(PlexServers.CONNECTION_AUTO);
    Toybox.Application.Properties.setValue("connection_compatibility", previous);
    return passed;
}
