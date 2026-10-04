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

## Plex setup

Open **Settings → App Settings → Plex sign in** on the watch. The app displays
a short code and asks Garmin Connect Mobile to open `plex.tv/link` on the
phone. After the code is approved, the app discovers the account's Plex Media
Servers and automatically selects the best available HTTPS connection,
preferring an owned server and a local connection.

The current implementation uses Plex's legacy short-PIN token exchange because
Connect IQ does not provide the Ed25519 signing support needed by Plex's newer
device-JWT flow. Migrating to the JWT flow remains planned security work.

## License and attribution

This fork remains licensed under GPL-3.0. See [LICENSE](LICENSE).

Copyright and attribution for the original SubMusic project are retained in
the Git history and license. Modified versions distributed as binaries must
provide the corresponding source code under GPL-3.0.
