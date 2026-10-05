using Plexit.Utils;
using Toybox.Communications;

class PlexAPI extends Api {

    private var d_params = {};
    private var d_options = { :headers => { "Accept" => "application/json" } };

    function initialize(settings, progress, fallback) {
        Api.initialize("");
        Api.update(settings);

		// set callbacks
		Api.setProgressCallback(progress);
		Api.setFallback(fallback);

        d_params.put("X-Plex-Platform", "Chrome");
        d_params.put("X-Plex-Device", System.getDeviceSettings().partNumber);
        d_params.put("X-Plex-Device-Name", client());

		d_options[:headers].put("X-Plex-Product", "Plexit");
		d_options[:headers].put("X-Plex-Version", (new PlexitVersion(null)).toString());
		d_options[:headers].put("X-Plex-Client-Identifier", PlexAccount.clientId());
		d_options[:headers].put("X-Plex-Platform", "Garmin Connect IQ");
		d_options[:headers].put("X-Plex-Device", "Garmin Watch");
		d_options[:headers].put("X-Plex-Device-Name", System.getDeviceSettings().partNumber);
    }

    function identity(callback) {
        Api.setCallback(callback);

        var url = url() + "/identity";
		var options = d_options;

        Communications.makeWebRequest(url, {}, options, self.method(:onResponse));
    }

	function scrobble(callback, params) {
		Api.setCallback(callback);
		
		var url = url() + "/:/scrobble";
		var options = {
			:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
		};
		
		// construct parameters
		params = Plexit.Utils.merge(params, d_params);
		options = Plexit.Utils.merge(options, d_options);

		Communications.makeWebRequest(url, params, options, self.method(:onScrobble));
	}

	function onScrobble(responseCode, data) {
		var error = Api.checkResponse(responseCode, data);
		if (error) {
			d_fallback.invoke(error);
			return;
		}
		d_callback.invoke(data);
	}
	
	/*
	 * onIdentity
	 *
	 * checks Dictionary response and returns the MediaContainer element
	 */
	function onResponse(responseCode, data) {
		// errors are filtered first
		var error = Api.checkDictionaryResponse(responseCode, data);
		if (error) {
			d_fallback.invoke(error);
			return;
		}
		d_callback.invoke(data["MediaContainer"]);
	}

    function playlists(callback, params) {
		Api.setCallback(callback);

        var url = url() + "/playlists";
        params = Utils.merge(d_params, params);

        Communications.makeWebRequest(url, params, d_options, self.method(:onResponse));
    }

    function onPlaylists(responseCode, data) {
		// check if request was successful and response is ok
    	var error = Api.checkDictionaryResponse(responseCode, data);
    	if (error) {
    		d_fallback.invoke(error);	// add function name and variables available ?
    		return;
    	}
    	
    	var response = data["MediaContainer"]["Metadata"];
		
		d_callback.invoke(response);
    }

    function playlists_items(callback, params, id) {
		Api.setCallback(callback);

        var url = url() + "/playlists/" + id + "/items";
        params = Utils.merge(d_params, params);

        Communications.makeWebRequest(url, params, d_options, self.method(:onResponse));
    }

    function playlist(callback, params, id) {
		Api.setCallback(callback);

        var url = url() + "/playlists/" + id;
        params = Utils.merge(d_params, params);
        Communications.makeWebRequest(url, params, d_options, self.method(:onResponse));
    }
    
    /**
     * stream
     *
     * downloads a given media file
     */
    function stream(callback, params, id, encoding) {
    	Api.setCallback(callback);

		var url = url() + id;
		params = Plexit.Utils.merge(params, d_params);

		// additional options
		var options = {
			:method => Communications.HTTP_REQUEST_METHOD_GET,
			:headers => d_options[:headers],
          	:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
          	:mediaEncoding => encoding,
			:fileDownloadProgressCallback => method(:onProgress),
   		};

		Communications.makeWebRequest(url, params, options, self.method(:onStream));
	}
    
    /**
     * music_transcode
     *
     * downloads a given media file
     */
    function music_transcode(callback, params, encoding) {
    	Api.setCallback(callback);

		var url = url() + "/music/:/transcode/universal/start.m3u8";
		params = Plexit.Utils.merge(params, d_params);

		// additional options
		var options = {
			:method => Communications.HTTP_REQUEST_METHOD_GET,
			:headers => d_options[:headers],
          	:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
          	:mediaEncoding => encoding,
			:fileDownloadProgressCallback => method(:onProgress),
   		};

		Communications.makeWebRequest(url, params, options, self.method(:onStream));
	}

	function onStream(responseCode, data) {
		// check if request was successful and response is ok
		var error = Api.checkContentResponse(responseCode, data);
		if (error) {
    		d_fallback.invoke(error);
			return;
		}
    	d_callback.invoke(data);
	}

    
    /**
     * photo transcode
     *
     * downloads artwork for given media id
     */
	function photo_transcode(callback, params, id) {
		Api.setCallback(callback);

		var url = url() + "/photo/:/transcode";
		params = Plexit.Utils.merge(params, d_params);
		params.put("url", id);
		params.put("width", 100);
		params.put("height", 100);

		// additional options
		var options = {
			:headers => d_options[:headers],
			:maxWidth => 100,
			:maxHeight => 100,
			:fileDownloadProgressCallback => method(:onProgress),
		};

		Communications.makeImageRequest(url, params, options, method(:onPhoto));
	}

	function onPhoto(responseCode, data) {
		// check if request was successful and response is ok
		var error = Api.checkImageResponse(responseCode, data);
		if (error) {
			d_fallback.invoke(error);
			return;
		}
    	d_callback.invoke(data);
	}

	// @override
	function updateKey(key) {
		Api.updateKey(key);
		d_params.put("X-Plex-Token", key);
		d_options[:headers].put("X-Plex-Token", key);
	}
}
