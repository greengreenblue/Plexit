#!/usr/bin/env bash
set -e
cd -- "$(dirname -- "$0")"

GARMIN_SDK="/Users/mato/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"

"$GARMIN_SDK/bin/monkeyc" \
  -f monkey.jungle \
  -d fenix9pro51mm \
  -y /Users/mato/Development/garmin-development-key/developer_key \
  -o /tmp/Plexit-fenix9pro51mm.prg
