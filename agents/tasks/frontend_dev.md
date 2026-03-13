# Halide – Frontend Developer Agent Specification (Flutter + BLoC)

## 1. Purpose

Frontend Developer agents implement and maintain the Halide Flutter client for
iOS, Android, and Web using the BLoC state management pattern.

Frontend agents MUST:
- Implement screens, navigation, and state as defined in
  `docs/specs/frontend_ui.md`.
- Integrate correctly with backend APIs defined in `docs/specs/backend_api.md`.
- Follow architecture decisions in `docs/decisions/*.md`.

Frontend agents MUST NOT:
- Modify backend code in `backend/`.
- Change orchestrator or agent specs under `agents/` (unless explicitly asked).
- Override ADRs; they may only follow them.

---

## 2. Files Frontend Agents Read

Frontend agents may READ:

- `docs/specs/frontend_ui.md`
- `docs/specs/backend_api.md`
- `docs/specs/system_architecture.md`
- `docs/sprints/<current_sprint>.md`
- `docs/decisions/*.md` (ADRs)
- `project_manifest.json`
- Existing Flutter code and tests under `frontend/`

Agents should always read relevant specs before changing behavior.

---

## 3. Files Frontend Agents Write

Frontend agents may WRITE or UPDATE:

- Flutter source code:
  - `frontend/lib/app/*`
  - `frontend/lib/features/*`
  - `frontend/lib/services/*`
  - `frontend/lib/bloc/*` or `frontend/lib/features/**/bloc/*`
- Flutter tests:
  - `frontend/test/*`
- Frontend documentation when needed:
  - Sections of `docs/specs/frontend_ui.md` describing new screens/flows that
    are requested in sprint tasks.

Frontend agents MUST NOT modify:

- `backend/` directory.
- `docs/decisions/*.md` contents (except trivial typo fixes if instructed).
- Orchestrator code or other agent specs.

---

### 4. Flutter Project Structure

The Halide Flutter project uses a feature-first architecture with BLoC:

```text
frontend/
  lib/
    app/
      app.dart          # Root app
      router.dart       # GoRouter / Navigator 2.0
      theme.dart
      di.dart           # Dependency injection / BLoC providers
    core/
      widgets/          # Shared UI components
      util/             # Helpers (formatting, extensions)
      error/            # Error mapping & handling
    features/
      auth/
        bloc/
        models/
        screens/
        widgets/
      locker/
        bloc/
        models/
        screens/
        widgets/
      rolls/
        bloc/
        models/
        screens/
        widgets/
      meter/
        bloc/
        models/
        screens/
        widgets/
      lab_import/
        bloc/
        models/
        screens/
        widgets/
      gallery/
        bloc/
        models/
        screens/
        widgets/
      settings/
        bloc/
        models/
        screens/
        widgets/
    services/
      api/
        rest_client.dart
        graphql_client.dart
      auth/
        firebase_auth_service.dart
      storage/
        image_url_service.dart
  test/
    features/
    widgets/
    integration/
```

Rules:

- **Each feature has its own bloc/ folder** containing:
  - `*_event.dart`
  - `*_state.dart`
  - `*_bloc.dart`
- **UI screens depend on BLoC classes**, not directly on services.
- **Services (API, auth, storage) are injected** into BLoCs via constructors or a simple DI layer.

## 5. State Management Pattern (BLoC)

### 5.1 General Rules
- **Each feature BLoC**:
  - Exposes a sealed State type capturing loading, success, and error states.
  - Handles user actions as Event types.
  - Calls services for networking and maps results to states.
- **Widgets**:
  - Listen to BLoC state using `BlocBuilder`, `BlocConsumer`, or similar.
  - Dispatch events on user interaction.

### 5.2 BLoC Structure Example
```text
features/rolls/bloc/
  roll_list_event.dart
  roll_list_state.dart
  roll_list_bloc.dart
```

**RollListEvent examples:**
- `RollListStarted({RollStatus? statusFilter})`
- `RollListRefreshed()`

**RollListState examples:**
- `RollListInitial`
- `RollListLoading`
- `RollListLoaded { List<Roll> rolls }`
- `RollListError { String message }`

BLoC must call the REST/GraphQL APIs defined in `backend_api.md` and handle errors consistently (e.g. map known error codes to friendly messages).

## 6. Networking and Auth Integration

### 6.1 Auth
- Use `firebase_auth` SDK for Google/Apple/Facebook login.
- On successful login:
  - Obtain Firebase ID token.
  - Store token in an auth BLoC or secure storage layer.
  - Provide token to all API clients (REST and GraphQL) as `Authorization: Bearer <token>`.

### 6.2 API Clients
- **REST client**:
  - Wraps http/dio or similar, adding:
    - Base URL.
    - Auth header injection.
    - Error mapping into a common `ApiError` type.
- **GraphQL client**:
  - Configured for `/graphql` endpoint.
  - Uses the same auth token injection.

BLoCs never construct raw HTTP requests; they call service abstractions in `services/api/`. Services are responsible for mapping backend responses (`backend_api.md`) into Dart models.

## 7. Working from Sprint Tasks

Frontend agents MUST obey sprint tasks defined in `docs/sprints/<sprint>.md`.

For each task assigned to a frontend role:

1. **Locate the task block**:
   ```text
   ### [FE1-001] Short title
   - **Status**: TODO
   - **Depends On**: [BE2-001]
   - **Assignee**: FE1
   ```

2. **Respect dependencies**: Do not start tasks whose backend dependencies are not **DONE** yet (unless task explicitly allows mocking).

3. **Implementation steps** for a typical frontend task:
   - Read relevant sections in `frontend_ui.md` and `backend_api.md`.
   - Identify target feature folder and any new screens/BLoCs required.
   - Implement UI widgets and screens as described in **Summary**.
   - Implement or update appropriate BLoC(s) to interact with backend APIs.
   - Wire navigation and connect screens to BLoCs.
   - Add or update tests as appropriate.
   - Update the sprint file in your own worktree to change **Status** from **TODO** → **IN_PROGRESS** → **DONE**.

4. **Commit changes** with message including the task ID, e.g.:
   `feat: [FE1-001] implement login screen and auth bloc.`

Frontend agents do not add or remove tasks unless explicitly instructed.

## 8. Screen & UX Guidelines

Screens and flows must align with `frontend_ui.md`:
- Routes, screen names, and main widgets should match that spec.
- **Loading states**: Use progress indicators or skeletons while BLoC is in a loading state.
- **Error states**: Show snackbars, banners, or inline messages for errors surfaced by BLoC.
- **Accessibility**: Use semantic widgets and adequate tap targets where possible.
- **Web support**:
  - Avoid using mobile-only plugins without guarding web platforms.
  - Degrade gracefully for features that require camera access.

## 9. Specific Feature Guidelines

### 9.1 Auth Feature
Implement `AuthBloc` which:
- Reacts to events: `AuthStarted`, `AuthLoginRequested`, `AuthLogoutRequested`.
- Manages states: `AuthInitial`, `AuthLoading`, `AuthAuthenticated`, `AuthUnauthenticated`, `AuthFailure`.
- On startup: Check persisted session and emit appropriate state.
- On login: Use FirebaseAuth to sign in; obtain ID token and notify API clients.

### 9.2 Locker (Gear) Feature
`LockerBloc` handles fetching cameras and lenses via API:
- Uses endpoints from `backend_api.md` (`/cameras`, `/lenses` or GraphQL).
- **UI**:
  - Locker tab shows gear lists.
  - Forms use BLoC events for create/update/delete operations.

### 9.3 Rolls and Frames Feature
- **RollListBloc + RollDetailBloc**:
  - Fetch rolls with filters (Active / In Lab / Archived).
  - Fetch roll detail including frames and images.
- **FrameFormBloc**:
  - Handles creation of new frames.
  - Can consume suggested exposure from Meter BLoC when available.

### 9.4 Meter Feature
- **MeterBloc**:
  - Manages EV input, selected priority mode, and film settings.
  - Calls `/api/v1/meter/calc` and `/api/v1/meter/advice`.
  - Exposes resulting exposure and AI tips to UI.
- **Optional integration with device camera**:
  - Only when platform supports camera plugin; guard web.

### 9.5 Lab Import and Gallery Feature
- **LabImportBloc**:
  - Creates new lab import batches via `/api/v1/lab-imports`.
  - Polls status endpoint and updates state.
- **GalleryBloc (or simple provider)**:
  - Fetches images per roll.
  - Manages selected image for detail view.

## 10. Testing Guidelines

- **Unit tests**: For each BLoC, test transitions for main `event → state` flows.
- **Widget tests**: For critical screens (e.g. login, roll list, roll detail), ensure UI reacts correctly to BLoC states.
- **Integration tests** (optional for now): End-to-end flows such as `login → create camera → create roll`.

Tests should not hit real backend services; they should mock API service interfaces.

## 11. Interaction with Other Agents

### 11.1 Scrum Master Agent
- Provides sprint tasks and clarifies blockers.
- Frontend agents report progress by updating task Status in sprint files.

### 11.2 Spec Validator Agent
- Ensures `frontend_ui.md` and sprint tasks are clear and consistent.
- Frontend agents should not silently diverge from validated specs.

### 11.3 Backend Agents
- Provide and maintain API endpoints.
- Frontend agents must not change expectations on APIs without a corresponding update to `backend_api.md` and sprint tasks.

## 12. Changelog

- **v1.0** – Initial definition of Frontend Developer Agent behavior for Halide using Flutter and BLoC.