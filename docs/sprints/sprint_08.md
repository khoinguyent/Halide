# Sprint 8: EXIF Capture & Interactive Controls

Sprint 8 focuses on enhancing the film-shooting experience by allowing users to log technical parameters (Aperture, Shutter Speed) and metadata (Location, Time) for each shot in a roll, even before the film is developed.

## Frontend – FE_DEV_1 (EXIF Logging)

### [FE_8.1] Quick Action: Record Shot in Shooting Roll
- **Status**: TODO
- **Assignee**: FE_DEV_1

**Summary**  
Add a prominent "Record Shot" quick action button to the `RollDetailView` when the roll status is `shooting`.

**Acceptance Criteria**
- New button (e.g., FAB or fixed bottom bar) labeled "Record Shot" visible only during the `shooting` phase.
- Tapping the button launches the interactive EXIF capture modal.
- Includes haptic feedback on tap.

### [FE_8.2] Interactive EXIF Capture Modal & Sliders
- **Status**: TODO
- **Assignee**: FE_DEV_1

**Summary**  
A high-fidelity modal for logging shot parameters with interactive sliders and visual feedback.

**Acceptance Criteria**
- **Aperture Slider**:
  - Discrete f-stop values: 0.9, 1.2, 1.4, 1.7, 1.8, 2.0, 2.4, 2.8, 3.5, 4.0, 4.5, 5.6, 6.7, 8.0, 11, 16, 22.
  - **Aperture Mimic**: A visual element (SVG or Canvas) that simulates the aperture blades opening/closing dynamically as the slider moves.
- **Shutter Speed Slider**:
  - Range from 1/4000s to 1s in standard increments.
- **Automatic Metadata**:
  - Capture current GPS coordinates (lat/long) and high-precision timestamp.
- **Record Action**:
  - A "LOG SHOT" button that persists the data to the backend.

## Backend – BE_DEV_1 (Support)

### [BE_8.1] Shot Log Data Model & API
- **Status**: TODO
- **Assignee**: BE_DEV_1

**Summary**  
Extend the data model and API to support "log-only" shots that don't yet have an associated image file.

**Acceptance Criteria**
- Update `Image` model: `image_url` made nullable or updated to support a `null` value for shot logs.
- New endpoint `POST /api/v1/rolls/{id}/shots` to create a shot log entry.
- Ensure `created_at` or a new `shot_time` field accurately reflects the logging time.
- Update `get_roll` logic to include these shot logs in the `image_urls` list (return as `null` or with a placeholder for the frontend).
