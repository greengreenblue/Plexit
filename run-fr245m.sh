#!/usr/bin/env bash
set -e
cd -- "$(dirname -- "$0")"

GARMIN_SDK="/Users/mato/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"

"$GARMIN_SDK/bin/connectiq"
sleep 2

"$GARMIN_SDK/bin/monkeydo" \
  /tmp/Plexit-fr245m.prg \
  fr245m
