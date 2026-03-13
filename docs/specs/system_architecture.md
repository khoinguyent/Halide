# Halide – System Architecture Specification

## 1. Document Purpose

This document defines the overall architecture of the Halide film photography
management system. It is the single source of truth for all agents (backend,
frontend, and coordination) about high-level design decisions, terminology, and
system boundaries.

## 2. Product Overview

Halide is a specialized film photography management ecosystem that bridges
analog shooting and digital archiving. It supports gear tracking, film roll
lifecycle management, light metering with AI guidance, and automated lab scan
ingestion.

Core user goals:

- Track cameras, lenses, and film stocks in a personal **Locker**.
- Track film rolls from loading to scanning, with accurate metadata.
- Use a software light meter plus AI guidance to choose exposure.
- Import lab scans from cloud storage, grouped by physical roll.

## 3. High-Level Architecture

### 3.1 Components

- **Frontend App**
  - Flutter application targeting iOS, Android, and Web.
  - Communicates with backend via REST and GraphQL APIs over HTTPS.
- **Backend API**
  - Python FastAPI application exposing REST and Strawberry GraphQL endpoints.
  - Encapsulates domain logic for auth, gear, rolls, metering, and lab import.
- **Database**
  - PostgreSQL instance storing all persistent domain data.
- **Cache / Task Queue**
  - Redis instance used for caching and background job coordination.
- **Object Storage**
  - Cloudflare R2 / S3-compatible bucket storing scan images (JPEG/TIFF).
- **Authentication Provider**
  - Firebase Authentication providing social login (Google, Apple, Facebook).

### 3.2 Runtime View

- Frontend obtains Firebase ID token after social login.
- Frontend calls backend with `Authorization: Bearer <firebase_token>`.
- Backend validates token, maps it to an internal `User` record, and handles
  authorized requests.
- Background jobs (lab import, heavy processing) are enqueued via Redis and
  executed by worker processes sharing the same codebase.
- Images are stored in object storage; database only stores metadata and object
  keys.

## 4. Technology Stack

- **Backend**
  - Language: Python 3.x
  - Framework: FastAPI
  - API: REST + Strawberry GraphQL
  - ORM: SQLAlchemy or SQLModel
  - DB: PostgreSQL
  - Cache / Queue: Redis
- **Frontend**
  - Language: Dart
  - Framework: Flutter
  - State Management: Riverpod or BLoC (see frontend_ui.md)
  - Networking: GraphQL client + REST client
- **Infrastructure**
  - Containerization: Docker
  - Auth: Firebase Auth
  - Storage: Cloudflare R2 / S3
  - Reverse proxy / CDN: Cloudflare

## 5. Domain Modules

### 5.1 User & Gear Management

- Manage User profile linked to external auth provider.
- Manage Camera bodies and Lenses in the Locker.
- Associate camera and lens with a film roll for accurate metadata.

### 5.2 Film Roll Lifecycle

- States: `loaded`, `shooting`, `developed`, `scanned`, `archived`.
- Metadata: film stock, ISO, push/pull processing, notes, timestamps.
- Frames: optional per-frame exposure and location data.
- Gallery: digital view of scans grouped by film roll.

### 5.3 Light Metering & AI Guidance

- **Metering**:
  - Uses device camera sensor to approximate scene EV.
  - Uses formula $EV_{100} = \log_2(N^2 / t)$ for exposure calculations.
- **AI Guidance**:
  - Rule-based suggestions for overexposure, reciprocity failure, and film-type specific behaviors.
  - Returns both human-readable tips and machine-readable suggestion codes.

### 5.4 Lab Import Service

- Accepts shared links to lab scans (Google Drive, Dropbox, or generic URL).
- Downloads and extracts images in a background job.
- Uploads images to object storage and creates `Image` records.
- Attempts to match images to film rolls using naming and metadata hints.

## 6. Cross-Cutting Concerns

### 6.1 Security

- All external calls use HTTPS only.
- Authentication uses Firebase ID tokens.
- All mutations require authenticated user context.
- Authorization is basic per-user ownership (no multi-tenant roles yet).

### 6.2 Error Handling

- REST responses use consistent error envelope:
  - `code`, `message`, `details` (optional).
- GraphQL errors use standard GraphQL error format.
- Sensitive internal details are not exposed in error messages.

### 6.3 Observability

- Structured logging with correlation IDs per request.
- Basic metrics endpoint for health checks.
- Logs include user ID (hashed) and request path for debugging.

## 7. Deployment Overview

- All services are containerized.
- Environments:
  - `dev`: rapid iteration, verbose logs.
  - `staging`: pre-production, mirrors production configuration.
  - `prod`: optimized, monitored, and autoscaled as needed.
- CI/CD pipeline:
  - Lint, tests, build, deploy per branch.

## 8. Architectural Constraints

- Single PostgreSQL instance per environment.
- No direct frontend access to storage buckets; all uploads and presigned URL
  generation go through backend.
- All business logic resides in backend; frontend is a thin client.

## 9. Glossary

- **Locker**: The collection of a user’s cameras and lenses.
- **Roll**: A physical roll of film, mapped to a digital record.
- **Frame**: A single exposure on a roll.
- **Batch**: A lab import job creating multiple `Image` records.
