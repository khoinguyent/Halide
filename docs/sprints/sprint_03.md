# Sprint 3: Data Integration & Dynamic Forms

Sprint 3 transitions the Halide app from static "Glass" mocks to a dynamic, database-driven experience. This includes implementing full CRUD forms for gear and film rolls, and seeding the database with realistic test data.

## Backend – BE_DEV_1 (Data Seeding & Master Data)

### [BE_3.1] Database Seeding Engine

- **Status**: DONE
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

- **Status**: DONE
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

- **Status**: DONE
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

- **Status**: DONE
- **Depends On**: [BE_3.1]
- **Assignee**: FE_DEV_1

**Summary**

Refactor existing BLoCs to fetch real data from the backend APIs. Replace all hardcoded "mock" objects with live DB content.

**Acceptance Criteria**

- "Your Rolls" and "Your Locker" screens display real user data from the database.
- Pull-to-refresh implemented on both main screens.
- Skeleton loaders persist until the API response is validated and mapped.

### [FE_3.2] Add New Roll Form Implementation

- **Status**: DONE
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

- **Status**: DONE
- **Depends On**: [FE_2.5]
- **Assignee**: FE_DEV_2

**Summary**

Update the Locker screen to match the "Your Rolls" layout, adding the header and the + button in the top right.

**Acceptance Criteria**

- Header typography matches the Rolls screen exactly.
- Global "Lenses" category is removed; lenses appear inside camera cards.
- Layout remains consistent with the high-fidelity screenshot state.

### [FE_3.4] Add Gear Input Form

- **Status**: DONE
- **Depends On**: [FE_3.3], [BE_3.3]
- **Assignee**: FE_DEV_2

**Summary**

Implement the input form for adding new cameras and lenses to the locker.

**Acceptance Criteria**

- Fields: Nickname, Manufacturer, Model, Serial Number.
- Toggle to specify if the gear item is a standalone lens.
- Successful submission refreshes the Locker list immediately.
