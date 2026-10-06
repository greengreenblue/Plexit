using Plexit.Utils;
using Toybox.Communications;
using Toybox.Lang;

class PlexAPI extends Api {

    private var d_params = {};
    private var d_options = { :headers => { "Accept" => "application/json" } };
	private var d_photoSourceId = null;
	private var d_photoDirectRetry = false;
	private var d_photoUsingPublic = false;
	private var d_photoParams = null;
	private var d_artworkUrl = null;

    function initialize(settings, progress, fallback) {
        Api.initialize("");
        Api.update(settings);
		d_artworkUrl = settings.get("artwork_url");

		// set callbacks
		Api.setProgressCallback(progress);
		Api.setFallback(fallback);

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
		System.println("playlists: " + url);
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
		System.println("playlists_items: " + url);
        params = Utils.merge(d_params, params);

        Communications.makeWebRequest(url, params, d_options, self.method(:onResponse));
    }

    function playlist(callback, params, id) {
		Api.setCallback(callback);

        var url = url() + "/playlists/" + id;
		System.println("playlist: " + url);
        params = Utils.merge(d_params, params);
        Communications.makeWebRequest(url, params, d_options, self.method(:onResponse));
    }

	function library_sections(callback, params) {
		Api.setCallback(callback);
		var requestUrl = url() + "/library/sections";
		System.println("library_sections: " + requestUrl);
		Communications.makeWebRequest(
			requestUrl,
			Utils.merge(d_params, params),
			d_options,
			self.method(:onResponse)
		);
	}

	function library_section_all(callback, params, sectionId) {
		Api.setCallback(callback);
		var requestUrl = url() + "/library/sections/" + sectionId + "/all";
		System.println("library_section_all: " + requestUrl);
		Communications.makeWebRequest(
			requestUrl,
			Utils.merge(d_params, params),
			d_options,
			self.method(:onResponse)
		);
	}

	function metadata(callback, params, id) {
		Api.setCallback(callback);
		var requestUrl = url() + "/library/metadata/" + id;
		System.println("metadata: " + requestUrl);
		Communications.makeWebRequest(
			requestUrl,
			Utils.merge(d_params, params),
			d_options,
			self.method(:onResponse)
		);
	}

	function metadata_children(callback, params, id) {
		Api.setCallback(callback);
		var requestUrl = url() + "/library/metadata/" + id + "/children";
		System.println("metadata_children: " + requestUrl);
		Communications.makeWebRequest(
			requestUrl,
			Utils.merge(d_params, params),
			d_options,
			self.method(:onResponse)
		);
	}

	function metadata_all_leaves(callback, params, id) {
		Api.setCallback(callback);
		var requestUrl = url() + "/library/metadata/" + id + "/allLeaves";
		System.println("metadata_all_leaves: " + requestUrl);
		Communications.makeWebRequest(
			requestUrl,
			Utils.merge(d_params, params),
			d_options,
			self.method(:onResponse)
		);
	}
    
    /**
     * stream
     *
     * downloads a given media file
     */
    function stream(callback, params, id, encoding) {
		Api.setCallback(callback);
		Api.beginDownloadProgress();
		System.println("Starting direct audio download");

		var url = url() + id;
		System.println("Audio download URL: " + url);
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
	 * Ask PMS to evaluate the exact profile before starting the expensive
	 * download. The returned decision text is invaluable when PMS rejects a
	 * client profile or transcode parameter.
	 */
	function music_transcode_decision(callback, params) {
		Api.setCallback(callback);

		var url = url() + "/music/:/transcode/universal/decision";
		System.println("Plex transcode decision endpoint: /music/:/transcode/universal/decision");
		System.println("Plex transcode request: path=" + params.get("path")
			+ ", protocol=" + params.get("protocol")
			+ ", bitrate=" + params.get("musicBitrate")
			+ ", directPlay=" + params.get("directPlay")
			+ ", directStream=" + params.get("directStream"));

		var profile = params.get("X-Plex-Client-Profile-Extra");
		var requestParams = Plexit.Utils.copy(params);
		requestParams.remove("X-Plex-Client-Profile-Extra");
		requestParams = Plexit.Utils.merge(requestParams, d_params);
		var options = Plexit.Utils.copy(d_options);
		var headers = Plexit.Utils.copy(d_options[:headers]);
		// PMS selects its base transcoder profile from the platform header.
		// Unknown platform/profile names can be rejected before MDE runs.
		headers.put("X-Plex-Platform", "iOS");
		headers.put("X-Plex-Device", "AppleTV");
		headers.put("X-Plex-Client-Profile-Extra", profile);
		options.put(:headers, headers);
		// PMS can return XML or an HTML error document here even when JSON was
		// requested. Read it as text so Garmin does not replace the real HTTP
		// response with INVALID_HTTP_BODY_IN_NETWORK_RESPONSE.
		options.put(:responseType, Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN);

		System.println("Plex transcode decision url: " + url);
		// Never print requestParams/options here: both contain the Plex token.

		Communications.makeWebRequest(url, requestParams, options, self.method(:onTranscodeDecision));
	}

	function onTranscodeDecision(responseCode, data) {
		System.println("Plex transcode decision response: " + responseCode);
		if (data instanceof Lang.String) {
			var end = data.length();
			if (end > 1200) { end = 1200; }
			System.println("Plex transcode decision body: " + data.substring(0, end));
		}
		d_callback.invoke(responseCode, data);
	}

    /**
     * music_transcode
     *
     * downloads a given media file
     */
    function music_transcode(callback, params, encoding) {
		Api.setCallback(callback);
		Api.beginDownloadProgress();
		System.println("Starting Plex MP3 transcode download");
		System.println("Plex transcode start endpoint: /music/:/transcode/universal/start.mp3");

		// A progressive HTTP MP3 response can be persisted directly by Garmin.
		// HLS start.m3u8 returns a playlist/segments and is not the requested
		// MP3 content object.
		var url = url() + "/music/:/transcode/universal/start.mp3";
		var profile = params.get("X-Plex-Client-Profile-Extra");
		var requestParams = Plexit.Utils.copy(params);
		requestParams.remove("X-Plex-Client-Profile-Extra");
		requestParams = Plexit.Utils.merge(requestParams, d_params);

		// additional options
		var headers = Plexit.Utils.copy(d_options[:headers]);
		headers.put("X-Plex-Platform", "iOS");
		headers.put("X-Plex-Device", "AppleTV");
		headers.put("X-Plex-Client-Profile-Extra", profile);
		var options = {
			:method => Communications.HTTP_REQUEST_METHOD_GET,
			:headers => headers,
          	:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_AUDIO,
          	:mediaEncoding => encoding,
			:fileDownloadProgressCallback => method(:onProgress),
   		};

		Communications.makeWebRequest(url, requestParams, options, self.method(:onStream));
	}

	function onStream(responseCode, data) {
		System.println("Audio download completed with response " + responseCode);
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
		d_photoSourceId = id;
		d_photoDirectRetry = false;
		d_photoUsingPublic = false;
		d_photoParams = params;

		var ratingKey = artworkRatingKey(id);
		if (ratingKey == null) {
			startPlexPhotoTranscode();
			return;
		}

		// Playlist responses do not contain the album MBID. Resolve the album
		// metadata first, then use the public Cover Art Archive image so Garmin's
		// image proxy never needs access to the user's private Plex server.
		var metadataUrl = url() + "/library/metadata/" + ratingKey;
		System.println("Resolving public artwork for Plex album " + ratingKey);
		Communications.makeWebRequest(
			metadataUrl,
			{ "includeGuids" => 1 },
			d_options,
			method(:onArtworkMetadata)
		);
	}

	function onArtworkMetadata(responseCode, data) {
		var mbid = null;
		if ((responseCode == 200) && (data instanceof Lang.Dictionary)) {
			var container = data["MediaContainer"];
			if (container instanceof Lang.Dictionary) {
				var metadata = container["Metadata"];
				if ((metadata instanceof Lang.Array) && (metadata.size() > 0)
					&& (metadata[0] instanceof Lang.Dictionary)) {
					mbid = artworkMbid(metadata[0]);
				}
			}
		}

		if (mbid == null) {
			System.println("No MusicBrainz release id; trying Plex artwork");
			startPlexPhotoTranscode();
			return;
		}

		d_photoUsingPublic = true;
		var publicUrl = "https://coverartarchive.org/release/" + mbid + "/front-250";
		var options = {
			:maxWidth => 100,
			:maxHeight => 100,
			:dithering => Communications.IMAGE_DITHERING_NONE,
		};
		if (Communications has :PACKING_FORMAT_JPG) {
			options.put(:packingFormat, Communications.PACKING_FORMAT_JPG);
		}
		System.println("Starting public MusicBrainz artwork download: " + mbid);
		Communications.makeImageRequest(publicUrl, null, options, method(:onPhoto));
	}

	function artworkRatingKey(id) {
		if (!(id instanceof Lang.String)) {
			return null;
		}
		var prefix = "/library/metadata/";
		if (id.find(prefix) != 0) {
			return null;
		}
		var remainder = id.substring(prefix.length(), id.length());
		var slash = remainder.find("/");
		if (slash == null) {
			return remainder;
		}
		return remainder.substring(0, slash);
	}

	function artworkMbid(metadata) {
		var guid = metadata["guid"];
		var mbid = mbidFromGuid(guid);
		if (mbid != null) {
			return mbid;
		}

		var guids = metadata["Guid"];
		if (!(guids instanceof Lang.Array)) {
			return null;
		}
		for (var index = 0; index < guids.size(); index += 1) {
			if (guids[index] instanceof Lang.Dictionary) {
				mbid = mbidFromGuid(guids[index]["id"]);
				if (mbid != null) {
					return mbid;
				}
			}
		}
		return null;
	}

	function mbidFromGuid(guid) {
		if (!(guid instanceof Lang.String) || (guid.find("mbid://") != 0)) {
			return null;
		}
		return guid.substring(7, guid.length());
	}

	function startPlexPhotoTranscode() {

		var imageBaseUrl = (d_artworkUrl != null) ? d_artworkUrl : url();
		var photoUrl = imageBaseUrl + "/photo/:/transcode";
		var params = Plexit.Utils.merge(d_photoParams, d_params);
		addImageClientParams(params);
		// Plex authenticates the outer photo-transcode request and its nested
		// source URL separately. Protected library artwork therefore needs the
		// token inside the url parameter as well.
		var sourceUrl = d_photoSourceId;
		if (key() != null) {
			sourceUrl += ((sourceUrl.find("?") == null) ? "?" : "&")
				+ "X-Plex-Token=" + key();
		}
		params.put("url", sourceUrl);
		params.put("width", 100);
		params.put("height", 100);
		params.put("format", "jpeg");
		params.put("quality", 80);
		params.put("upscale", 0);
		params.put("minSize", 0);

		// makeImageRequest only accepts image conversion options. Authentication
		// is already present in params as X-Plex-Token; :headers and
		// :fileDownloadProgressCallback are not valid image request options.
		var options = {
			:maxWidth => 100,
			:maxHeight => 100,
		};

		System.println("Starting Plex artwork download via " + imageBaseUrl + ": " + d_photoSourceId);
		Communications.makeImageRequest(photoUrl, params, options, method(:onPhoto));
	}

	function onPhoto(responseCode, data) {
		System.println("Artwork download completed with response " + responseCode);
		// check if request was successful and response is ok
		var error = Api.checkImageResponse(responseCode, data);
		if (error) {
			if (d_photoUsingPublic) {
				d_photoUsingPublic = false;
				System.println("Public artwork unavailable; trying Plex artwork");
				startPlexPhotoTranscode();
				return;
			}
			if (!d_photoDirectRetry && (d_photoSourceId != null)) {
				d_photoDirectRetry = true;
				downloadArtworkDirect();
				return;
			}
			d_fallback.invoke(error);
			return;
		}
		d_callback.invoke(data);
	}

	function downloadArtworkDirect() {
		var imageBaseUrl = (d_artworkUrl != null) ? d_artworkUrl : url();
		var directUrl = imageBaseUrl + d_photoSourceId;
		var params = {};
		if (key() != null) {
			params.put("X-Plex-Token", key());
		}
		addImageClientParams(params);
		var options = {
			:maxWidth => 100,
			:maxHeight => 100,
			:dithering => Communications.IMAGE_DITHERING_NONE,
		};
		System.println("Retrying artwork as direct image: " + d_photoSourceId);
		Communications.makeImageRequest(directUrl, params, options, method(:onPhoto));
	}

	function addImageClientParams(params) {
		// makeImageRequest has no :headers option. Plex accepts all X-Plex
		// identity values as query parameters as an equivalent transport.
		params.put("X-Plex-Product", "Plexit");
		params.put("X-Plex-Client-Identifier", PlexAccount.clientId());
		params.put("X-Plex-Platform", "iOS");
		params.put("X-Plex-Device", "AppleTV");
	}

	// @override
	function updateKey(key) {
		Api.updateKey(key);
		d_params.put("X-Plex-Token", key);
		d_options[:headers].put("X-Plex-Token", key);
	}

	function update(settings) {
		Api.update(settings);
		d_artworkUrl = settings.get("artwork_url");
	}
}
