# Plexit

Plexit is a free, open-source Plex music client for Garmin watches. It connects
directly to a Plex Media Server, downloads selected playlists over Wi-Fi and
plays them offline through Garmin's native music player.

## Features

- Secure Plex PIN sign-in and automatic server discovery.
- Browse and select Plex music playlists.
- Background playlist synchronization over Wi-Fi.
- Automatic FLAC, ALAC, AAC, OGG and Opus conversion to MP3 at 192 kb/s.
- Direct download of compatible MP3 files with automatic transcode fallback.
- Offline playback, playlist shuffle and play-all.
- Download status, storage statistics and per-playlist deletion.
- Plex listening-count updates during synchronization.

## Development

Plexit currently targets Connect IQ SDK 9.2.0. Reference devices:

- Forerunner 965 (`fr965`)
- Fenix 9 Pro 51 mm (`fenix9pro51mm`)

Build with `./build.sh` or `./build-fenix.sh`, then start the Connect IQ
simulator and run `./run.sh` or `./run-fenix.sh`.

## License and credits

Plexit is licensed under GPL-3.0. See [LICENSE](LICENSE).

The project began as a fork of
[memen45/SubMusic](https://github.com/memen45/SubMusic). Its GPL license and
Git history are preserved. Plexit is an independent project and is not
affiliated with Plex, Garmin or the original SubMusic maintainers.
