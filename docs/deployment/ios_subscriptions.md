# Setup Guide: iOS Auto-Renewable Subscriptions (RevenueCat)

This guide provides the steps to configure subscriptions in App Store Connect and sync them with your RevenueCat project.

## Step 1: App Store Connect Prerequisites
1.  **Agreements**: Go to **Agreements, Tax, and Banking** and ensure the **Paid Applications** agreement is signed and active.
2.  **Tax & Banking**: Ensure your bank account and tax forms are completed, otherwise subscriptions will not appear in the app.

## Step 2: Create a Subscription Group
Groups prevent users from buying multiple competing plans.
1.  Go to **Apps** > **Halide** > **Subscriptions**.
2.  Click **Create** under **Subscription Groups**.
3.  Name it (e.g., `Pro Access`).

## Step 3: Create the Product
1.  Inside your group, click **Create** under **Subscriptions**.
2.  **Reference Name**: `Halide Pro Yearly` (for internal use).
3.  **Product ID**: `com.halide.halidemanagement.pro.yearly` (must be unique).
4.  **Duration**: Select a period (e.g., 1 Year). This duration **defines the recurrence cycle**. The subscription will automatically bill the user and renew at this interval until they cancel.

## Step 4: Configure Pricing & Details
1.  **Subscription Price**: Set your price (e.g., $29.99/year).
2.  **App Store Localization**: Provide a display name and description for the App Store (e.g., "Pro Membership").
3.  **Review Metadata**: You MUST upload a screenshot of your paywall for Apple review before you can submit.
4.  **Promoted IAP / win-back promotional image** (if you use **Promote** on the product page or win-back offers): use **purpose-built 1024×1024-style artwork** with **large readable text**. Raw in-app screenshots with tiny UI copy often fail **Guideline 2.3.2** — see [app_store_iap_promotional_images.md](./app_store_iap_promotional_images.md).

## Step 5: RevenueCat Integration
1.  **Shared Secret**: In App Store Connect, go to **App Information** and generate an **App-Specific Shared Secret**.
2.  **RevenueCat Dashboard**:
    - Go to **Project Settings** > **Apps** > **App Store**.
    - Paste the **Shared Secret** and **Bundle ID**.
3.  **Entitlements**: Ensure you have an entitlement (e.g., `pro`) in RevenueCat.
4.  **Offerings**: Add your new Product ID to a RevenueCat **Package** (e.g., `$rc_yearly`).

## Step 6: Testing
- Create a **Sandbox Tester** account in App Store Connect.
- Log in on your physical device and perform a purchase.
- The "Pro" features should unlock immediately.
