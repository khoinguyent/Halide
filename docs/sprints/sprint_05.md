# Sprint 5: Storage Orchestration & Hybrid Archiving

Sprint 5 focuses on giving users total control over their data residency. It implements the multi-account "Primary" logic, introduces a "Local-First" storage strategy, and completes the professional profile customization suite.

## Backend – BE_DEV_1 (Storage Logic & Routing)

### [BE_5.1] Multi-Instance Storage Schema
- **Status**: DONE
- **Depends On**: [BE_4.1]
- **Assignee**: BE_DEV_1

**Summary**
Update the PostgreSQL schema to allow multiple instances of the same provider (e.g., two Google Drive accounts). Add `display_label` and `is_primary` fields to the storage configuration table.

**Acceptance Criteria**
- Database allows multiple rows for the same provider_type per user.
- Logic ensures exactly one configuration is marked `is_primary: true` per user.
- API endpoints updated to handle labeling (e.g., "Work Archive").

### [BE_5.2] Routing Engine: Cloud vs. Local vs. System
- **Status**: DONE
- **Depends On**: [BE_4.2]
- **Assignee**: BE_DEV_1

**Summary**
Modify the Transfer Service to check the user's `storage_strategy` before processing uploads, supporting three distinct paths: Local, Personal Cloud, and System Cloud.

**Acceptance Criteria**
- If strategy is `PERSONAL_CLOUD`, images are routed to the provider marked `is_primary`.
- If strategy is `LOCAL`, the backend only stores metadata and thumbnails.
- If strategy is `SYSTEM_CLOUD`, images are routed to the managed Halide S3 bucket (requires active subscription).

### [BE_5.3] Managed "System Cloud" Storage Provider
- **Status**: DONE
- **Depends On**: [BE_4.3]
- **Assignee**: BE_DEV_1

**Summary**
Implement the internal storage provider for the System Cloud tier, including subscription verification and quota management.

**Acceptance Criteria**
- Logic to verify user's active \"Pro\" subscription before allowing uploads to System Cloud.
- Quota tracking system to monitor storage usage (e.g., 500GB/1TB tiers).
- Secure signed-URL generation for high-res downloads from the managed bucket.

## Frontend – FE_DEV_1 (Storage UX)

### [FE_5.1] Multi-Account Management & Primary Toggle
- **Status**: DONE
- **Depends On**: [FE_4.5]
- **Assignee**: FE_DEV_1

**Summary**
Implement the UI for managing multiple accounts and setting a Primary destination.

**Acceptance Criteria**
- List view showing multiple drives with account-specific labels and emails.
- Visual \"Primary\" badge on the active drive.
- \"Set as Primary\" interaction that triggers an atomic update in the UI.

### [FE_5.2] Storage Tier Selector (Local / Personal / System)
- **Status**: DONE
- **Depends On**: [FE_5.1]
- **Assignee**: FE_DEV_1

**Summary**
Implement a premium UI/UX for selecting the primary storage strategy with a three-tier approach.

**Acceptance Criteria**
- Three-way selector: \"Local Device\" (Free), \"Personal Cloud\" (Connect your own), \"System Cloud\" (Subscription).
- Integrated \"Pro\" upgrade prompt for users selecting System Cloud without an active sub.
- Detailed comparison table/tooltip explaining reliability and cost for each tier.

## Frontend – FE_DEV_2 (Local Archiving & Profile)

### [FE_5.3] Local Device Storage Handler
- **Status**: DONE
- **Depends On**: [FE_4.3]
- **Assignee**: FE_DEV_2

**Summary**
Implement the Flutter logic for saving scanned rolls directly to the mobile device's file system (Gallery or App Documents) when LOCAL mode is active.

**Acceptance Criteria**
- Integration with `path_provider` to manage local directories.
- Disk space check before initiating large roll imports.
- \"Move to Cloud\" option for individual rolls even if global strategy is LOCAL.

### [FE_5.4] Profile Customization & Avatar Upload
- **Status**: DONE
- **Depends On**: [FE_4.5], [BE_4.3]
- **Assignee**: FE_DEV_2

**Summary**
Implement the frontend interface for editing user metadata and handling the avatar upload workflow.

**Acceptance Criteria**
- Edit screen for Name, Professional Nickname, and Photography Bio.
- Image picker integration for avatar selection.
- Multi-part form-data integration with `PATCH /api/v1/user/profile`.
- Visual feedback (progress bar/spinner) during image upload to S3.

### [FE_5.5] Unified Image Source Resolver & Cache
- **Status**: DONE
- **Depends On**: [FE_5.2], [FE_5.3]
- **Assignee**: FE_DEV_2

**Summary**
Create a unified image widget/provider that dynamically resolves image sources across the entire app (Rolls, Gear, Profile) based on the current storage strategy and local availability.

**Acceptance Criteria**
- Implement `HalideImageProvider` to prioritize local filesystem paths if `storage_strategy == LOCAL`.
- Automatic fallback to Network/Cloud URL if the local file is missing or `storage_strategy` is `PERSONAL_CLOUD` / `SYSTEM_CLOUD`.
- Integrated cache management to prevent redundant downloads of high-res previews.
- Support for \"Offline\" badges on image thumbnails when viewing locally stored assets.