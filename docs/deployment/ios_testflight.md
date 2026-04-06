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

### 3. Staging flavor via `.env`
In `frontend/.env`, set:

```bash
FLAVOR=staging
```

Also set `REVENUE_CAT_*` and `GOOGLE_DRIVE_SERVER_CLIENT_ID` as needed. The build script exports `.env` and passes `--dart-define=FLAVOR=...` so `AppConfig` uses the staging API (`https://stagging-api.smartconnector.io.vn`).

### 4. Build IPA
Use the provided build script which injects environment variables from `.env`.
```bash
cd frontend
chmod +x scripts/build_ipa.sh
./scripts/build_ipa.sh
```
The output IPA is under `frontend/build/ios/ipa/` (often `Runner.ipa` or the archive product name — check the script output).

### 5. Upload to TestFlight
Run the following command to upload the generated IPA (adjust `--file` to the `.ipa` path printed by the build). Make sure the `.p8` file is available to the toolchain or use API key auth:

```bash
cd frontend
xcrun altool --upload-app --type ios \
  --file build/ios/ipa/Halide.ipa \
  --apiKey 9PTQG9323C \
  --apiIssuer 8b3530de-316d-4584-8095-2a001c801243
```

If your exported IPA has a different name, use `ls build/ios/ipa/`.

## Build History

| Build | Version | Date | Delivery UUID |
|-------|---------|------|---------------|
| 48 | 1.0.0+48 | 2026-04-06 | 683ecfe0-5857-4628-8b70-74192462368c |
| 47 | 1.0.0+47 | 2026-04-05 | d8164b6c-5619-4aac-a06a-a2992045a2da |
| 41 | 1.0.0+41 | 2026-04-05 | f37b24c3-3bde-48b3-9095-aca82a7cdccd |
| 40 | 1.0.0+40 | 2026-04-05 | c20fe1f5-b3de-4fed-9b29-9fdf3d4715e4 |
| 39 | 1.0.0+39 | 2026-04-05 | 6493e6cc-1c5b-47cd-be35-90603bfea0a6 |
| 31 | 1.0.0+31 | 2026-04-04 | 3a4da1bb-9322-4a52-87ed-d03000a6811e |
| 30 | 1.0.0+30 | 2026-04-04 | 10ac5f61-ee2b-4303-b904-864584eb4440 |
| 29 | 1.0.0+29 | 2026-04-04 | 17d5f4c6-988e-479a-8be7-715d87d50f6e |

## Troubleshooting

- **No signing certificate "iOS Distribution" found**: Ensure you have a distribution certificate in your Keychain.
- **Team Mismatch**: Ensure the Team ID in Xcode (`Runner` target > Signing & Capabilities) matches your certificate.
