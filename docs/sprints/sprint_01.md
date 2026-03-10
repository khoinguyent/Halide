# Sprint 01: Cloud Integration & User Authentication
**Goal:** Establish Firebase Auth, Cloud Storage (R2/S3), and the core GraphQL data layer.

---

## 📋 Task Breakdown

### [BE_1.1] Firebase & Environment Initialization
- **Status**: DONE
- **Depends On**: None
- **Assignee**: BE_DEV_1
- **Task**: Initialize Firebase Admin SDK. Setup `.env` validation for `FIREBASE_PROJECT_ID`, `S3_ENDPOINT` (R2), and `S3_ACCESS_KEY`.
- **Safety**: Use `IF NOT EXISTS` logic for any new environment-specific database extensions.

### [BE_1.2] Cloud Storage Service (R2/S3)
- **Status**: DONE
- **Depends On**: [BE_1.1]
- **Assignee**: BE_DEV_1
- **Task**: Implement a `StorageService` using `boto3`. Create the logic for `upload_roll_image`. Ensure it generates unique keys following `users/{uid}/rolls/{roll_id}/{image_id}.jpg`.

### [BE_2.1] Master Film Stock & Gear Query
- **Status**: TODO
- **Depends On**: None
- **Assignee**: BE_DEV_2
- **Task**: Create GraphQL Resolvers for `FilmStocks` (Master List) and `UserGear`. 
- **Safety**: Ensure `FilmStocks` seeding script ignores duplicates if run multiple times.

### [BE_2.2] User Activity Dashboard (GraphQL)
- **Status**: TODO
- **Depends On**: [BE_2.1]
- **Assignee**: BE_DEV_2
- **Task**: Build the `UserDashboard` query. It must return the User profile, their linked `UserCameras`, and the last 30 `Rolls` sorted by `created_at`.

### [FE_1.1] Firebase Auth & Social Logic
- **Status**: TODO
- **Depends On**: None
- **Assignee**: FE_DEV_1
- **Task**: Implement full Firebase Auth UI. Support: 1. Email/Pass (Sign up/Forgot), 2. Google, 3. Facebook, 4. Apple ID.
- **Safety**: Ensure the Firebase UID is passed to the Backend to sync with the `Users` table.

### [FE_2.1] Roll State Management
- **Status**: TODO
- **Depends On**: None
- **Assignee**: FE_DEV_2
- **Task**: Build the UI/State logic for changing a Roll's status (e.g., 'Shooting' -> 'At Lab'). Implement a bottom-sheet selector for status updates.

### [FE_2.2] Multi-Image Roll Uploader
- **Status**: TODO
- **Depends On**: [BE_1.2]
- **Assignee**: FE_DEV_2
- **Task**: Create the "Add Images" interface. Allow selecting multiple files from the gallery and piping them to the Backend `upload_roll_image` endpoint.