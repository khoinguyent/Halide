# Halide – Backend API Specification

## 1. Purpose

This document defines the backend API contracts (REST and GraphQL) for Halide. Backend and frontend agents must keep all changes consistent with this document.

---

## 2. General Conventions

- **Base REST URL**: `/api/v1`
- **GraphQL endpoint**: `/graphql`
- **Protocol**: HTTPS only
- **Auth header**: `Authorization: Bearer <firebase_id_token>`
- **Content type**: `application/json` for requests and responses
- **Timestamps**: ISO 8601 in UTC (e.g. `2026-03-13T10:00:00Z`)
- **Numeric fields**:
  - `shutter_speed` is expressed in seconds as a float (e.g. `0.004` for 1/250)
  - `ev_100` is a float representing EV at ISO 100

### 2.1 Standard Error Envelope

```json
{
  "code": "string",
  "message": "string",
  "details": {
    "field_errors": {
      "field_name": "description"
    }
  }
}
```

---

## 3. Data Models

These JSON shapes describe API payloads; internal DB schemas can extend them.

### 3.1 User
```json
{
  "id": "uuid",
  "email": "string",
  "display_name": "string",
  "auth_provider": "string",      // "google", "apple", "facebook"
  "created_at": "datetime"
}
```

### 3.2 Camera
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "brand": "string",
  "model": "string",
  "serial_number": "string|null",
  "format": "string",             // "35mm", "120", etc.
  "notes": "string|null"
}
```

### 3.3 Lens
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "brand": "string",
  "model": "string",
  "focal_length_mm": 50,
  "max_aperture": 1.8,
  "mount": "string|null",
  "notes": "string|null"
}
```

### 3.4 FilmStock
```json
{
  "id": "uuid",
  "name": "string",               // e.g. "Kodak Portra 400"
  "iso": 400,
  "type": "color_negative | bw | slide",
  "manufacturer": "string"
}
```

### 3.5 FilmRoll
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "film_stock_id": "uuid",
  "camera_id": "uuid|null",
  "lens_id": "uuid|null",
  "iso_override": 200,
  "push_pull_stops": 1,
  "status": "loaded | shooting | developed | scanned | archived",
  "notes": "string|null",
  "loaded_at": "datetime|null",
  "finished_at": "datetime|null"
}
```

### 3.6 Frame
```json
{
  "id": "uuid",
  "roll_id": "uuid",
  "frame_number": 1,
  "captured_at": "datetime|null",
  "ev_100": 10.5,
  "aperture": 2.0,
  "shutter_speed": 0.004,
  "metering_mode": "string|null", // "spot", "center", "matrix"
  "location_lat": 10.12345,
  "location_lng": 106.12345,
  "notes": "string|null"
}
```

### 3.7 Image
```json
{
  "id": "uuid",
  "frame_id": "uuid|null",
  "roll_id": "uuid|null",
  "lab_batch_id": "uuid|null",
  "cloud_key": "string",
  "format": "jpeg | tiff",
  "width": 4000,
  "height": 3000,
  "filesize": 1234567,
  "scan_index": 1,
  "imported_at": "datetime"
}
```

### 3.8 LabImportBatch
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "source_type": "gdrive | dropbox | url",
  "source_url": "string",
  "status": "pending | processing | failed | completed",
  "error_message": "string|null",
  "started_at": "datetime|null",
  "completed_at": "datetime|null"
}
```

---

## 4. REST API

### 4.1 Health
**GET** `/health`  
- **Auth**: None
- **Response**: `{"status": "ok"}`

### 4.2 Auth & Profile
**GET** `/api/v1/me`  
- **Auth**: Required
- **Description**: Returns the current authenticated user profile; creates a new user on first request.
- **Response**: `User` model

### 4.3 Gear – Cameras
**GET** `/api/v1/cameras`  
- **Description**: List all cameras owned by the current user.
- **Response**: `Camera[]`

**POST** `/api/v1/cameras`  
- **Body**:
```json
{
  "brand": "string",
  "model": "string",
  "serial_number": "string|null",
  "format": "string",
  "notes": "string|null"
}
```
- **Response**: Created `Camera`

**PATCH** `/api/v1/cameras/{id}`  
- **Body**: Partial `Camera` fields.
- **Response**: Updated `Camera`

**DELETE** `/api/v1/cameras/{id}`  
- **Response**: `204 No Content`

### 4.4 Gear – Lenses
Follows the same pattern as cameras.

**GET** `/api/v1/lenses`  
- **Response**: `Lens[]`

**POST** `/api/v1/lenses`  
- **Body**:
```json
{
  "brand": "string",
  "model": "string",
  "focal_length_mm": 50,
  "max_aperture": 1.8,
  "mount": "string|null",
  "notes": "string|null"
}
```

### 4.5 Film Stocks
**GET** `/api/v1/film-stocks`  
- **Description**: Read-only list of available film stocks.
- **Response**: `FilmStock[]`

### 4.6 Film Rolls

> **Implementation note:** Rolls and shots are documented end-to-end in [roll_and_shot_cycle.md](./roll_and_shot_cycle.md). The live API uses `RollOutDashboard` (flat object with `image_urls`, `shots`, `shot_offset`, etc.), not nested `roll` / `frames` / `images`.

**GET** `/api/v1/rolls`  
- **Response**: `RollOutDashboard[]` (dashboard list with film brand, camera name, gallery URLs, shot logs).

**GET** `/api/v1/rolls/{id}`  
- **Response**: `RollOutDashboard` (same shape as list item).

**POST** `/api/v1/rolls`  
- **Body**: `RollCreate` — `film_stock_id`, optional `user_camera_id`, `shot_at_iso`, `max_frames`, `title`, `description`.
- **Default status**: `shooting`.

**PATCH** `/api/v1/rolls/{id}/status`  
- **Body**: `{ "status": "shooting" | "lab" | "scanned" | "archived" | ... }` — forward-only transitions.

**PATCH** `/api/v1/rolls/{id}/meta`  
- **Body**: `{ "title", "description", "shot_offset" }` — alignment calibration for scan vs. log order.

**PATCH** `/api/v1/rolls/{id}/drive-url`  
- **Body**: `{ "drive_url": "https://drive.google.com/..." }` — lab folder / ZIP for sync.

**POST** `/api/v1/rolls/{id}/shots`  
- **Description**: Log a **shot without a scan** (meter or EXIF modal while `shooting`).
- **Body**:
```json
{
  "aperture": 2.8,
  "shutter_speed": "1/125",
  "lat": 10.77,
  "lng": 106.69,
  "notes": "optional",
  "logged_at": "2026-05-18T12:00:00"
}
```
- **Response**: `ImageOut` (`image_url` is null for log-only rows).

### 4.7 Frames (legacy spec)
**POST** `/api/v1/rolls/{roll_id}/frames`  
- **Description**: Create a new frame attached to the given roll.
- **Body**:
```json
{
  "frame_number": 1,
  "ev_100": 10.5,
  "aperture": 2.8,
  "shutter_speed": 0.004,
  "metering_mode": "spot",
  "location_lat": 10.12345,
  "location_lng": 106.12345,
  "notes": "Portrait by window"
}
```

### 4.8 Metering & AI Guidance
**POST** `/api/v1/meter/calc`  
- **Description**: Calculate matching exposure pair given EV and priority.
- **Body**:
```json
{
  "priority": "aperture",
  "aperture": 2.8,
  "shutter_speed": 0.004,
  "iso": 400,
  "ev_100": 10.5
}
```
- **Response**: Exposure parameters.

**POST** `/api/v1/meter/advice`  
- **Description**: Provide AI guidance for exposure safety and reciprocity.
- **Body**:
```json
{
  "film_stock_id": "uuid",
  "iso": 400,
  "ev_100": 10.5,
  "expected_exposure_seconds": 1.0,
  "scene_flags": ["deep_shadows", "backlit"]
}
```
- **Response**:
```json
{
  "recommended_adjustment_stops": 1.0,
  "warnings": ["reciprocity_risk"],
  "tips": ["Tip string"]
}
```

### 4.9 Lab Import
**POST** `/api/v1/lab-imports`  
- **Description**: Create a new lab import batch from a shared link.
- **Body**:
```json
{
  "source_type": "gdrive",
  "source_url": "url",
  "roll_hint_ids": ["uuid"]
}
```

**GET** `/api/v1/lab-imports/{id}`  
- **Description**: Get status and metrics for a batch.

### 4.10 Shooting Analytics

**GET** `/api/v1/analytics/shooting-matrix`  
- **Description**: Aggregated shooting dashboard for the authenticated user over the last **365 days**. Reads from the `mv_user_shooting_shots` materialized view (refreshed after shot writes and on dashboard load).
- **Query params**:
  - `timezone` (optional) — device IANA timezone override for this request.
  - `sync_timezone` (optional, default `false`) — when `true` and `timezone` is set, persist it on the user profile.
- **Timezone resolution**: `timezone` query param → `users.timezone` → `UTC`.
- **Response** (`ShootingMatrixResponse`):
```json
{
  "matrix": [{ "date": "2026-06-15", "count": 18 }],
  "streaks": { "current_streak": 12, "longest_streak": 28 },
  "top_emulsion": {
    "name": "Kodak Portra 400",
    "brand": "Kodak",
    "count": 142,
    "percentage": 42.0
  },
  "top_hardware": {
    "name": "Canon 50mm f/1.4",
    "count": 98,
    "percentage": 37.0
  },
  "emulsion_breakdown": [
    { "name": "Kodak Portra 400", "count": 142, "percentage": 42.0 }
  ],
  "hardware_breakdown": [
    { "name": "Canon 50mm f/1.4", "count": 98, "percentage": 37.0 }
  ],
  "lighting_insight": {
    "golden_hour_percentage": 64.0,
    "golden_hour_shots": 88,
    "total_shots": 138
  },
  "totals": { "total_shots": 338, "active_days": 142, "period_days": 365 },
  "timezone": "UTC"
}
```
- **Notes**:
  - `matrix` includes every calendar day in the window (missing days have `count: 0`). Days are grouped in the user's resolved local timezone.
  - Source data: materialized view `mv_user_shooting_shots` (365-day rolling window of denormalized shot facts).
  - `top_hardware` uses the roll's `user_lens_id` at shot time; rolls without a lens are excluded from hardware stats.
  - `current_streak` counts consecutive local days with `count > 0` ending today.
  - Golden hour: 4:00 PM–6:00 PM in the resolved timezone.

**PATCH** `/api/v1/user/timezone`  
- **Description**: Persist the user's IANA timezone (typically synced from the device on app launch).
- **Body**: `{ "timezone": "Asia/Bangkok" }`
- **Response**: `UserOut` (includes `timezone`).

---

## 5. GraphQL Schema

Mounted at `/graphql`.

```graphql
type User {
  id: ID!
  email: String!
  displayName: String!
}

type Camera {
  id: ID!
  brand: String!
  model: String!
  format: String!
  notes: String
}

type Lens {
  id: ID!
  brand: String!
  model: String!
  focalLengthMm: Int!
  maxAperture: Float!
}

type FilmStock {
  id: ID!
  name: String!
  iso: Int!
  type: String!
}

type FilmRoll {
  id: ID!
  status: String!
  filmStock: FilmStock!
  camera: Camera
  lens: Lens
  frames: [Frame!]!
  images: [Image!]!
}

type Frame {
  id: ID!
  frameNumber: Int!
  ev100: Float
  aperture: Float
  shutterSpeed: Float
}

type Image {
  id: ID!
  cloudKey: String!
  format: String!
  scanIndex: Int
}

type Query {
  me: User
  myGear: [Camera!]!
  myLenses: [Lens!]!
  myRolls(status: String): [FilmRoll!]!
  roll(id: ID!): FilmRoll
}

type Mutation {
  createCamera(
    brand: String!,
    model: String!,
    serialNumber: String,
    format: String!,
    notes: String
  ): Camera!

  createLens(
    brand: String!,
    model: String!,
    focalLengthMm: Int!,
    maxAperture: Float!,
    mount: String,
    notes: String
  ): Lens!

  createFilmRoll(
    filmStockId: ID!,
    cameraId: ID,
    lensId: ID,
    isoOverride: Int,
    pushPullStops: Int,
    notes: String
  ): FilmRoll!
}
```

### 5.1 Rules
- GraphQL changes must be additive.
- All mutations enforce same auth and validation rules as REST.

---

## 6. Versioning

- **REST**: Breaking changes require a new version prefix (`/api/v2`).
- **GraphQL**: Use additive changes only; deprecate fields before removal.