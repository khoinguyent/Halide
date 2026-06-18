# Promoted In-App Purchase & win-back images (Guideline 2.3.2)

Apple may reject under **Guideline 2.3.2 – Performance – Accurate Metadata** when the **promotional image** for a **promoted In-App Purchase** and/or **win-back offer** does not clearly and accurately represent that specific offer.

This applies to **App Store Connect metadata**, not to Flutter/Xcode code. Fixing it means **replacing the image(s) in App Store Connect** and resubmitting for review (same or new build, per Apple’s current flow).

## What reviewers flagged (typical)

1. **“Just a screenshot”** — a frame grab of the in-app purchase UI used as the promotional image. Apple expects **purpose-built promotional artwork**, not a scaled-down app screen.
2. **Text too small** — body copy, prices, or labels that are hard to read when the image appears on the App Store product page (including on **iPad**, which reviewers often use).

## What to upload instead

For **each** promoted IAP or win-back offer, use a **single, clear marketing image** that:

- **Matches only that offer** (e.g. “5 GB extra cloud storage” vs “Pro yearly” — do not reuse one image for multiple SKUs if the visuals blur together).
- Uses **large, high-contrast headline text** (rough guide at **1024×1024**: treat the **title line like a poster**, not like in-app UI; avoid long paragraphs).
- Stays **simple**: brand background + short headline + optional one-line benefit + simple icon or abstract graphic. Avoid dense app chrome, multi-panel screenshots, or illegible fine print.

Optional: add **localized** promotional images per language in App Store Connect if you promote in multiple regions.

## Technical specs (confirm in current Apple Help)

Apple documents requirements under **Promote In-App Purchases** and **In-App Purchase information**. As of common practice, promotional images are often:

- **1024 × 1024** px (or the size shown in App Store Connect for that slot — **always follow the upload UI**).
- **PNG or JPEG**, **RGB**, **flattened** (no transparency where disallowed), **no rounded corners** (the store masks them).

Official help (bookmark and re-check when Apple updates copy):

- [Promote In-App Purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/promote-in-app-purchases/)
- [View and edit In-App Purchase information](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/view-and-edit-in-app-purchase-information/)

## Where to change it in App Store Connect

1. **Apps** → **Halide Pro** (or your app name).
2. **In-App Purchases** or **Subscriptions** → select the **exact product** that is **promoted** (or the win-back offer).
3. Find **Promotional image** / **Promotion** (wording varies) and **replace** the asset.
4. Save, then complete **App Review** resubmission (and reply in Resolution Center if Apple asked for clarification).

## Halide-specific reminders

- **Consumable storage** (`halide_storage_*_ext`): promo image should say clearly **what GB pack** is offered (e.g. “Add 5 GB cloud storage”) in **large** type — not a full “Add storage” screen capture.
- **Subscription / Pro**: use artwork that reflects **subscription value** (Pro features headline), not a generic unrelated screen.
- **Win-back**: image must match the **win-back terms** Apple shows for that offer.

## Quick checklist before resubmit

- [ ] Every **promoted** IAP / win-back has its **own** image where required (no misleading reuse).
- [ ] No image is **only** a raw in-app screenshot with tiny UI text.
- [ ] Headline readable at **thumbnail** size on iPad and iPhone product page.
- [ ] File format and pixel size match **exactly** what App Store Connect requests for that field.

After updating assets, resubmit for review; no code change is required unless you are also addressing separate review notes.
