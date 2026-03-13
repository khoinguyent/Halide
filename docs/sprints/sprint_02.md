Sprint 2 should deepen the core flows already started: gear/roll CRUD + film stocks on the backend, and Locker/Rolls UI + login wiring on the frontend.

Backend – BE_DEV_1 (Infra & Storage / Auth)
[BE_2.1] Backend structure refactor
Status: IN_PROGRESS

Depends On: [BE_1.1]

Assignee: BE_DEV_1

Summary
Refactor existing backend files into the app/core, app/db, app/api/v1, app/services, and app/graphql layout so later work is consistent.

Acceptance Criteria

No business logic remains in top-level backend/*.py files (except entry main.py).

New packages exist: app/core, app/db/models, app/db/schemas, app/api/v1, app/services, app/graphql.

All existing tests and endpoints still work.

[BE_2.2] StorageService REST endpoint
Status: IN_PROGRESS

Depends On: [BE_1.2]

Assignee: BE_DEV_1

Summary
Expose the storage upload logic via a REST endpoint so the frontend’s multi-image uploader can call it.

Acceptance Criteria

New endpoint POST /api/v1/rolls/{roll_id}/images accepts multiple files.

Uses StorageService.upload_roll_image() with key pattern users/{uid}/rolls/{roll_id}/{image_id}.jpg.
​

Returns Image JSON objects per upload.

Validates ownership of roll_id by current user; unauthorized access returns 403.

[BE_2.3] Firebase-based auth integration layer
Status: IN_PROGRESS

Depends On: [BE_1.1], [BE_2.1]

Assignee: BE_DEV_1

Summary
Bridge Firebase Auth to the existing JWT/user system so the Flutter app can log in via Firebase but backend still has a User row.

Acceptance Criteria

core/security.py exposes get_current_user() that verifies Firebase ID token and loads/creates User.

Existing /rolls and storage endpoints require this dependency instead of custom JWT from Sprint 00.
​

Errors on invalid/expired tokens follow the standard error envelope.

Backend – BE_DEV_2 (Domain & GraphQL)
[BE_2.4] Film stock & gear GraphQL alignment
Status: TODO

Depends On: [BE_2.1 (Sprint1)], [BE_2.1 (Sprint2)]

Assignee: BE_DEV_2

Summary
Refine FilmStocks and UserGear GraphQL queries to match the REST data models and new backend structure.

Acceptance Criteria

GraphQL types defined in graphql/types.py for FilmStock, Camera, Roll.

Resolvers in graphql/resolvers/film_stock_resolvers.py and gear_resolvers.py call services, not raw DB.

FilmStocks query returns seeded list; UserGear returns current user’s cameras/lenses.
​

Schema matches shapes in backend_api.md.

[BE_2.5] UserDashboard service + API
Status: TODO

Depends On: [BE_2.4]

Assignee: BE_DEV_2

Summary
Finalize the UserDashboard GraphQL query and expose an equivalent REST endpoint for the mobile home/dashboard.

Acceptance Criteria

Service dashboard_service.py computes:

User profile.

User cameras.

Last 30 rolls sorted by created_at.
​

GraphQL query userDashboard returns this shape.

REST endpoint GET /api/v1/dashboard returns the same JSON structure.

Tests cover roll ordering and ownership filtering.

[BE_2.6] Film roll status transitions
Status: TODO

Depends On: [BE_DEV_2 tasks from Sprint 00]

Assignee: BE_DEV_2

Summary
Implement robust roll status transitions to support the frontend bottom-sheet status selector.

Acceptance Criteria

Roll model supports statuses: loaded, shooting, lab, scanned, archived.

Endpoint PATCH /api/v1/rolls/{id}/status updates status with validation (no illegal jumps, e.g. archived → shooting).

Errors use clear codes (e.g. invalid_status_transition).

GraphQL reflects the same status values.

[FE_2.1] MainShell + Bottom Nav (Glass Dock)
Status: TODO

Depends On: [FE_1.1], [BE_2.3]

Assignee: FE_DEV_1

Summary

Implement the post-login shell that matches the HTML prototype: full-screen photo background, glass bottom navigation dock (Locker, Rolls, Meter, Profile), and central FAB reserved for frame logging.

Acceptance Criteria

MainShell uses HalideScaffold background and places:

Glass bottom nav bar with 4 items: Locker, Rolls, Meter, Profile.

Center-aligned circular FAB above the dock, visually similar to the prototype (glass circle with camera icon).

Switching tabs preserves each tab’s scroll/Bloc state.

FAB is visible on all tabs but currently triggers a simple “Log frame” placeholder action (toast/dialog).

[FE_2.2] Rolls Home Screen – “Your Rolls” Layout
Status: TODO

Depends On: [FE_2.1], [BE_2.5], [BE_2.6]

Assignee: FE_DEV_2

Summary

Create the Rolls tab main screen that matches the provided HTML mock: “Your Rolls” title, vertical list of glass cards representing rolls, including the “Scanned with gallery strip”, “Shooting with progress bar”, and “At Lab with skeleton thumbnails” styles.

Acceptance Criteria

When the Rolls tab is active, the top of the content shows the title Your Rolls with light, large typography.

Each roll is rendered as a glass card using shared GlassPanel:

Top row: colored status badge (Shooting, At Lab, Scanned, Archived) and small timestamp.

Main title: film stock name; subtitle: roll nickname and camera/lens line.

For rolls with status = scanned:

Card includes horizontal image strip (thumbnails) and an “Open Gallery” text button at the bottom as in the prototype.

For rolls with status = shooting:

Card includes a progress bar and frame count text (Frame X/36 and percentage).

For rolls with status = lab:

Card shows 2–3 pulsing skeleton blocks in place of images.

Layout uses the same spacing, fonts, and glass styling as the HTML prototype (no divergent card styles).

[FE_2.3] Rolls Tab BLoC + Dashboard Integration
Status: TODO

Depends On: [FE_2.2], [BE_2.5]

Assignee: FE_DEV_2

Summary

Wire the Rolls home screen to a RollsHomeBloc that loads data from the /dashboard or UserDashboard GraphQL endpoint, mapping backend roll status and metadata into the visual states used by the prototype.

Acceptance Criteria

RollsHomeBloc states: Loading, Loaded { rolls }, Error.

On entering the Rolls tab the first time, the BLoC loads data from backend:

Last 30 rolls with status and created/updated timestamps.

Enough metadata to render badges, names, nicknames, camera/lens summary, and frame counts.

Error state shows a glass card with an inline error message and retry button.

Empty state (no rolls) shows a glass card explaining what rolls are and a CTA button “Add first roll”, positioned where the first card would be.

[FE_2.4] FAB → Frame Logging Hook (Prototype-level)
Status: TODO

Depends On: [FE_2.1], [BE_2.6]

Assignee: FE_DEV_1

Summary

Connect the central glass FAB to a simple “Log Frame” interaction similar to the prototype toast: when tapped from the Rolls tab, it should confirm a frame was logged against the active “shooting” roll (or show a helpful error if none).

Acceptance Criteria

From Rolls tab:

Tapping FAB dispatches a BLoC event (e.g. LogQuickFrame) on the rolls/frames BLoC.

On success, a transient overlay/toast appears (“✨ Logged Frame N to '<roll name>'”) styled as a small glass pill above the dock, like the HTML prototype.

The shooting roll’s progress bar increments accordingly.

If no roll is currently in shooting state:

Toast shows a friendly message (“No active roll. Start a new roll to log frames.”).

On other tabs, FAB can still show the toast or remain a no-op for now, but MUST preserve visual consistency with Rolls tab.

[FE_2.5] Locker & Other Tabs Placeholder with Prototype Style
Status: TODO

Depends On: [FE_2.1]

Assignee: FE_DEV_2

Summary

Implement minimal Locker/Meter/Profile content so that switching tabs keeps the overall aesthetic consistent with the Rolls prototype (glass cards, “coming soon” messages), using the same layout primitives.

Acceptance Criteria

Locker tab:

Shows title Your Locker and at least two glass cards with sample camera entries styled similarly to the Locker view in the HTML (nickname label, camera name, serial line).

Meter and Profile tabs:

Show title and a central glass panel with “Coming soon” text, using the same typography and glass styling as other cards.

All tabs sit inside HalideScaffold background and share the same padding/top spacing as the Rolls screen.