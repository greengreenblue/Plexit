
class Audio extends Storable {

	hidden var d_audio;

	enum { SONG, END }
	static private var s_types = ["song"];

	// storage for playable class
	hidden var d_storage = {
		"id" => null,
		"type" => SONG,
	};

	function initialize(id, type) {
		Storable.initialize({ "id" => id, "type" => type, });

		d_audio = new ISong(id);
	}
	
	// getters
	function id() {
		return d_audio.id();
	}

	function artwork() {
		return d_audio.artwork();
	}

	function title() {
		return d_audio.title();
	}

	function artist() {
		return d_audio.artist();
	}

	function time() {
		return d_audio.time();
	}

	function playback() {
		return d_audio.playback();
	}

	function setPlayback(value) {
		return d_audio.setPlayback(value);
	}
	
	function mime() {
		return d_audio.mime();
	}

	function mediaKey() {
		return d_audio.mediaKey();
	}

	function refId() {
		return d_audio.refId();
	}
	
	function setRefId(refId) {
		return d_audio.setRefId(refId);
	}

	function type() {
		return get("type");
	}

	static function typeToString(type) {
		return s_types[type];
	}

	function metadata() {
		return d_audio.metadata();
	}
}
