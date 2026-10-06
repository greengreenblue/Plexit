using Toybox.Media;
using Toybox.Math;
using Toybox.System;
using Plexit;

class PlexitContentIterator extends Media.ContentIterator {

	private var d_songcount;
	private var d_playable;
	private var d_repeatMode = Media.REPEAT_MODE_OFF;

    function initialize() {
        ContentIterator.initialize();

		// retrieve now playing
		d_playable = new Plexit.IPlayable();
		
		d_songcount = d_playable.size();
    }

    // Determine if the the current track can be skipped.
    function canSkip() {
        return true;
    }

    // Get the current media content object.
	    function get() {
		if ((d_songcount == 0) || (d_playable.songidx() < 0)
				|| (d_playable.songidx() >= d_songcount))
    	{
    		return null;
    	}
        return getObj(d_playable.songidx());
    }

    // Get the current media content playback profile
    function getPlaybackProfile() {
        var profile = new Media.PlaybackProfile();
        profile.attemptSkipAfterThumbsDown = true;
        profile.playbackControls = [
            PLAYBACK_CONTROL_NEXT,
            PLAYBACK_CONTROL_PREVIOUS,
            PLAYBACK_CONTROL_VOLUME,
            
            PLAYBACK_CONTROL_LIBRARY,
            
            PLAYBACK_CONTROL_SHUFFLE,
            PLAYBACK_CONTROL_REPEAT,
            PLAYBACK_CONTROL_RATING,
        ];
		// add skip forward buttons if enabled
		if (Application.Properties.getValue("skip_30s")) {
			profile.playbackControls.addAll([
				PLAYBACK_CONTROL_SKIP_FORWARD,
				PLAYBACK_CONTROL_SKIP_BACKWARD,
			]);
		}
        profile.playbackNotificationThreshold = 30;
        profile.requirePlaybackNotification = true;		// notify played
        profile.skipPreviousThreshold = 5;
        // profile.supportsPlaylistPreview = true;
        return profile;
    }

    // Get the next media content object.
    function next() {
    	if ((d_playable.songidx() + 1) >= d_songcount)
    	{
			if (d_songcount > 0) {
				d_playable.setIdx(0);
				d_playable.save();
				return getObj(0);
			}
    		return null;
    	}
		d_playable.incSongIdx();
    	return getObj(d_playable.songidx());
    }

    // Get the next media content object without incrementing the iterator.
    function peekNext() {
    	if ((d_playable.songidx() + 1) >= d_songcount)
    	{
			if (d_songcount > 0) {
				return getObj(0);
			}
    		return null;
    	}
    	return getObj(d_playable.songidx() + 1);
    }

    // Get the previous media content object without decrementing the iterator.
    function peekPrevious() {
    	if (d_playable.songidx() == 0)
    	{
			if (d_songcount > 0) {
				return getObj(d_songcount - 1);
			}
    		return null;
    	}
    	return getObj(d_playable.songidx() - 1);
    }

    // Get the previous media content object.
    function previous() {
    	if (d_playable.songidx() == 0)
    	{
			if (d_songcount > 0) {
				d_playable.setIdx(d_songcount - 1);
				d_playable.save();
				return getObj(d_songcount - 1);
			}
    		return null;
    	}
		d_playable.decSongIdx();
    	return getObj(d_playable.songidx());
    }

    // Determine if playback is currently set to shuffle.
    function shuffling() {
        return d_playable.shuffle();
    }
    
    function toggleShuffle() {
		d_playable.shuffleIdcs(!d_playable.shuffle());
    }

	function repeatMode() {
		return d_repeatMode;
	}

	function toggleRepeat() {
		if (d_repeatMode == Media.REPEAT_MODE_OFF) {
			d_repeatMode = Media.REPEAT_MODE_ONE;
		} else if (d_repeatMode == Media.REPEAT_MODE_ONE) {
			d_repeatMode = Media.REPEAT_MODE_ALL;
		} else {
			d_repeatMode = Media.REPEAT_MODE_OFF;
		}
	}

	// Retrieve the cached object from Media
	function getObj(idx) {
		if ((idx == null) || (idx < 0) || (idx >= d_songcount)) {
			return null;
		}

		// retrieve content reference
		var audio = d_playable.getAudio(idx);
		if (!(audio instanceof Plexit.Audio) || (audio.refId() == null)) {
			return null;
		}
		var contentRef = new Media.ContentRef(audio.refId(), Media.CONTENT_TYPE_AUDIO);
		
		// retrieve metadata
		var content = null;
		try {
			content = Media.getCachedContentObj(contentRef);
		} catch (error) {
			System.println("Cached playback item unavailable: " + error);
			return null;
		}
		if (content == null) {
			return null;
		}
		var metadata = content.getMetadata();
		if (metadata == null) {
			return null;
		}

		// add stored metadata if not given in file (Plex does not provide metadata in file)
		var has_title = (metadata.title != null) && (metadata.title instanceof Lang.String) && (!metadata.title.equals(""));
		var has_artist = (metadata.artist != null) && (metadata.artist instanceof Lang.String) && (!metadata.artist.equals(""));
		if (!has_title) {
			metadata.title = audio.title();
		}
		if (!has_artist) {
			metadata.artist = audio.artist();
		}
		
		// return content
		return new Media.ActiveContent(contentRef, metadata, 0);
	}
}
