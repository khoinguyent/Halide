#!/usr/bin/env bash
# Build and run Halide on the iOS Simulator (debug).
#
# Usage:
#   ./scripts/run_simulator.sh
#   FLAVOR=staging ./scripts/run_simulator.sh
#   DEVICE="iPhone 17 Pro" ./scripts/run_simulator.sh
#   ./scripts/run_simulator.sh -- --no-pub
#
# Environment:
#   FLAVOR   dev (default if unset), staging, or prod — dev uses http://localhost:8000
#   DEVICE   Flutter device id or name (default: first available iOS simulator)
#
# Requires frontend/.env with REVENUE_CAT_APPLE_KEY and GOOGLE_DRIVE_SERVER_CLIENT_ID
# (same as scripts/build_ipa.sh).

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
cd "$FRONTEND_DIR"

if [ ! -f .env ]; then
  echo "Error: .env file not found in $FRONTEND_DIR"
  echo "Create one with FLAVOR, REVENUE_CAT_APPLE_KEY, GOOGLE_DRIVE_SERVER_CLIENT_ID."
  exit 1
fi

PRESET_FLAVOR="${FLAVOR:-}"

# shellcheck disable=SC2046
export $(grep -v '^#' .env | grep -v '^\s*$' | xargs)

if [ -n "$PRESET_FLAVOR" ]; then
  export FLAVOR="$PRESET_FLAVOR"
  echo "Using FLAVOR from environment: $FLAVOR"
fi

if [ -z "${FLAVOR:-}" ]; then
  export FLAVOR=dev
  echo "FLAVOR was empty → defaulting to dev (localhost API)"
fi

: "${REVENUE_CAT_APPLE_KEY:?Set REVENUE_CAT_APPLE_KEY in frontend/.env}"
: "${GOOGLE_DRIVE_SERVER_CLIENT_ID:?Set GOOGLE_DRIVE_SERVER_CLIENT_ID in frontend/.env}"

RC_GOOGLE="${REVENUE_CAT_GOOGLE_KEY:-}"

ensure_simulator_ready() {
  if xcrun simctl list devices booted 2>/dev/null | grep -qE '\(Booted\)'; then
    return 0
  fi

  local device_id
  device_id="$(
    xcrun simctl list devices available -j | python3 -c "
import json, sys

data = json.load(sys.stdin)
preferred = (
    'iPhone 17 Pro',
    'iPhone 16 Pro',
    'iPhone 15 Pro',
    'iPhone 17',
    'iPhone 16',
    'iPhone 15',
)

def iter_iphones():
    for runtime, devices in data.get('devices', {}).items():
        if 'iOS' not in runtime:
            continue
        for d in devices:
            if not d.get('isAvailable'):
                continue
            name = d.get('name', '')
            if 'iPhone' in name:
                yield name, d['udid']

by_name = {name: udid for name, udid in iter_iphones()}
for name in preferred:
    if name in by_name:
        print(by_name[name])
        raise SystemExit

for _, udid in iter_iphones():
    print(udid)
    raise SystemExit
" 2>/dev/null || true
  )"

  if [ -z "$device_id" ]; then
    echo "Error: no available iOS simulator. Install one in Xcode → Settings → Platforms."
    exit 1
  fi

  echo "Booting simulator $device_id"
  xcrun simctl boot "$device_id" 2>/dev/null || true
}

resolve_flutter_device() {
  if [ -n "${DEVICE:-}" ]; then
    echo "$DEVICE"
    return 0
  fi

  local resolved
  resolved="$(
    flutter devices --machine 2>/dev/null | python3 -c "
import json, sys

devices = json.load(sys.stdin)
preferred = (
    'iPhone 17 Pro',
    'iPhone 16 Pro',
    'iPhone 15 Pro',
    'iPhone 17',
    'iPhone 16',
    'iPhone 15',
)

ios_sims = [
    d for d in devices
    if d.get('targetPlatform') == 'ios' and d.get('emulator')
]

if not ios_sims:
    raise SystemExit(1)

by_name = {d['name']: d['id'] for d in ios_sims}
for name in preferred:
    if name in by_name:
        print(by_name[name])
        raise SystemExit

print(ios_sims[0]['id'])
" 2>/dev/null || true
  )"

  if [ -z "$resolved" ]; then
    echo "Error: no iOS simulator visible to Flutter. Open Xcode and install an iOS simulator runtime." >&2
    exit 1
  fi

  echo "$resolved"
}

echo "Preparing iOS Simulator..."
ensure_simulator_ready
open -a Simulator 2>/dev/null || true

flutter pub get

FLUTTER_DEVICE="$(resolve_flutter_device)"
echo "Running Halide on simulator (FLAVOR=$FLAVOR, device=$FLUTTER_DEVICE)"

exec flutter run -d "$FLUTTER_DEVICE" \
  --dart-define=FLAVOR="$FLAVOR" \
  --dart-define=REVENUE_CAT_APPLE_KEY="$REVENUE_CAT_APPLE_KEY" \
  --dart-define=REVENUE_CAT_GOOGLE_KEY="$RC_GOOGLE" \
  --dart-define=GOOGLE_DRIVE_SERVER_CLIENT_ID="$GOOGLE_DRIVE_SERVER_CLIENT_ID" \
  "$@"
