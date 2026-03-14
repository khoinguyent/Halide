# Sprint 4: Integrations & Professional Profile

Sprint 4 introduces external storage integrations (Cloud/NAS), automated image transfer workflows, and full user profile customization. It also refines the "Add Roll" and "Gear" workflows based on user feedback.

## Backend – BE_DEV_1 (Storage Integrations & Transfer)

### [BE_4.1] External Storage Provider Configuration
- **Status**: DONE
- **Depends On**: [BE_2.1]
- **Assignee**: BE_DEV_1

**Summary**
Implement the configuration logic and OAuth flows for external storage providers including Google Drive, OneDrive, and generic NAS (SMB/FTP) settings.

**Acceptance Criteria**
- Support for storing credentials/tokens for Google Drive and OneDrive.
- Support for NAS configuration (Host, Port, Username, Password, Path).
- Encryption of external credentials at rest in the database.

### [BE_4.2] Cloud-to-Cloud Image Transfer Service
- **Status**: DONE
- **Depends On**: [BE_4.1]
- **Assignee**: BE_DEV_1

**Summary**
Create a service that monitors a "Source" folder on a connected drive and transfers images to the "Halide Archive" folder based on the roll ID.

**Acceptance Criteria**
- Worker process can move files from a designated 'Inbox' folder to organized 'Rolls' folders.
- Supports background syncing for NAS servers.
- Logs transfer successes/failures for user notification.

## Backend – BE_DEV_2 (User Profile & Metadata)

### [BE_4.3] User Profile & Avatar API
- **Status**: TODO
- **Depends On**: [BE_2.1]
- **Assignee**: BE_DEV_2

**Summary**
Implement full profile management including avatar uploads and metadata updates (Name, Professional Nickname, Bio).

**Acceptance Criteria**
- `PATCH /api/v1/user/profile` handles multipart image upload for avatars.
- Avatars are stored in a dedicated `users/{uid}/profile/avatar.jpg` bucket.
- API returns updated profile info including name and nickname.

## Frontend – FE_DEV_1 (Advanced Rolls & Gallery)

### [FE_4.1] "Add New Roll" Modal Enhancement
- **Status**: TODO
- **Depends On**: [FE_3.2]
- **Assignee**: FE_DEV_1

**Summary**
Update the "Add Roll" modal to include a Roll Title/Nickname, a searchable camera list (Format: Nickname - Model), and a description field.

**Acceptance Criteria**
- Input for "Roll Title" (replaces 'Untitled Roll').
- Camera picklist displays as Gear Nickname - Model (e.g., 'Main Shooter - Leica M6').
- Large text field for "Description/Notes".
- Bug Fix: Implement BLoC listener to refresh "THE ARCHIVE" immediately after successful creation (no manual refresh needed).

### [FE_4.2] Scanned Gallery & Image Viewer
- **Status**: TODO
- **Depends On**: [FE_2.2], [BE_2.2]
- **Assignee**: FE_DEV_1

**Summary**
Implement the full gallery view for "SCANNED" rolls and a high-fidelity individual image viewer.

**Acceptance Criteria**
- "Open Gallery" button transitions to a grid view of all images in the roll.
- Tapping an image opens a full-screen viewer with zoom/pan support.
- Displays frame-level metadata (if available) as an overlay in the viewer.

### [FE_4.3] Roll Status Management & Device Upload
- **Status**: TODO
- **Depends On**: [FE_3.1], [BE_2.6]
- **Assignee**: FE_DEV_1

**Summary**
Implement the UI/UX for changing roll statuses (e.g., Shooting -> At Lab) and manual image upload from the mobile device.

**Acceptance Criteria**
- Contextual menu or slider to update roll status.
- "Upload from Device" button for rolls in 'Lab' or 'Scanned' state.
- Visual Fix: "At Lab" status cards no longer show empty image placeholders (cleaner look).

## Frontend – FE_DEV_2 (Gear Management & Legal)

### [FE_4.4] Gear Details & Multi-Image Upload
- **Status**: DONE
- **Depends On**: [FE_3.4]
- **Assignee**: FE_DEV_2

**Summary**
Enhance the "THE GEAR" screen to support gear detail views, updates, and multi-image uploads for each piece of equipment.

**Acceptance Criteria**
- Tapping a gear card opens a detail screen with editable fields.
- Support for uploading/viewing max 3 images per gear item.
- "Add Gear" form updated to include image selection.

### [FE_4.5] Settings: Privacy & Legal Screens
- **Status**: DONE
- **Depends On**: [FE_2.5]
- **Assignee**: FE_DEV_2

**Summary**
Implement the User Privacy and Terms & Conditions screens within the Settings module.

**Acceptance Criteria**
- New routes for `/settings/privacy` and `/settings/terms`.
- Content rendered using the shared Glass styling and typography.
- Links added to the main Profile/Settings tab.
