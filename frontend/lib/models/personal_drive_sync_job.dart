/// Mirrors the backend's `PersonalDriveSyncJob` (see
/// `backend/app/db/models/personal_drive_sync.py`), returned by
/// `POST /api/v1/storage/gdrive/sync_rolls_to_personal` and
/// `GET /api/v1/storage/gdrive/personal_sync_jobs/{job_id}`.
enum PersonalDriveSyncJobStatus { queued, running, succeeded, failed, partial, unknown }

PersonalDriveSyncJobStatus personalDriveSyncJobStatusFromString(String? raw) {
  switch (raw) {
    case 'queued':
      return PersonalDriveSyncJobStatus.queued;
    case 'running':
      return PersonalDriveSyncJobStatus.running;
    case 'succeeded':
      return PersonalDriveSyncJobStatus.succeeded;
    case 'failed':
      return PersonalDriveSyncJobStatus.failed;
    case 'partial':
      return PersonalDriveSyncJobStatus.partial;
    default:
      return PersonalDriveSyncJobStatus.unknown;
  }
}

/// Outcome for a single roll within a job's `result` list. The backend emits either:
/// - `{roll_id, uploaded, skipped, failed, errors}` when the roll's sync ran, or
/// - `{roll_id, error}` when the whole roll failed before/without uploading anything.
class PersonalDriveRollSyncResult {
  final String rollId;
  final int uploaded;
  final int skipped;
  final int failed;
  final List<String> errors;
  final String? error;

  const PersonalDriveRollSyncResult({
    required this.rollId,
    this.uploaded = 0,
    this.skipped = 0,
    this.failed = 0,
    this.errors = const [],
    this.error,
  });

  /// Whole-roll failure (e.g. roll not found, Drive auth error) rather than a
  /// partial per-frame failure inside an otherwise-successful roll sync.
  bool get isRollLevelError => (error ?? '').trim().isNotEmpty;

  factory PersonalDriveRollSyncResult.fromJson(Map<String, dynamic> json) {
    return PersonalDriveRollSyncResult(
      rollId: (json['roll_id'] ?? '').toString(),
      uploaded: (json['uploaded'] as int?) ?? 0,
      skipped: (json['skipped'] as int?) ?? 0,
      failed: (json['failed'] as int?) ?? 0,
      errors: (json['errors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      error: json['error']?.toString(),
    );
  }
}

class PersonalDriveSyncJob {
  final String id;
  final PersonalDriveSyncJobStatus status;
  final int totalRolls;
  final int completedRolls;
  final int failedRolls;
  final int skippedRolls;
  final List<PersonalDriveRollSyncResult> result;
  final String? error;

  const PersonalDriveSyncJob({
    required this.id,
    required this.status,
    this.totalRolls = 0,
    this.completedRolls = 0,
    this.failedRolls = 0,
    this.skippedRolls = 0,
    this.result = const [],
    this.error,
  });

  bool get isFinished =>
      status == PersonalDriveSyncJobStatus.succeeded ||
      status == PersonalDriveSyncJobStatus.failed ||
      status == PersonalDriveSyncJobStatus.partial;

  int get processedRolls => completedRolls + failedRolls;

  PersonalDriveRollSyncResult? resultFor(String rollId) {
    for (final r in result) {
      if (r.rollId == rollId) return r;
    }
    return null;
  }

  factory PersonalDriveSyncJob.fromJson(Map<String, dynamic> json) {
    return PersonalDriveSyncJob(
      id: (json['id'] ?? '').toString(),
      status: personalDriveSyncJobStatusFromString(json['status'] as String?),
      totalRolls: (json['total_rolls'] as int?) ?? 0,
      completedRolls: (json['completed_rolls'] as int?) ?? 0,
      failedRolls: (json['failed_rolls'] as int?) ?? 0,
      skippedRolls: (json['skipped_rolls'] as int?) ?? 0,
      result: (json['result'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => PersonalDriveRollSyncResult.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      error: json['error']?.toString(),
    );
  }
}
