# Backend Structure – Quick Guide

## Where to put things

- Auth helpers → `app/core/security.py`
- DB models → `app/db/models/`
- Pydantic schemas → `app/db/schemas/`
- Business logic → `app/services/`
- REST endpoints → `app/api/v1/`
- GraphQL schema/resolvers → `app/graphql/`
- Background workers → `app/tasks/`

## Rules

- Routers call services; services talk to DB and other services.
- Do not put business logic into routers or GraphQL resolvers.
- Always update `docs/specs/backend_api.md` when adding/changing endpoints.
- Keep filenames and import paths consistent with `docs/specs/backend_structure.md`.
- Run the server from `backend/` using: `uvicorn app.main:app --reload`
