# iOS TestFlight Deployment Guide

This document describes how to build and distribute the Halide iOS app to **TestFlight** with **`FLAVOR=staging`** (staging API: `https://stagging-api.smartconnector.io.vn`, in-app **STAGING** banner).

## Prerequisites

- **Xcode** and **Flutter** installed; Apple Developer Program membership.
- **`frontend/.env`** (not committed) with at least:
  - `FLAVOR=staging` for staging TestFlight builds, **or** rely on `STAGING_TESTFLIGHT=1` when running the script (see below).
  - `REVENUE_CAT_APPLE_KEY` (staging RevenueCat public SDK key when testing purchases against staging).
  - `GOOGLE_DRIVE_SERVER_CLIENT_ID` (Drive integration).
  - Optional: `REVENUE_CAT_GOOGLE_KEY` (empty is allowed for iOS-only builds).
- **Signing**: a valid **Apple Distribution** certificate in Keychain and matching provisioning for the bundle ID below.
- **App Store Connect API key** (for CLI upload with `altool`):
  - **Key ID**: `9PTQG9323C`
  - **Issuer ID**: `8b3530de-316d-4584-8095-2a001c801243`
  - **Key file**: `AuthKey_9PTQG9323C.p8` (download once from App Store Connect; store outside the repo). For `altool`, place it under **`~/private_keys/`** so the toolchain can find **`~/private_keys/AuthKey_9PTQG9323C.p8`**, or follow `man altool` for your setup.
- **Bundle ID**: `com.halide.halidemanagement.pro.dev.io`

## How staging flavor is applied

- The release IPA passes **`--dart-define=FLAVOR=...`** from `scripts/build_ipa.sh`.
- In the app, **`--dart-define=FLAVOR=...` overrides** a conflicting `FLAVOR` inside the bundled `.env` asset (`AppConfig` in `frontend/lib/config/app_config.dart`).
- **`STAGING_TESTFLIGHT=1`** forces **`FLAVOR=staging`** for that build even if `.env` still has `dev` or `prod`.

## Step-by-step (staging TestFlight)

### 1. Versioning

Increment the build number in `frontend/pubspec.yaml` (the part after `+`). Each upload to App Store Connect must use a **new** build number **higher than every build already listed** for that app (Apple does not require consecutive numbers; gaps such as 62–63 missing are fine).

The **marketing version** (the part before `+`, i.e. **CFBundleShortVersionString**) must match the **version** you created in App Store Connect for this submission (e.g. **`1.1.0`** for a **1.1** release train; three-part form is what Flutter/`pubspec` use). It must also be **higher** than any version Apple has already approved for the app, and higher than closed pre-release trains when Apple requires it.

The repo is currently set to **`1.1.0+67`** for the **1.1** version in App Store Connect. For each new upload, increase the **`+` build** number (e.g. **`1.1.0+68`**).

### 2. Clean and prepare

```bash
cd frontend
flutter clean
flutter pub get
```

### 3. Configure `.env`

Ensure staging-related keys are set. At minimum:

```bash
FLAVOR=staging
REVENUE_CAT_APPLE_KEY=appl_...
GOOGLE_DRIVE_SERVER_CLIENT_ID=...
```

Staging API host is fixed in code when `FLAVOR=staging`; you do not put the API URL in `.env`.

### 4. Build the IPA (staging)

From **`frontend/`**, run the build script. **Recommended for TestFlight + staging API:**

```bash
cd frontend
chmod +x scripts/build_ipa.sh
STAGING_TESTFLIGHT=1 ./scripts/build_ipa.sh
```

If **`FLAVOR=staging`** is already set in `.env`, `./scripts/build_ipa.sh` alone is enough.

The script:

- Runs **`flutter build ipa --release`** with **`ios/ExportOptions.plist`** (`app-store-connect` export).
- Injects **`--dart-define=FLAVOR=staging`** (when using `STAGING_TESTFLIGHT=1` or when `.env` says so).
- Injects RevenueCat and Google Drive defines from `.env`.

Optional overrides:

```bash
BUILD_NUMBER=63 BUILD_NAME=1.0.1 STAGING_TESTFLIGHT=1 ./scripts/build_ipa.sh
```

### 5. IPA output

The signed IPA is written under:

```text
frontend/build/ios/ipa/Halide.ipa
```

Confirm with:

```bash
ls -la frontend/build/ios/ipa/
```

### 6. Upload to TestFlight

**Option A — Apple Transporter (simple)**

Install [Transporter](https://apps.apple.com/us/app/transporter/id1450874784), open it, and drag **`Halide.ipa`** into the window. Deliver to App Store Connect, then assign the build in TestFlight.

**Option B — Command line (`altool`)**

From **`frontend/`** (so paths match):

```bash
cd frontend
xcrun altool --upload-app --type ios \
  --file build/ios/ipa/Halide.ipa \
  --api-key 9PTQG9323C \
  --api-issuer 8b3530de-316d-4584-8095-2a001c801243
```

Use **`--api-key`** and **`--api-issuer`** (hyphens). Put the whole command on one line, or use **`\`** at the end of each continued line. Do **not** use `--apiKey` / `--apiIssuer` (they are ignored and you get an authentication error).

Ensure the **`.p8`** key file is discoverable (commonly **`~/private_keys/AuthKey_9PTQG9323C.p8`**). If upload fails with an authentication error, verify the key path and that the API key has **App Manager** (or higher) access.

After processing in App Store Connect, enable the build for **internal** or **external** TestFlight testing.

### 7. Prod API on TestFlight (optional)

If you intentionally need **production** API in a TestFlight build, set **`FLAVOR=prod`** in `.env` and run **`./scripts/build_ipa.sh`** **without** `STAGING_TESTFLIGHT=1`. Do not use `STAGING_TESTFLIGHT=1` for that case.

## Build history

| Build | Version   | Date       | Delivery UUID |
|-------|-----------|------------|-----------------|
| 67    | 1.1.0+67  | 2026-05-12 | de0cfdb3-abd7-438d-8a6b-03dd5e8f5d43 |
| 66    | 1.0.1+66  | 2026-05-12 | |
| 65    | 1.0.0+65  | 2026-05-12 | *(upload failed: train 1.0.0 closed)* |
| 64    | 1.0.0+64  | 2026-04-29 | |
| 61    | 1.0.0+61  | 2026-04-20 | 9dcbf994-5277-4961-8d26-29ddbf8cde2c |
| 60    | 1.0.0+60  | 2026-04-16 | |
| 56    | 1.0.0+56  | 2026-04-12 | b14dddfc-9e70-4482-9180-2f586699210b |
| 54    | 1.0.0+54  | 2026-04-10 | cbd87724-e6a8-4d20-b676-53c3f023e888 |
| 53    | 1.0.0+53  | 2026-04-10 | b12d8922-fb49-495f-96d0-c85d828fc1cc |
| 52    | 1.0.0+52  | 2026-04-09 | f849f546-465c-4afe-bec9-98feb15710b2 |
| 49    | 1.0.0+49  | 2026-04-07 | 29166f64-1484-4c6a-b9bc-ec17d744b7e8 |
| 48    | 1.0.0+48  | 2026-04-06 | 683ecfe0-5857-4628-8b70-74192462368c |
| 47    | 1.0.0+47  | 2026-04-05 | d8164b6c-5619-4aac-a06a-a2992045a2da |
| 41    | 1.0.0+41  | 2026-04-05 | f37b24c3-3bde-48b3-9095-aca82a7cdccd |
| 40    | 1.0.0+40  | 2026-04-05 | c20fe1f5-b3de-4fed-9b29-9fdf3d4715e4 |
| 39    | 1.0.0+39  | 2026-04-05 | 6493e6cc-1c5b-47cd-be35-90603bfea0a6 |
| 31    | 1.0.0+31  | 2026-04-04 | 3a4da1bb-9322-4a52-87ed-d03000a6811e |
| 30    | 1.0.0+30  | 2026-04-04 | 10ac5f61-ee2b-4303-b904-864584eb4440 |
| 29    | 1.0.0+29  | 2026-04-04 | 17d5f4c6-988e-479a-8be7-715d87d50f6e |

## App Store Review: promoted IAP / win-back images (Guideline 2.3.2)

If review cites **2.3.2 – Accurate Metadata** and the **promotional image** for a **promoted In-App Purchase** or **win-back offer**, the fix is in **App Store Connect** (replace the promotional artwork), not in the Flutter binary. See **[app_store_iap_promotional_images.md](./app_store_iap_promotional_images.md)** for requirements and a resubmission checklist.

## Troubleshooting

- **No signing certificate "iOS Distribution" found**: Install a distribution certificate and select the correct team in Xcode (**Runner** → Signing & Capabilities).
- **Team mismatch**: `DEVELOPMENT_TEAM` in the Xcode project should match your Apple Developer team (see `ios/Runner.xcodeproj`).
- **`altool` authentication errors**: Use **`--api-key`** and **`--api-issuer`** (with hyphens); keep the command on one line or use `\` for line continuation. Confirm **`AuthKey_9PTQG9323C.p8`** location (often **`~/private_keys/`**), Key ID, Issuer ID, and API key role in App Store Connect.
- **409 “Invalid Pre-Release Train” / “train version 'X.Y.Z' is closed”** or **CFBundleShortVersionString must be higher than previously approved**: Bump the **marketing version** in `pubspec.yaml` (e.g. **`1.0.0` → `1.0.1`**) and rebuild the IPA; optionally bump the **`+` build** number as well, then upload again.
- **Invalid binary / processing failed**: Open App Store Connect for the detailed rejection reason; common issues are missing export compliance, missing privacy manifests, or invalid entitlements.
- **`Flutter/Flutter.h` file not found** / **`could not build module 'geolocator_apple'`** when archiving: run **`flutter clean`**, delete **`ios/Pods`**, **`ios/Podfile.lock`**, and **`build/`**, then **`flutter pub get`**, **`cd ios && pod install`**, and rebuild. The **`Podfile`** uses **`use_frameworks! :linkage => :static`** so pods resolve Flutter headers in Release/IPA builds.
- **Launch image placeholder warning** during `flutter build ipa`: does not block upload; replace default launch assets in Xcode when ready.
