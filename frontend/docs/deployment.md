# Deployment Guide for Halide iOS

This document outlines the steps to build and distribute the Halide application to TestFlight.

## Prerequisites

- **Apple Distribution Certificate**: Must be installed in the macOS Keychain.
- **App Store Connect API Key**: 
  - Key ID: `9PTQG9323C`
  - Issuer ID: `8b3530de-316d-4584-8095-2a001c801243`
  - Key File: `AuthKey_9PTQG9323C.p8`
  - Key Location: `~/.private_keys/` (The file must be named `AuthKey_<KeyID>.p8` and located in `~/.private_keys/` for `altool` to find it).

## Step 1: Build the IPA

Run the build script from the `frontend` directory:

```bash
bash scripts/build_ipa.sh
```

This will increment the build number (if configured) and generate an `.ipa` file at `build/ios/ipa/Halide.ipa`.

## Step 2: Upload to TestFlight

Use `xcrun altool` to upload the generated IPA:

```bash
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/Halide.ipa \
  --apiKey 9PTQG9323C \
  --apiIssuer 8b3530de-316d-4584-8095-2a001c801243
```

Alternatively, you can use the **Transporter** app by dragging and dropping the `Halide.ipa` file.
