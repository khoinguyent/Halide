#!/usr/bin/env bash
# Build Halide IPA (staging) and upload to TestFlight.
#
# Usage:
#   ./scripts/deploy_testflight.sh
#   BUILD_NUMBER=85 ./scripts/deploy_testflight.sh
#   FLAVOR=prod ./scripts/deploy_testflight.sh   # prod API (omit STAGING_TESTFLIGHT)
#
# Requires:
#   - frontend/.env (REVENUE_CAT_APPLE_KEY, GOOGLE_DRIVE_SERVER_CLIENT_ID)
#   - ~/private_keys/AuthKey_9PTQG9323C.p8 (App Store Connect API key)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$(dirname "$SCRIPT_DIR")"
cd "$FRONTEND_DIR"

API_KEY_ID="9PTQG9323C"
API_ISSUER_ID="8b3530de-316d-4584-8095-2a001c801243"
API_KEY_PATH="$HOME/private_keys/AuthKey_${API_KEY_ID}.p8"

if [ ! -f "$API_KEY_PATH" ]; then
  ALT_PATH="$HOME/.private_keys/AuthKey_${API_KEY_ID}.p8"
  if [ -f "$ALT_PATH" ]; then
    API_KEY_PATH="$ALT_PATH"
  else
    echo "Error: App Store Connect API key not found at:"
    echo "  $HOME/private_keys/AuthKey_${API_KEY_ID}.p8"
    exit 1
  fi
fi

echo "==> Clean and fetch dependencies"
flutter clean
flutter pub get

echo ""
echo "==> Build release IPA"
if [ "${FLAVOR:-}" = "prod" ]; then
  ./scripts/build_ipa.sh
else
  STAGING_TESTFLIGHT=1 ./scripts/build_ipa.sh
fi

IPA_PATH="$FRONTEND_DIR/build/ios/ipa/Halide.ipa"
if [ ! -f "$IPA_PATH" ]; then
  IPA_PATH="$(ls -1 "$FRONTEND_DIR"/build/ios/ipa/*.ipa 2>/dev/null | head -1)"
fi
if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
  echo "Error: IPA not found under build/ios/ipa/"
  exit 1
fi

echo ""
echo "==> Upload to TestFlight: $IPA_PATH"
xcrun altool --upload-app --type ios \
  -f "$IPA_PATH" \
  --api-key "$API_KEY_ID" \
  --api-issuer "$API_ISSUER_ID"

echo ""
echo "Upload submitted. Check App Store Connect → TestFlight for processing status."
