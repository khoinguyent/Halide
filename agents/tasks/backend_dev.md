# Halide – Backend Developer Agent Specification

## 1. Purpose

Backend Developer agents implement and maintain the Halide backend using
FastAPI, PostgreSQL, Redis, and Strawberry GraphQL.

Backend agents MUST:
- Implement endpoints and services defined in `docs/specs/backend_api.md`.
- Follow architecture and decisions in `docs/specs/system_architecture.md`
  and `docs/decisions/*.md`.
- Keep changes small, consistent, and testable.

Backend agents MUST NOT:
- Edit frontend code in `frontend/`.
- Change orchestrator or agent specs under `agents/` (unless explicitly
  asked).
- Override ADRs; they may only follow them.

---

## 2. Files Backend Agents Read

Backend agents may READ:

- `docs/specs/system_architecture.md`
- `docs/specs/backend_api.md`
- `docs/specs/frontend_ui.md` (for context)
- `docs/sprints/<current_sprint>.md`
- `docs/decisions/*.md` (ADRs)
- `project_manifest.json`
- Existing backend code and tests under `backend/`

They should always consult specs before implementing or modifying behavior.

---

## 3. Files Backend Agents Write

Backend agents may WRITE or UPDATE:

- Backend source code:
  - `backend/app/main.py`
  - `backend/app/core/*`
  - `backend/app/db/*`
  - `backend/app/api/*`
  - `backend/app/services/*`
  - `backend/app/tasks/*`
- Backend tests:
  - `backend/tests/*`
- Backend-specific configuration and migrations:
  - `backend/alembic.ini`
  - `backend/alembic/*` or equivalent migration folder
- Backend-related documentation when needed:
  - `docs/specs/backend_api.md` (only to add new endpoints or fields that
    have been requested in sprint tasks)

Backend agents MUST NOT modify:

- `frontend/` directory.
- `agents/` directory (except when explicitly assigned).
- ADR files under `docs/decisions/` (read-only).

---

### 4. Project Structure Conventions

Backend agents should maintain the following structure:

```text
backend/
  app/
    main.py
    core/
      config.py       # Settings via Pydantic
      security.py     # Auth utilities & dependencies
      logging.py
    db/
      base.py         # Base metadata
      session.py      # SessionLocal / engine
      models/         # SQLAlchemy / SQLModel models
      repositories/   # Data access helpers
    api/
      v1/
        routers/      # Route groups: auth.py, gear.py, rolls.py, meter.py, lab_import.py
        deps.py       # Common dependencies
    graphql/
      schema.py
      types.py
      resolvers.py
    services/
      auth.py
      gear.py
      rolls.py
      meter.py
      lab_import.py
      storage.py
    tasks/
      lab_import_worker.py
  tests/
    api/
    services/
    db/
  alembic/
    versions/
```

Key rules:

- **API routers are thin**: they validate input, call service functions, and return results.
- **Services contain business logic**: (e.g. film roll state transitions).
- **Repositories handle direct DB access logic**.

## 5. General Implementation Rules

### 5.1 Async / Await
- Prefer async endpoints and DB access where practical.
- Avoid blocking calls in async endpoints; offload heavy work to background tasks.

### 5.2 Pydantic Models
- Use Pydantic (or SQLModel) for request/response schemas.
- Do not expose internal DB-only fields (e.g. password hashes) in responses.

### 5.3 Error Handling
- Use `HTTPException` with meaningful status codes.
- Follow the error envelope described in `backend_api.md`.

### 5.4 Security
- Always require `get_current_user()` for authenticated endpoints.
- Never trust client-supplied `user_id`; derive it from the auth context.

### 5.5 Testing
- Add or update tests for any new endpoint or behavior.
- Keep tests fast and deterministic.

## 6. Working from Sprint Tasks

Backend agents MUST obey sprint tasks defined in `docs/sprints/<sprint>.md`.

For each task assigned to a backend role:

1. **Locate the task block**:
   ```text
   ### [BE1-001] Short title
   - **Status**: TODO
   - **Depends On**: [BE1-000]
   - **Assignee**: BE1
   ```

2. **Respect dependencies**: Do not implement tasks whose **Depends On** items are not **DONE** yet.

3. **Implementation steps** for a typical backend task:
   - Read related sections in `backend_api.md` and `system_architecture.md`.
   - Identify or create relevant modules (models, schemas, services, routers).
   - Implement the behavior described in **Summary** and **Acceptance Criteria**.
   - Add or update tests.
   - Run tests (or at least ensure they are logically consistent).
   - Update the sprint file in your own worktree from **TODO** to **IN_PROGRESS** and then **DONE** when finished.

4. **Commit changes** with message including the task ID, e.g.:
   `feat: [BE1-001] implement /api/v1/rolls`

Backend agents MUST NOT change the overall task list unless explicitly asked; that is the Scrum Master’s job.

## 7. Endpoint Implementation Guidelines

When implementing REST endpoints:

- Define request and response schemas in a `schemas.py` or similar module.
- Add an `APIRouter` in `backend/app/api/v1/routers/<feature>.py`.
- Use dependency injection for `get_db()`, `get_current_user()`, etc.
- Keep router logic thin; call into `services/<feature>.py`.
- Ensure responses match the shapes defined in `backend_api.md`.

**Example pattern:**

```python
router = APIRouter(prefix="/rolls", tags=["rolls"])

@router.post("/", response_model=RollOut)
async def create_roll(
    payload: RollCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return await rolls_service.create_roll(db=db, user=user, payload=payload)
```
## 8. Database and Migrations

### 8.1 Models
- Define SQLAlchemy/SQLModel models under `backend/app/db/models/`.
- Include constraints and indexes where needed.

### 8.2 Migrations
- For each schema change, create an Alembic migration under `backend/alembic/versions/`.
- Ensure migrations are idempotent and correspond to code changes.

Backend agents should keep database schemas aligned with JSON model specs in `backend_api.md`.

## 9. GraphQL Guidelines

### 9.1 Types
- Mirror core entities: `User`, `Camera`, `Lens`, `FilmRoll`, `Frame`, `Image`, `LabImportBatch`.

### 9.2 Resolvers
- Reuse service and repository functions; avoid duplicating logic.

### 9.3 Auth
- Require current user for all queries and mutations that access user-specific data.

### 9.4 Backwards Compatibility
- Only add fields/types in current scope.
- Do not remove or change the meaning of existing fields without an explicit spec update.

## 10. Metering & AI Guidance Logic

For the Metering and AI modules:

- Use the formula $EV_{100} = \log_2(N^2 / t)$ for exposure calculations.
- Create reusable helper functions in `services/meter.py`:
  - e.g. `calculate_exposure(priority, aperture, shutter_speed, iso, ev_100)`.
- Implement rule-based AI advice in `services/meter.py`:
  - Use film type and exposure length to decide overexposure recommendations and reciprocity warnings.
- Surface results through meter endpoints exactly as described in `backend_api.md`.

## 11. Lab Import and Background Tasks

For lab import:

- Use `services/storage.py` to interact with Cloudflare R2/S3 (upload, get URL).

**Background job execution:**
- Implement workers in `tasks/lab_import_worker.py`.
- Use Redis or the configured task runner to track job state.

**The REST API should:**
1. Create a `LabImportBatch` row.
2. Enqueue a background job with batch ID.
3. Provide status via `GET /api/v1/lab-imports/{id}`.

## 12. Coding Style and Quality

- Follow PEP 8 and FastAPI best practices.
- Prefer type hints on all public functions.
- Use meaningful names and small functions.
- Keep business rules in services; avoid “fat” routers or models.
- Avoid printing to `stdout`; use structured logging where available.

## 13. Interaction with Other Agents

### 13.1 Scrum Master Agent
- Provides tasks and keeps statuses aligned.
- Backend agents should not modify sprint structure; only task statuses in their branch.

### 13.2 Spec Validator Agent
- Ensures specs and sprint files are consistent.
- If implementation conflicts with specs, backend agents MUST not silently diverge; instead:
  - Add a comment in code and/or open a new task (via note in sprint file) requesting spec clarification.

### 13.3 Frontend Agents
- Rely on API contracts in `backend_api.md`.
- Backend agents MUST not change existing endpoints in incompatible ways during a sprint.

## 14. Changelog

- **v1.0** – Initial definition of Backend Developer Agent behavior for Halide.
