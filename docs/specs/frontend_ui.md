# Halide – Frontend UI Specification (Flutter + BLoC)

## 1. Purpose

This document defines the UI structure, navigation, and interaction patterns of
the Halide Flutter app. Frontend Developer agents MUST use this as the single
source of truth for screens, flows, and state behavior.

---

## 2. App Architecture Overview

### 2.1 Platform Targets

- iOS (latest two major versions)
- Android (API 29+)
- Web (modern evergreen browsers)

### 2.2 Architectural Style

- Flutter app organized **feature-first** (per feature folder).[web:89][web:93]
- State management: **BLoC** (via `flutter_bloc` or compatible package).[web:91][web:95]
- Navigation: declarative routing using a single router (e.g. `go_router`) or
  `Navigator 2.0`, but consistently via `router.dart`.[web:90][web:98]

### 2.3 Project Layout (UI Perspective)

```text
lib/
  app/
    app.dart          # App root, theme, top-level BlocProviders
    router.dart       # Routes and navigation configuration
    theme.dart        # Colors, typography, component themes
    layout.dart       # Breakpoints & responsive helpers (if needed)
  core/
    widgets/          # Shared components (buttons, text fields, etc.)
    util/             # Helpers (formatting, date, etc.)
  features/
    auth/
      bloc/
      models/
      screens/
      widgets/
    locker/
      bloc/
      models/
      screens/
      widgets/
    rolls/
      bloc/
      models/
      screens/
      widgets/
    meter/
      bloc/
      models/
      screens/
      widgets/
    lab_import/
      bloc/
      models/
      screens/
      widgets/
    gallery/
      bloc/
      models/
      screens/
      widgets/
    settings/
      bloc/
      models/
      screens/
      widgets/
  services/
    api/
    auth/
    storage/

## 2.4 Design System & Layout

All screens MUST follow the same “glass card over dark photo” style shown in
the login mockup.

### 2.4.1 Shared Layout Components

The following shared widgets MUST be used by all feature screens:

- `HalideScaffold`
  - Root widget for all top-level screens.
  - Layout:
    - Background: dark photo or gradient layer.
    - Foreground: centered content area.
- `GlassPanel`
  - Semi-transparent dark card with blur, rounded corners, and padding.
  - Used to contain the main content of each screen (forms, lists, etc.).

Implementation notes (Flutter):

- Place these widgets under `lib/core/widgets/`:
  - `halide_scaffold.dart`
  - `glass_panel.dart`
- Each screen’s `build` method should look conceptually like:

```dart
return HalideScaffold(
  child: GlassPanel(
    child: <screen-specific content>,
  ),
);

No screen should implement its own background or card styling; it must reuse
these widgets.

2.4.2 Colors and Typography
All text and components MUST use theme values defined in app/theme.dart,
not hard-coded colors or fonts.

Colors:

Background: dark, desaturated image / gradient.

Panel: semi-transparent dark (#111111–#222222 with opacity).

Primary text: light gray.

Secondary text: medium gray (e.g. #A9A9A9).

Text styles:

headlineLarge: app name / main titles.

titleMedium: section headers.

bodyMedium: body copy and descriptions.

labelLarge: button labels.

Buttons:

Use shared widgets in core/widgets/:

PrimaryButton – filled, rounded, main CTA.

SecondaryButton – outlined or lower emphasis.

LinkTextButton – for “Sign up”, “Forgot password?” links.

2.4.3 Screen Composition Rules
For every new screen:

Use HalideScaffold as the root.

Place main content inside a single GlassPanel (or clearly grouped panels).

Use theme text styles and shared button widgets.

Keep a vertical layout with generous padding similar to the login mockup.

For bottom links (e.g. “Sign up”, “Forgot password?”), use LinkTextButton
aligned under the main panel.

Frontend tasks MUST explicitly mention using HalideScaffold, GlassPanel,
and shared buttons when implementing or updating screens.

## 3. Navigation and Routes

### 3.1 Route Map
Named routes (route IDs; actual implementation via `router.dart`):

```text
/splash              – SplashScreen
/auth/login          – LoginScreen
/main                – MainShell (bottom navigation)
/main/locker         – LockerScreen
/main/rolls          – RollListScreen
/main/meter          – MeterScreen
/main/settings       – SettingsScreen
/rolls/:id           – RollDetailScreen
/rolls/:id/new-frame – FrameFormScreen/Sheet
/lab-import/new      – LabImportCreateScreen
/lab-import/:id      – LabImportStatusScreen
/image/:id           – ImageDetailScreen
```

### 3.2 Navigation Rules
- **On app start**:
  1. Show `SplashScreen`.
  2. Check auth state via `AuthBloc`.
  3. Navigate to `/auth/login` if unauthenticated, `/main` if authenticated.

- **Bottom navigation**:
  - Tabs: Locker, Rolls, Meter, Settings.
  - State is preserved when switching tabs.

- **Detail navigation**:
  - Selecting a roll from `RollListScreen` navigates to `/rolls/:id`.
  - From `RollDetailScreen`:
    - “Add Frame” → `/rolls/:id/new-frame` as modal/sheet.
    - “View Image” → `/image/:id`.

## 4. Core Screens and Behavior

### 4.1 SplashScreen
- **Purpose**: Bootstrap app, restore session.
- **Behavior**:
  - Immediately dispatch `AuthStarted` event.
  - Show centered logo + loading indicator.
  - On `AuthAuthenticated` → navigate to `/main`.
  - On `AuthUnauthenticated` → navigate to `/auth/login`.

### 4.2 LoginScreen
- **Shows**:
  - App logo.
  - Short description: “Sign in to manage your film rolls.”
  - Buttons: “Continue with Google”, “Continue with Apple”, “Continue with Facebook”.
- **Behavior**:
  - Button press → dispatch `AuthLoginRequested(provider)` to `AuthBloc`.
  - While logging in: disable buttons, show loading indicator.
  - On success: navigate to `/main`.
  - On failure: show error snackbar, re-enable buttons.

## 5. Main Shell and Tabs

### 5.1 MainShell
- **Layout**:
  - Top app bar with title (changes per tab).
  - Body area for tab content.
  - Bottom navigation bar with icons + labels:
    - Locker (camera icon)
    - Rolls (film icon)
    - Meter (light-meter icon)
    - Settings (gear icon)
- **State**:
  - Shell holds current tab index.
  - Each tab can have its own BLoC(s) provided either at shell or feature level.

## 6. Locker Feature (Gear Management)

### 6.1 LockerScreen
- **Layout**:
  - Two sections: “Cameras” list, “Lenses” list.
  - Each section shows list items with brand + model + format/focal length + max aperture.
  - FAB or plus icon for adding new camera/lens.
- **State**:
  - Uses `LockerBloc` with events: `LockerStarted`, `LockerRefreshed`.
  - **Initial load**: On first build, dispatch `LockerStarted`, show loading indicator.
  - On success, show lists; on error, show retry button.

### 6.2 CameraFormScreen
Used for both create and edit.
- **Fields**: Brand, Model, Serial number, Format, Notes.
- **Buttons**: “Save”, “Cancel”.
- **Behavior**:
  - Validation errors shown inline.
  - On submit: dispatch `CameraSaved` event; show loading state.
  - On success, close screen and refresh Locker list.

### 6.3 LensFormScreen
Similar to `CameraFormScreen`.
- **Fields**: Brand, Model, Focal length, Max aperture, Mount, Notes.

## 7. Rolls Feature

### 7.1 RollListScreen
- **Layout**: Segmented control or chips: Active, In Lab, Archived.
- **Roll card**: Film stock, ISO, Camera/Lens, Status badge, Date.
- **State**: `RollListBloc` (`RollListStarted`, `RollListTabChanged`, `RollListRefreshed`).
- **Interaction**: Pull-to-refresh; tap roll to navigate to detail.

### 7.2 RollDetailScreen
- **Header**: Film stock, ISO, Camera, Lens, Status.
- **Metadata**: Push/pull, dates, notes.
- **Frames area**: List of frames (number, settings, note).
- **Gallery preview**: Horizontal strip or grid of thumbnails.
- **Actions**: “Add Frame”, Status change menu.

### 7.3 RollFormScreen (New Roll)
- **Fields**: Film stock (picker), Camera, Lens, ISO override, Push/pull, Notes.
- **Behavior**: Dispatch `RollFormSubmitted` on save; navigate to detail on success.

## 8. Frame Logging Feature

### 8.1 FrameFormScreen/Sheet
- **Exposure**: Aperture dropdown, Shutter speed picker, ISO (read-only).
- **Meter integration**: “Use Meter Suggestion” button.
- **Behavior**: Dispatch `FrameFormSubmitted` on success; close and refresh list.

## 9. Meter Feature

### 9.1 MeterScreen
- **Layout**: Camera preview window (platform permitting), Mode toggle (A/S priority), EV display, Selectors.
- **AI Guidance panel**: Tips and warnings (overexposure, reciprocity).
- **Behavior**: Calls `/api/v1/meter/calc` and `/api/v1/meter/advice` on parameter change.

## 10. Lab Import & Gallery Feature

### 10.1 LabImportCreateScreen
- **Fields**: Source type (GDrive, Dropbox, URL), Source URL, Roll selection.
- **Behavior**: Dispatch `LabImportCreated`; navigate to status screen.

### 10.2 LabImportStatusScreen
- **Shows**: Status badge (Pending/Processing/Completed/Failed), Batch metrics.
- **Behavior**: `LabImportBloc` polls backend; show “View rolls” link on completion.

### 10.3 Gallery (Roll-centric)
- **Thumbnail grid** in `RollDetailScreen`.
- **ImageDetailScreen**: Full-screen view with exposure overlay; swipe navigation.

## 11. Settings Feature

### 11.1 SettingsScreen
- **Account**: Display name, email, “Sign out” button.
- **Metering preferences**: Default mode (Aperture / Shutter), Overexposure preference.
- **App**: Theme (Light / Dark / System).
- **State**: `SettingsBloc` or `Cubit` persisted locally.

## 12. UI/UX Guidelines
- **Visual style**: Minimal, film-inspired aesthetic with high-contrast typography.
- **Loading**: Progress indicators or skeleton loaders.
- **Error messages**: Friendly, actionable, mapped from backend codes.
- **Responsiveness**: Mobile-first; two-pane layouts for tablets/web.

## 13. Platform-Specific Notes
- **Web**: Disable unsupported native features; adjust scroll/hover behavior.
- **Mobile**: Handle safe areas, gestures, and orientation changes.

## 14. Extension Rules
New screens or flows MUST:
1. Be added under the appropriate feature folder.
2. Be documented in this file.
3. Follow the BLoC pattern (`Widget → BLoC → Service`).
4. Update ADRs for significant architectural shifts.
