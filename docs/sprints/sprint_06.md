# Sprint 6: Advanced Tools & Storage V2

Sprint 6 introduces the high-fidelity Storage Strategy UI, the interactive cloud integration flow, and the internal Light Metering tool.

## Frontend – FE_DEV_1 (Storage UX V2)

### [FE_6.1] 3-Tier UI & State-Driven Connection Flow
- **Status**: DONE  
- **Assignee**: FE_DEV_1

**Summary**  
Implement the three-tier card selector and the multi-state integration workflow (List → Connecting → Success) for the Storage Strategy screen.

**Acceptance Criteria**
- Tier selector: cards for **Local Device (Free)**, **Personal Cloud (BYO)**, and **System Cloud (Pro)**. The active card uses an orange border and glow.
- View state manager with three explicit states:
  - `list`: standard settings / provider list view.
  - `connecting`: focused overlay with provider logo and spinner.
  - `success`: confirmation view with check icon and “Continue” button.
- Smooth animated transitions between states; app bar / navigation chrome is hidden during `connecting` and `success` to keep focus on the flow.

### [FE_6.2] Primary Archive Logic & Provider Grouping
- **Status**: DONE  
- **Assignee**: FE_DEV_1

**Summary**  
Implement the logic and UI for managing multiple instances of the same provider and designating a **Primary** storage target.

**Acceptance Criteria**
- Provider grouping: in the main list, group multiple connections under their parent provider (e.g., “Google Drive (2 linked)” with child rows for each account).
- Each linked account card shows account email/ID and a star icon (filled for primary, outline for secondary).
- Tapping “Set Primary” on a secondary account atomically promotes it to primary and demotes the previous one.
- “More” (⋮) menu reserved on each account row for future actions such as Disconnect/Rename.

## Frontend – FE_DEV_2 (Light Metering)

### [FE_6.3] Real-time Sensor Data & EV Calculation
- **Status**: DONE  
- **Assignee**: FE_DEV_2

**Summary**  
Use the device camera/sensor to measure ambient light levels and derive Exposure Value (EV) locally on the frontend.

**Acceptance Criteria**
- Service that listens to camera exposure parameters or ambient light sensor, emitting a stream of readings.
- EV is calculated using standard photography formulas (e.g., \(EV = \log_2(N^2 / t)\)) with ISO compensation.
- Public API surface that the Light Meter UI can subscribe to for continuous, debounced updates.

### [FE_6.4] Light Meter UI Overlay
- **Status**: DONE  
- **Assignee**: FE_DEV_2

**Summary**  
Create a professional spot-metering interface with interactive sliders layered over the camera preview.

**Acceptance Criteria**
- Spot meter: circular overlay that can be positioned over the preview to target specific light areas.
- Real-time display: continuous readout of suggested ISO, Aperture, Shutter Speed, and EV.
- Lock / Hold:
  - “Lock” button freezes the current reading.
  - Button shifts to orange with a subtle glow when active, with light haptics on toggle.
- Reciprocal exposure behavior: while locked, moving one parameter (e.g., ISO) recomputes the others (Shutter/Aperture) to keep exposure constant.
- Smooth, high-precision sliders for manual overrides.

## Backend – BE_DEV_1 (Support)

### [BE_6.1] Provider Metadata API
- **Status**: DONE  
- **Assignee**: BE_DEV_1

**Summary**  
Provide the frontend with consistent metadata for cloud providers so labels and icons are not hard-coded.

**Acceptance Criteria**
- Endpoint `GET /api/v1/storage/providers` returns a list of supported providers with:
  - Provider key (e.g., `gdrive`, `icloud`, `onedrive`, `nas`, `smb`).
  - Display name and short description.
  - Icon URL or asset key.
  - Auth-type requirements (e.g., OAuth vs host/username/password).
- Response contract documented so the Storage Strategy UI can be driven entirely from this metadata.