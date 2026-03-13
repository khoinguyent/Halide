# Halide – Backend Structure & Conventions

## 1. Purpose

This document defines how backend code is organized so multiple agents can work without conflicts.

## 2. High-Level Layout

- All application code lives under `backend/app/`.
- Cross-cutting concerns in `core/`.
- Database models and schemas in `db/`.
- HTTP routes in `api/v1/`.
- Business logic in `services/`.
- GraphQL in `graphql/`.
- Background jobs in `tasks/`.

## 3. Module Responsibilities

- `core/config.py`: Pydantic settings, reads `.env`.
- `core/security.py`: Firebase/JWT verification helpers.
- `core/dependencies.py`: `get_db()`, `get_current_user()`.

- `db/models/*.py`: SQLAlchemy models (one entity family per file).
- `db/schemas/*.py`: Pydantic schemas for requests/responses.

- `api/v1/*.py`: FastAPI routers, thin controllers that:
  - validate input via schemas,
  - call `services/*`,
  - return response schemas.

- `services/*_service.py`: Business logic:
  - DB queries via models/Session only.
  - No FastAPI decorators or HTTP concerns.

- `graphql/schema.py`: Assembles Strawberry schema.
- `graphql/types.py`: Strawberry type definitions based on models/schemas.
- `graphql/resolvers/*.py`: Functions used by Strawberry, calling services.

## 4. Implementation Rules

- A new endpoint MUST:
  - add or reuse Pydantic schemas in `db/schemas/`,
  - add a route in the correct `api/v1/*.py`,
  - implement logic in `services/*_service.py`,
  - update tests under `backend/tests/`.

- A new DB entity MUST:
  - add model file in `db/models/`,
  - add corresponding schemas file,
  - create Alembic migration.

- GraphQL fields MUST not introduce business rules that differ from REST.

## 5. File Naming

- Use snake_case filenames.
- Suffix services with `_service.py`.
- Suffix BQ workers with `_worker.py`.
