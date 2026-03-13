# Sprint 2: Core Flows & Refinement

Sprint 2 focuses on establishing the modular backend structure, bridging Firebase Auth, and implementing the high-fidelity "Glassmorphism" UI for the Locker and Rolls screens.

## Backend – BE_DEV_1 (Infra & Storage / Auth)

### [BE_2.1] Backend structure refactor
- **Status**: TODO
- **Depends On**: [BE_1.1]
- **Assignee**: BE_DEV_1

**Summary**
Refactor existing backend files into the modular layout defined in `backend_structure.md`. Move logic into `app/core`, `app/db`, `app/api/v1`, and `app/services`.

**Acceptance Criteria**
- No business logic remains in top-level `backend/*.py` files.
- Packages created: `app/core`, `app/db/models`, `app/db/schemas`, `app/api/v1`, `app/services`, `app/graphql`.
- All existing tests pass after the move.

### [BE_2.2] StorageService REST endpoint
- **Status**: TODO
- **Depends On**: [BE_1.2]
- **Assignee**: BE_DEV_1

**Summary**
Expose storage upload logic via REST for the frontend multi-image uploader.

**Acceptance Criteria**
- `POST /api/v1/rolls/{roll_id}/images` accepts multiple multipart files.
- Uses path pattern: `users/{uid}/rolls/{roll_id}/{image_id}.jpg`.
- Validates roll ownership; unauthorized access returns 403.

### [BE_2.3] Firebase Auth Integration
- **Status**: TODO
- **Depends On**: [BE_1.1], [BE_2.1]
- **Assignee**: BE_DEV_1

**Summary**
Bridge Firebase Auth to the internal User system via JWT verification in `core/security.py`.

**Acceptance Criteria**
- `core/security.py` implements `get_current_user()` using Firebase Admin SDK.
- Syncs/Creates a local `User` row on first successful login.
- Middleware rejects requests with invalid or missing Bearer tokens.

## Backend – BE_DEV_2 (Domain & GraphQL)

### [BE_2.4] Film Stock & Gear GraphQL Alignment
- **Status**: TODO
- **Depends On**: [BE_2.1]
- **Assignee**: BE_DEV_2

**Summary**
Refine GraphQL queries to match the REST models and include the new `nickname` requirement for gear and rolls.

**Acceptance Criteria**
- GraphQL types in `graphql/types.py` include `nickname` for Camera and Roll.
- Resolvers call the service layer, not raw DB sessions.

### [BE_2.5] User Dashboard Service + API
- **Status**: TODO
- **Depends On**: [BE_2.4]
- **Assignee**: BE_DEV_2

**Summary**
Create the unified dashboard data provider for the mobile home screen.

**Acceptance Criteria**
- `dashboard_service.py` returns: User profile, linked cameras, and last 30 rolls.
- Rolls must include `gear_nickname` and `status`.
- REST `GET /api/v1/dashboard` and GQL `userDashboard` both implemented.

### [BE_2.6] Film roll status transitions
- **Status**: TODO
- **Depends On**: [BE_2.1]
- **Assignee**: BE_DEV_2

**Summary**
Implement strict logic for roll states: loaded, shooting, lab, scanned, archived.

**Acceptance Criteria**
- `PATCH /api/v1/rolls/{id}/status` validates transitions (e.g., cannot move from 'archived' back to 'shooting').
- Error code `invalid_status_transition` returned on failure.

## Frontend – FE_DEV_1 (Architecture & Navigation)

### [FE_2.1] MainShell + Bottom Nav (Glass Dock)
- **Status**: TODO
- **Depends On**: [FE_1.1], [BE_2.3]
- **Assignee**: FE_DEV_1

**Summary**
Implement the post-login shell with the glass bottom navigation dock exactly as defined in the UI prototype.

**Acceptance Criteria**
- `MainShell` implements the 4 tabs: Locker, Rolls, Meter, Profile.
- Central Glass FAB implemented above the dock.
- `HalideScaffold` used for background photo and blur consistency.

### [FE_2.4] FAB -> Frame Logging Hook
- **Status**: TODO
- **Depends On**: [FE_2.1], [BE_2.6]
- **Assignee**: FE_DEV_1

**Summary**
Connect the central FAB to a quick-log interaction that increments the frame count of the current shooting roll.

**Acceptance Criteria**
- Tapping FAB dispatches `LogQuickFrame` event.
- Displays a glass toast overlay: “✨ Logged Frame N to '[Nickname]'”.

## Frontend – FE_DEV_2 (UI & Dashboard)

### [FE_2.2] Rolls Home Screen Layout
- **Status**: TODO
- **Depends On**: [FE_2.1], [BE_2.5]
- **Assignee**: FE_DEV_2

**Summary**
Create the "Your Rolls" screen using dynamic glass cards that reflect roll lifecycle states.

**Acceptance Criteria**
- All cards display the `gear_nickname` prominently.
- Status 'Scanned' shows a horizontal image strip preview of thumbnails.
- Status 'Shooting' shows a progress bar and frame count.

### [FE_2.3] Rolls Tab BLoC Integration
- **Status**: TODO
- **Depends On**: [FE_2.2], [BE_2.5]
- **Assignee**: FE_DEV_2

**Summary**
Wire the Rolls UI to the Dashboard API using the BLoC pattern for state management.

**Acceptance Criteria**
- `RollsHomeBloc` handles Loading, Loaded, and Error states.
- Empty state shows "Add first roll" glass card CTA.

### [FE_2.5] Locker & Tab Placeholders
- **Status**: TODO
- **Depends On**: [FE_2.1]
- **Assignee**: FE_DEV_2

**Summary**
Implement placeholder content for Locker, Meter, and Profile tabs using the shared glass design tokens.

**Acceptance Criteria**
- Locker tab displays cards for saved gear including their nicknames.
- Meter and Profile show "Coming Soon" panels in the translucent glass style.