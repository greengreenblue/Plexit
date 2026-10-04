# SubMusic Plex fork

This repository is an in-progress Plex-only fork of
[memen45/SubMusic](https://github.com/memen45/SubMusic), a Garmin Connect IQ
audio content provider licensed under GPL-3.0.

The project currently preserves the original SubMusic name and application ID.
Both will be changed before an independent release.

## Current scope

- Browse Plex music playlists.
- Select playlists for offline synchronization.
- Download and transcode tracks through Plex Media Server.
- Play downloaded tracks through the Garmin system music player.
- Shuffle playlists and play all downloaded songs.
- Upload listening counts during synchronization.
- Display album artwork where the device supports it.

Support for Subsonic, Airsonic, Ampache, Nextcloud Music, and podcasts has been
removed from this fork.

## Development status

The compatibility baseline builds with Connect IQ SDK 9.2.0. The legacy code
currently requires Monkey C type checking to be disabled; `monkey.jungle`
contains that temporary setting. Restoring modern type checking is tracked as
technical debt and should happen as the retained modules are refactored.

Reference build target: Forerunner 965 (`fr965`).

## Temporary Plex setup

Until the planned Plex sign-in flow is implemented, configure these values in
the Connect IQ application settings:

- **Server Address**: the HTTPS address of the Plex Media Server.
- **Plex token**: a valid Plex authentication token.

The manual token setup is temporary and is intended only for development.

## License and attribution

This fork remains licensed under GPL-3.0. See [LICENSE](LICENSE).

Copyright and attribution for the original SubMusic project are retained in
the Git history and license. Modified versions distributed as binaries must
provide the corresponding source code under GPL-3.0.
