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
