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
