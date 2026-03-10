# Sprint 00: Architectural Runway & Core Auth
**Goal:** Initialize the tech stack and establish the source of truth for 4 developers.

## 🔙 Backend (Python/FastAPI + PostgreSQL + Redis)
- **BE_DEV_1 (Infra & Model):** - Setup `docker-compose.yml` with PostgreSQL (Port 5432) and Redis (Port 6379).
    - Initialize FastAPI project with `SQLAlchemy` and `alembic`.
    - Create models for `Users`, `FilmStocks`, `Cameras`, and `Rolls` based on `/docs/specs/db_schema.md`.
- **BE_DEV_2 (Security & API):**
    - Implement JWT-based registration and login.
    - Create `GET /rolls` and `POST /rolls` endpoints.
    - Setup the `UserCamera` CRUD endpoints.

## 📱 Frontend (Flutter Mobile/Web)
- **FE_DEV_1 (Navigation & State):**
    - Initialize Flutter project and configure `GoRouter`.
    - Setup `Riverpod` or `Provider` for global state (Auth/Rolls).
    - Create empty views for: Home, Roll Detail, and Profile.
- **FE_DEV_2 (UI Components):**
    - Implement the `RollCard` widget. 
    - **Constraint:** Must visually mimic a physical film box; colors must change dynamically based on the `FilmStock` (e.g., Yellow for Kodak, Green for Fuji).

## ✅ Definition of Done
- All backend endpoints return 200 OK via Swagger.
- Flutter app compiles for both Web and Mobile.
- Agents verify code against `/docs/specs/`.