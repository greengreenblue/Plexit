# Plexit

Plexit is a free, open-source Plex music client for Garmin watches. Download
music from your Plex Media Server over Wi-Fi, then listen offline through
Garmin's built-in music player — without carrying your phone.

## Features

- **Easy Plex sign-in.** Link your watch at [plex.tv/link](https://plex.tv/link)
  using a short code, with no passwords or server tokens to type on the watch.
  Plexit discovers your available Plex servers automatically.
- **Find music faster.** Full-text search runs on your Plex server, so you can
  find artists and albums without scrolling through hundreds of entries on a
  small watch display. Search covers your library, not just the currently
  displayed page.
- **Designed for limited memory.** Library browsing loads small pages instead
  of the entire library at once. Tested on the older Forerunner 245 Music,
  as well as fēnix 8.
- **More than playlists.** Browse and download Plex playlists, albums, artists
  and collections, or build **dynamic mixes** from your library.
- **Dynamic mixes.** Choose Recently Added, Recently Played, Most Played,
  Unplayed, Favorites or a genre. Set a track limit of **25, 50, 100 or 200**
  and an estimated download-size limit of **250, 500, 1,000 or 2,000 MB**.
  Defaults are **50 tracks and 500 MB**. These limits apply to dynamic mixes
  and genre selections, helping keep downloads manageable; they do not limit
  your regular Plex playlists or albums. The size estimate assumes 192 kb/s
  audio, so actual downloads can differ, particularly for directly downloaded
  MP3 files. Selected mixes are rebuilt from Plex when synchronized.
- **Offline listening.** Play all downloaded music, choose a playlist or shuffle
  your tracks using Garmin's native music controls.
- **Automatic audio conversion.** Compatible MP3 files download directly;
  other supported formats, including FLAC, ALAC, AAC, OGG and Opus, are
  transcoded by your Plex server to MP3 at 192 kb/s.
- **Artwork and download management.** Album covers, download status, storage
  information and individual download deletion.
- **Plex updates.** Playback records and pending ratings are sent back to Plex
  during synchronization, subject to the device limitations below.
- Support for **multiple Plex servers**, including shared servers.
- Automatic switching between Plex server addresses.
- Set a **custom Plex server address**, useful when you have remote Plex server
  and also need to connect to it locally.
- **Multiple languages.** English, Slovak, Czech, German, Polish and Spanish,
  selected automatically from the watch's language setting. More languages
  are planned for upcoming updates.

## Setup and usage

### What you need

- A compatible Garmin watch with music support and Bluetooth headphones.
- A Plex account and access to a Plex Media Server with a music library.
- Wi-Fi configured on your watch for music downloads. Your Plex server must be
  reachable from the watch's network; a server that is available only on your
  home network requires the watch to be on that network too.

Plexit does not provide a music catalog. Use music you are entitled to access
and download. Your Plex server performs any required audio conversion.

### Link your Plex account

1. Open the watch's music controls and select **Plexit** as the music provider.
2. In Plexit, open **Settings → Plex & playback → Plex sign in**.
3. On your phone or computer, visit [plex.tv/link](https://plex.tv/link), sign
   in to your Plex account and enter the code displayed on the watch.
4. Wait for Plexit to find your server and show the connection confirmation.

The menu names below use English; they are translated when your watch uses
another supported language.

### Download and listen

1. Open **Add music** and choose **Playlists**, **Albums**, **Artists**,
   **Collections** or **Mixes**.
2. Select what you want to keep offline. In album/artist browsing, use
   **Search** to find music on Plex, or **Show more** to load another page.
3. For a dynamic mix, open **Mixes → Mix settings** to choose the track and
   download-size limits, then enable the desired mix or genre.
4. Return to **Add music** and choose **Sync now** (or **Sync pending** when
   changes are waiting). Keep the server reachable until downloads finish.
5. Connect your Bluetooth headphones. Open **Playlists** to choose downloaded
   music, or use **Play All** or **Shuffle**. Downloaded music plays without
   a network connection or phone.

For example, select **Recently Added** with a 25-track limit, synchronize it
at home, then listen offline on your next run. Synchronize again when you want
an updated selection from Plex (after you've added new songs to your Plex).

Use **Settings → Storage → Downloads** to inspect or delete individual
downloads. **Storage → Remove Data** resets all Plexit data, including your
saved Plex connection and downloaded music, so you will need to link again.

## Known issues and limitations

- **Choose a connection mode for each server.** Under **Settings → Music
  servers → [server] → Server connection**, choose **Automatic** (local addresses
  first), **Automatic – compatibility** (wait 60 seconds after a failed request
  before trying the next address), or **Internet only** (skip addresses Plex
  identifies as local; retain remote and relay addresses). Internet only is useful
  for a friend's shared server, even when your phone uses Wi-Fi. After account
  authorization and discovery, new servers ask whether they are on your home
  network: Yes selects Automatic; No selects Internet only. The mode can later
  be changed in that server's detailed settings. If automatic sign-in exhausts
  all addresses, Plexit offers an internet-only trial after a recovery countdown
  and saves that server's preference only after success. Address probes show
  local/remote numbering and a bounded countdown (2 seconds for local addresses,
  8 for remote, followed by at most 5 seconds to acknowledge cancellation).
  Existing compatibility preferences are preserved during migration.
- **Transcoded download progress is estimated when the size is unknown.** The
  estimate uses track duration and target bitrate and advances with received
  bytes, capped at 95% of the track until it completes. Metadata refresh alone
  does not mark a selection downloaded; its audio must be saved successfully.
- **Plex artwork can be slow or unavailable.** Artwork delivery from some Plex
  servers does not work reliably with Garmin's image-download path. Plexit
  therefore prefers MusicBrainz artwork from the Cover Art Archive by default.
  You can change **Prefer MusicBrainz Artwork** under
  **Settings → Plex & playback**, or in the app settings in Connect IQ.
  If synchronization takes unusually long while fetching covers, or Plex
  covers fail to appear, enable this option. Public artwork depends on Plex
  having a MusicBrainz release identifier and a matching cover being available;
  Plexit falls back to Plex artwork when needed.
- **Thumbs Up/Down on fēnix.** Rating controls do not yet work reliably on
  fēnix watches, although they have worked on Forerunner watches in testing.
  This is still being investigated. Offline music playback is unaffected.
- **Search results are limited.** Searches run against the server's library,
  but Plexit requests a small number of results to fit the watch's memory and
  HTTP-response limits. A broad query may not display every match; use a more
  specific artist or album name. Paged browsing is available separately.
- **Downloads need a reachable server.** Sign-in alone does not guarantee that
  your watch can reach the selected Plex server. Network access and server-side
  transcoding performance affect synchronization; music must finish downloading
  before it can be played offline.
- **Mix size limits are estimates.** They are intended to control the size of a
  selection, not enforce an exact storage quota. A single long track can also
  exceed the selected estimate.

For help or bug reports, use
[GitHub Issues](https://github.com/martinbernat/Plexit/issues). Include your watch
model and the steps to reproduce the problem. Remove Plex tokens, sign-in codes
and private server details before sharing logs or screenshots.

## License and credits

Plexit is licensed under GPL-3.0. See [LICENSE](LICENSE).

The project began as a fork of
[memen45/SubMusic](https://github.com/memen45/SubMusic). Its GPL license and
Git history are preserved. Plexit is an independent project and is not
affiliated with Plex, Garmin or the original SubMusic maintainers.
