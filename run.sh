cd /Users/mato/Development/SubMusic

GARMIN_SDK="/Users/mato/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"

"$GARMIN_SDK/bin/connectiq"
sleep 2

"$GARMIN_SDK/bin/monkeydo" \
  /tmp/SubMusic-fr965.prg \
  fr965
