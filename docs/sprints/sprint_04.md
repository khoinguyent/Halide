# Sprint 04 - External Storage & Archiving

## Backend Tasks (BE_DEV_1)

### [BE_4.1] Storage Configuration
- **Status**: IN_PROGRESS
- **Description**: Implement OAuth flows for Google Drive and OneDrive. Add generic NAS support (SMB/FTP). Ensure all external credentials are encrypted at rest in the database.

### [BE_4.2] Transfer Service
- **Status**: IN_PROGRESS
- **Description**: Create the background worker that monitors 'Inbox' folders on connected drives and organizes them into the 'Halide Archive' based on Roll IDs.
