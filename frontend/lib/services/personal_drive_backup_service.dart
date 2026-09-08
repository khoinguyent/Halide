import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/personal_drive_sync_job.dart';
import 'api_service.dart';

/// On-device record of the last backup attempt for one roll. The backend
/// doesn't expose a per-roll "last archived" field over the API, so the app
/// keeps a small local history to show "backed up 2h ago" style badges and
/// let people pick up where they left off across sessions.
class PersonalDriveBackupRecord {
  final DateTime syncedAt;
  final bool hadError;

  const PersonalDriveBackupRecord({required this.syncedAt, required this.hadError});

  Map<String, dynamic> toJson() => {
        'synced_at': syncedAt.toIso8601String(),
        'had_error': hadError,
      };

  factory PersonalDriveBackupRecord.fromJson(Map<String, dynamic> json) {
    return PersonalDriveBackupRecord(
      syncedAt: DateTime.tryParse(json['synced_at']?.toString() ?? '') ?? DateTime.now(),
      hadError: json['had_error'] == true,
    );
  }
}

/// A previously-started job the user may still be waiting on (e.g. they backed
/// out of the picker while a batch was uploading).
typedef ActivePersonalDriveJob = ({String jobId, List<String> rollIds});

/// Starts and tracks personal Google Drive ("Agxel Vault") backups for rolls.
///
/// The backend processes backups as an async job (`PersonalDriveSyncJob`) so a
/// batch of rolls can sync over time in the background; this service starts
/// jobs, polls their progress, and persists a small history/resume record on
/// device.
class PersonalDriveBackupService {
  final ApiService _api;

  PersonalDriveBackupService({ApiService? api}) : _api = api ?? ApiService();

  static const _historyPrefsKeyPrefix = 'personal_drive_backup_history_v1_';
  static const _activeJobPrefsKeyPrefix = 'personal_drive_backup_active_job_v1_';

  String get _uidOrShared => FirebaseAuth.instance.currentUser?.uid ?? 'shared';

  /// Kicks off (or resumes eligibility for) a batch backup job for [rollIds].
  /// Pass [force] to re-upload frames already mirrored on Drive.
  Future<PersonalDriveSyncJob> startBackup({
    required List<String> rollIds,
    bool force = false,
  }) async {
    final resp = await _api.post(
      '/api/v1/storage/gdrive/sync_rolls_to_personal',
      data: {'roll_ids': rollIds, 'force': force},
    );
    final job = PersonalDriveSyncJob.fromJson(Map<String, dynamic>.from(resp.data as Map));
    await _saveActiveJob(job.id, rollIds);
    return job;
  }

  Future<PersonalDriveSyncJob> fetchJob(String jobId) async {
    final resp = await _api.get('/api/v1/storage/gdrive/personal_sync_jobs/$jobId');
    return PersonalDriveSyncJob.fromJson(Map<String, dynamic>.from(resp.data as Map));
  }

  Future<void> _saveActiveJob(String jobId, List<String> rollIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_activeJobPrefsKeyPrefix$_uidOrShared',
      jsonEncode({'job_id': jobId, 'roll_ids': rollIds}),
    );
  }

  /// Returns an unfinished job started in a previous app session, if any, so
  /// the picker can resume polling instead of losing track of it.
  Future<ActivePersonalDriveJob?> loadActiveJob() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_activeJobPrefsKeyPrefix$_uidOrShared');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final jobId = map['job_id']?.toString();
      if (jobId == null || jobId.isEmpty) return null;
      final rollIds =
          (map['roll_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
      return (jobId: jobId, rollIds: rollIds);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveJob() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_activeJobPrefsKeyPrefix$_uidOrShared');
  }

  Future<Map<String, PersonalDriveBackupRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_historyPrefsKeyPrefix$_uidOrShared');
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, PersonalDriveBackupRecord.fromJson(Map<String, dynamic>.from(v as Map))),
      );
    } catch (_) {
      return {};
    }
  }

  /// Records the outcome of a finished job for every roll that was requested,
  /// so rolls that never made it into `job.result` (e.g. the job errored out
  /// before starting) are still marked as attempted.
  Future<void> recordJobResult(PersonalDriveSyncJob job, List<String> requestedRollIds) async {
    final history = await loadHistory();
    final now = DateTime.now();

    for (final rollId in requestedRollIds) {
      final r = job.resultFor(rollId);
      final hadError = r == null ? true : r.isRollLevelError;
      history[rollId] = PersonalDriveBackupRecord(syncedAt: now, hadError: hadError);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_historyPrefsKeyPrefix$_uidOrShared',
      jsonEncode(history.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
