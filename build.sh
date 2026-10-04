cd /Users/mato/Development/SubMusic

GARMIN_SDK="/Users/mato/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"

"$GARMIN_SDK/bin/monkeyc" \
  -f monkey.jungle \
  -d fr965 \
  -y /Users/mato/Development/garmin-development-key/developer_key \
  -o /tmp/SubMusic-fr965.prg
