#!/bin/bash

# Build script for Halide Flutter App
# Reads from .env and executes flutter build ipa with --dart-define flags

# Resolve the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FRONTEND_DIR="$( dirname "$SCRIPT_DIR" )"

cd "$FRONTEND_DIR"

# Load .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found in $FRONTEND_DIR"
    exit 1
fi

echo "Building Halide for iOS (ipa)..."
echo "Flavor: $FLAVOR"

flutter build ipa --release \
    --dart-define=FLAVOR=$FLAVOR \
    --dart-define=REVENUE_CAT_APPLE_KEY=$REVENUE_CAT_APPLE_KEY \
    --dart-define=REVENUE_CAT_GOOGLE_KEY=$REVENUE_CAT_GOOGLE_KEY \
    --dart-define=GOOGLE_DRIVE_SERVER_CLIENT_ID=$GOOGLE_DRIVE_SERVER_CLIENT_ID
