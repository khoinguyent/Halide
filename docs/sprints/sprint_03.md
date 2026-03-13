<<<<<<< HEAD
<<<<<<< HEAD
# Sprint 3: Data Integration & Dynamic Forms

Sprint 3 transitions the Halide app from static "Glass" mocks to a dynamic, database-driven experience. This includes implementing full CRUD forms for gear and film rolls, and seeding the database with realistic test data.

## Backend – BE_DEV_1 (Data Seeding & Master Data)

### [BE_3.1] Database Seeding Engine

- **Status**: TODO
- **Depends On**: [BE_2.1]
- **Assignee**: BE_DEV_1

**Summary**

Create a seeding engine to populate the PostgreSQL database for the current user. Generate realistic dummy records for Cameras, Lenses, FilmStocks, and metadata-rich FilmRolls to facilitate testing.

**Acceptance Criteria**

- Script creates at least 3 cameras and 5 lenses (using nicknames) for the primary user.
- Generates 10 historical rolls with varied statuses (scanned, lab, shooting).
- Populates frame-level metadata (ISO, Shutter, Aperture, GPS) for at least 20 entries.
- Accessible via CLI or a protected internal endpoint.

### [BE_3.2] Film Master Registry

- **Status**: TODO
- **Depends On**: [BE_2.1]
- **Assignee**: BE_DEV_1

**Summary**

Implement a "Master" film stock registry table to power the searchable picklists in the frontend's "Add Roll" form.

**Acceptance Criteria**

- Table `film_stock_master` seeded with brands like Kodak, Fujifilm, and Ilford.
- Includes fields: `brand`, `name`, `default_iso`, and `type` (slide, negative, b&w).
- Endpoint `GET /api/v1/master/films` supports search by brand or name.

## Backend – BE_DEV_2 (Schema Refinement)

### [BE_3.3] Gear Schema Refactor (Nesting Lenses)

- **Status**: TODO
- **Depends On**: [BE_2.4]
- **Assignee**: BE_DEV_2

**Summary**

Modify the gear API and DB relationships to remove the global "Lenses" section. Lenses should now be managed as sub-items within specific gear/camera objects.

**Acceptance Criteria**

- Camera model updated to include a relationship with Lenses.
- Gear API response nests lenses inside the parent camera items.
- Top-level `/lenses` categories are removed from the dashboard response.

## Frontend – FE_DEV_1 (Rolls & Data Wiring)

### [FE_3.1] Live Data Integration

- **Status**: TODO
- **Depends On**: [BE_3.1]
- **Assignee**: FE_DEV_1

**Summary**

Refactor existing BLoCs to fetch real data from the backend APIs. Replace all hardcoded "mock" objects with live DB content.

**Acceptance Criteria**

- "Your Rolls" and "Your Locker" screens display real user data from the database.
- Pull-to-refresh implemented on both main screens.
- Skeleton loaders persist until the API response is validated and mapped.

### [FE_3.2] Add New Roll Form Implementation

- **Status**: TODO
- **Depends On**: [FE_2.1], [BE_3.2]
- **Assignee**: FE_DEV_1

**Summary**

Implement the "Add Roll" form triggered by the + button on the Rolls tab.

**Acceptance Criteria**

- Form features a searchable picklist for Film Name (using data from [BE_3.2]).
- Includes inputs for ISO, Image Count, and Type (Slide/Negative/B&W).
- Includes a gear selector that pulls from the user's registered cameras.
- Uses a glass-morphism overlay style.

## Frontend – FE_DEV_2 (Locker & Gear Forms)

### [FE_3.3] Locker Screen Refinement

- **Status**: TODO
- **Depends On**: [FE_2.5]
- **Assignee**: FE_DEV_2

**Summary**

Update the Locker screen to match the "Your Rolls" layout, adding the header and the + button in the top right.

**Acceptance Criteria**

- Header typography matches the Rolls screen exactly.
- Global "Lenses" category is removed; lenses appear inside camera cards.
- Layout remains consistent with the high-fidelity screenshot state.

### [FE_3.4] Add Gear Input Form

- **Status**: TODO
- **Depends On**: [FE_3.3], [BE_3.3]
- **Assignee**: FE_DEV_2

**Summary**

Implement the input form for adding new cameras and lenses to the locker.

**Acceptance Criteria**

- Fields: Nickname, Manufacturer, Model, Serial Number.
- Toggle to specify if the gear item is a standalone lens.
- Successful submission refreshes the Locker list immediately.
=======
# Sprint 3

## Frontend – FE_DEV_2 (UI Components & Feature Screens)

[FE_3.3] Locker Refinement
- Status: TODO
- Summary: Update the Locker screen to match the 'Your Rolls' header style. Move lenses inside the camera cards as sub-items, removing the global lenses category.
- Acceptance Criteria:
  - Header matches "Your Rolls" typography and spacing.
  - Lenses are nested within their respective camera cards.
  - Global "Lenses" section is removed.

[FE_3.4] Add Gear Form
- Status: TODO
- Summary: Implement the form for adding cameras and lenses. Include fields for Nickname, Manufacturer, Model, and Serial Number.
- Acceptance Criteria:
  - Form exists for adding new gear.
  - Fields for Nickname, Manufacturer, Model, and Serial Number are present.
  - Form matches Halide visual standards (GlassPanel, HalideScaffold).
>>>>>>> feat/sprint_03/fe_dev_2
=======
# Sprint 03 - Seeding & Master Data

## Backend Tasks (BE_DEV_1)

### [BE_3.1] Seeding Engine
- **Status**: DONE
- **Description**: Create a robust seeding script/service that populates the PostgreSQL database for the current user with 3 cameras, 5 lenses, and 10 historical rolls. Use metadata-rich data (Aperture, Shutter, GPS) for at least 20 frames.

### [BE_3.2] Master Registry
- **Status**: DONE
- **Description**: Implement the FilmStockMaster table and a searchable GET /api/v1/master/films endpoint to power the frontend picklists.
- **Acceptance Criteria**:
    - Queryable by name, brand, iso.
    - Idempotent seeding of master film stocks.
>>>>>>> feat/sprint_03/be_dev_1
