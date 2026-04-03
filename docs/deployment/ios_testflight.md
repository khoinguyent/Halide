# iOS TestFlight Deployment Guide

This document outlines the steps to build and distribute the Halide iOS app to TestFlight.

## Prerequisites

- **App Store Connect API Key**: Used for automated uploads without requiring a login session.
    - **Key ID**: `9PTQG9323C`
    - **Issuer ID**: `8b3530de-316d-4584-8095-2a001c801243`
    - **Bundle ID**: `com.halide.halidemanagement.pro.dev.io`
    - **Key File Source**: `/Users/123khongbiet/Downloads/AuthKey_9PTQG9323C.p8`
- **Signing Certificates**: A valid **Apple Distribution** certificate must be installed in the Keychain.
- **Provisioning Profile**: A matching profile for the App ID and Team ID.

## Step-by-Step Instructions

### 1. Versioning
Increment the build number in `frontend/pubspec.yaml`.
Example: `version: 1.0.0+23`

### 2. Clean and Prepare
```bash
cd frontend
flutter clean
flutter pub get
```

### 3. Build IPA
Use the provided build script which injects environment variables from `.env`.
```bash
chmod +x scripts/build_ipa.sh
./scripts/build_ipa.sh
```
The output will be generated at `frontend/build/ios/ipa/Runner.ipa` (or similar).

### 4. Upload to TestFlight
Run the following command to upload the generated IPA. Make sure the `.p8` file is located in `~/.private_keys/` or specify the path:

```bash
xcrun altool --upload-app --type ios \
  --file build/ios/ipa/Halide.ipa \
  --apiKey 9PTQG9323C \
  --apiIssuer 8b3530de-316d-4584-8095-2a001c801243
```
*Note: The IPA filename is `Halide.ipa` (not `Runner.ipa`).*

## Troubleshooting

- **No signing certificate "iOS Distribution" found**: Ensure you have a distribution certificate in your Keychain.
- **Team Mismatch**: Ensure the Team ID in Xcode (`Runner` target > Signing & Capabilities) matches your certificate.
