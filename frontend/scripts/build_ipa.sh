#!/usr/bin/env bash
# Build script for Halide Flutter App (TestFlight / App Store export).
#
# Requires frontend/.env with at least REVENUE_CAT_APPLE_KEY and GOOGLE_DRIVE_SERVER_CLIENT_ID.
# Set FLAVOR=staging for staging API (https://stagging-api.smartconnector.io.vn), or prod / dev.
#
# Optional: STAGING_TESTFLIGHT=1 forces FLAVOR=staging even if .env says dev (last --dart-define wins in AppConfig).

set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_DIR="$( dirname "$SCRIPT_DIR" )"
cd "$FRONTEND_DIR"

if [ ! -f .env ]; then
    echo "Error: .env file not found in $FRONTEND_DIR"
    exit 1
fi

# shellcheck disable=SC2046
export $(grep -v '^#' .env | grep -v '^\s*$' | xargs)

if [ "${STAGING_TESTFLIGHT:-}" = "1" ]; then
  export FLAVOR=staging
  echo "STAGING_TESTFLIGHT=1 → forcing FLAVOR=staging"
fi

if [ -z "${FLAVOR:-}" ]; then
  export FLAVOR=staging
  echo "FLAVOR was empty → defaulting to staging"
fi

echo "Building Halide for iOS (ipa) with FLAVOR=$FLAVOR"

BUILD_ARGS=()
if [ -n "${BUILD_NUMBER:-}" ]; then
  echo "Build number override: $BUILD_NUMBER"
  BUILD_ARGS+=(--build-number="$BUILD_NUMBER")
fi
if [ -n "${BUILD_NAME:-}" ]; then
  echo "Build name override: $BUILD_NAME"
  BUILD_ARGS+=(--build-name="$BUILD_NAME")
fi

EXPORT_PLIST="$FRONTEND_DIR/ios/ExportOptions.plist"
if [ ! -f "$EXPORT_PLIST" ]; then
  echo "Error: missing $EXPORT_PLIST"
  exit 1
fi

# REVENUE_CAT_GOOGLE_KEY may be unset for iOS-only builds
RC_GOOGLE="${REVENUE_CAT_GOOGLE_KEY:-}"

: "${REVENUE_CAT_APPLE_KEY:?Set REVENUE_CAT_APPLE_KEY in frontend/.env}"
: "${GOOGLE_DRIVE_SERVER_CLIENT_ID:?Set GOOGLE_DRIVE_SERVER_CLIENT_ID in frontend/.env}"

flutter build ipa --release "${BUILD_ARGS[@]}" \
    --export-options-plist="$EXPORT_PLIST" \
    --dart-define=FLAVOR="$FLAVOR" \
    --dart-define=REVENUE_CAT_APPLE_KEY="$REVENUE_CAT_APPLE_KEY" \
    --dart-define=REVENUE_CAT_GOOGLE_KEY="$RC_GOOGLE" \
    --dart-define=GOOGLE_DRIVE_SERVER_CLIENT_ID="$GOOGLE_DRIVE_SERVER_CLIENT_ID"

echo ""
echo "IPA output:"
ls -1 "$FRONTEND_DIR/build/ios/ipa/"*.ipa 2>/dev/null || echo "(no .ipa found under build/ios/ipa/)"
