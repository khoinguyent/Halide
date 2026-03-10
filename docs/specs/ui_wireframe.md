# Halide - UI Wireframes

*Source of Truth for Frontend Layouts.*

## View: Roll Feed (Home Screen)
**Path**: `/frontend/lib/screens/home_screen.dart` (planned)

**Description**: The primary view displaying all of a user's film rolls in a modern, vertical feed. It focuses on a clean aesthetic with large white cards, subtle depth, typography, and preview images.

**Layout Breakdown**:
- **App Bar / Top Navigation**:
  - Left: App Logo text (e.g., "Halide" in bold, custom typography) + small trailing brand icon.
  - Center: Rounded toggle/selector pill (e.g., for filtering lists or feeds).
  - Right: Circular icon buttons for "Sort/Filter" (up/down arrows) and "Menu".
- **Floating Action Button (FAB)**:
  - Bottom Center placement.
  - Dark, pill-shaped button.
  - Icon: "+" and Text: "Open New Roll" (or equivalent local language string).
- **Body**:
  - `ListView` (vertical scrolling list of cards).
  - Background: Very light gray/off-white to make the white cards pop.
  - Components: `RollListCard` widgets.

**RollListCard Component (New Paradigm)**:
- **Container**: White rounded rectangle with subtle drop shadow for depth.
- **Header Section**:
  - Left side: Square thumbnail image of the film box artwork (e.g., Fujifilm 400).
  - Title (Top): `FilmStock.name` (bold, large, modern font).
  - Subtitle (Below Title): Gray text containing the camera used (`Cameras.model`), `shot_at_iso`, and start date (e.g., "M6 - ISO 400 - 2026/03/05").
  - Right side: `Roll.status` badge (e.g., 'Shooting', 'Finished Shooting', 'At Lab', 'Result Received') and frame count aligned to the right (e.g., "12 frames").
- **Image Previews (Bottom Section)**:
  - Inside the card, underneath the header text.
  - A horizontal row (`ListView.horizontal` or custom grid row) showing 4 to 5 square thumbnails of the scanned `Images`.
  - The row fills the width margin-to-margin inside the white card.

## View: Roll Detail
**Path**: `/frontend/lib/screens/roll_detail_screen.dart` (planned)

**Description**: Detailed view of a single roll and its associated images.

**Layout Breakdown**:
- **App Bar**:
  - Title: dynamically set to Roll `FilmStock.name`
  - Subtitle: `Roll.status` progression (e.g., visual tracker mapping 'Shooting' -> 'Finished Shooting' -> 'At Lab' -> 'Result Received')
  - Back Button (Left)
  - Action (Right): Edit icon
- **Header Section**:
  - Film metadata details: `shot_at_iso`, `expired_year`, start date (`created_at`), and Camera info (`Cameras.brand` and `Cameras.model`).
- **Body**:
  - Grid or List (toggleable) of `Image` records for this roll.
  - Each `Image` item displays:
    - Frame Number (`frame_number`)
    - Thumbnail of `image_url` (if available / 'Result Received')
    - Shot settings: `aperture` and `shutter_speed`
    - `notes` snippet
  - Floating Action Button (FAB): "Add Exposure" (opens form for a new frame, primarily used while 'Shooting').
