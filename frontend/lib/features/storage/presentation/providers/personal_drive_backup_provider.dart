import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/personal_drive_sync_job.dart';
import '../../../../models/roll.dart';
import '../../../../models/user_profile.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../services/free_personal_drive_backup_service.dart';
import '../../../../services/google_drive_device_client.dart';
import '../../../../services/personal_drive_backup_service.dart';

/// UI-facing phase for one roll within the picker, derived from the active job
/// (if any) plus on-device history for rolls that were backed up previously.
enum RollBackupPhase { idle, uploading, done, error }

class PersonalDriveBackupState {
  final Set<String> selectedRollIds;
  final PersonalDriveSyncJob? activeJob;
  final List<String> activeJobRollIds;
  final bool isStarting;
  final bool isResuming;
  final Map<String, PersonalDriveBackupRecord> history;
  final String? errorMessage;
  /// Free-tier device backup: which roll is currently uploading.
  final String? freeUploadingRollId;
  final Map<String, FreePersonalDriveRollBackupResult> freeResults;
  /// Frame-level progress within the current free roll upload.
  final int freeFrameDone;
  final int freeFrameTotal;
  /// Set when Google Drive needs a reconnect (stale scopes / 403).
  final bool needsDriveReauth;
  /// Roll ids to retry after a successful Drive reconnect.
  final List<String> pendingReauthRollIds;

  const PersonalDriveBackupState({
    this.selectedRollIds = const {},
    this.activeJob,
    this.activeJobRollIds = const [],
    this.isStarting = false,
    this.isResuming = true,
    this.history = const {},
    this.errorMessage,
    this.freeUploadingRollId,
    this.freeResults = const {},
    this.freeFrameDone = 0,
    this.freeFrameTotal = 0,
    this.needsDriveReauth = false,
    this.pendingReauthRollIds = const [],
  });

  bool get isRunning {
    if (freeUploadingRollId != null) return true;
    return activeJob != null && !activeJob!.isFinished;
  }

  /// 0–1 overall progress for the banner. Null = indeterminate animation.
  double? get bannerProgress {
    final rollTotal = activeJobRollIds.isNotEmpty
        ? activeJobRollIds.length
        : (activeJob?.totalRolls ?? 0);
    if (rollTotal <= 0) return null;

    // Free path: completed rolls + in-progress frame fraction.
    if (freeUploadingRollId != null ||
        (freeResults.isNotEmpty && activeJob == null)) {
      final completed = freeResults.length;
      final frameFrac = (freeFrameTotal > 0)
          ? (freeFrameDone / freeFrameTotal).clamp(0.0, 1.0)
          : 0.0;
      final inFlight = freeUploadingRollId != null ? frameFrac : 0.0;
      final value = ((completed + inFlight) / rollTotal).clamp(0.0, 1.0);
      // Still starting folder/README — keep bar moving.
      if (value <= 0 && isRunning) return null;
      return value;
    }

    final job = activeJob;
    if (job != null) {
      final processed = job.processedRolls;
      final total = job.totalRolls == 0 ? rollTotal : job.totalRolls;
      if (total <= 0) return null;
      final value = (processed / total).clamp(0.0, 1.0);
      if (value <= 0 && isRunning) return null;
      return value;
    }
    return isRunning ? null : null;
  }

  RollBackupPhase phaseFor(String rollId) {
    if (freeUploadingRollId == rollId) return RollBackupPhase.uploading;
    final freeResult = freeResults[rollId];
    if (freeResult != null) {
      return freeResult.isRollLevelError ? RollBackupPhase.error : RollBackupPhase.done;
    }

    final job = activeJob;
    if (job != null && activeJobRollIds.contains(rollId)) {
      final result = job.resultFor(rollId);
      if (result == null) {
        return job.isFinished ? RollBackupPhase.error : RollBackupPhase.uploading;
      }
      return result.isRollLevelError ? RollBackupPhase.error : RollBackupPhase.done;
    }
    final record = history[rollId];
    if (record == null) return RollBackupPhase.idle;
    return record.hadError ? RollBackupPhase.error : RollBackupPhase.done;
  }

  DateTime? lastSyncedAtFor(String rollId) => history[rollId]?.syncedAt;

  String? errorDetailFor(String rollId) {
    final free = freeResults[rollId];
    if (free != null) {
      if ((free.error ?? '').isNotEmpty) return free.error;
      if (free.errors.isNotEmpty) return free.errors.first;
    }
    final job = activeJob;
    if (job != null) {
      final r = job.resultFor(rollId);
      if (r != null) {
        if ((r.error ?? '').isNotEmpty) return r.error;
        if (r.errors.isNotEmpty) return r.errors.first;
      }
    }
    return null;
  }

  PersonalDriveBackupState copyWith({
    Set<String>? selectedRollIds,
    PersonalDriveSyncJob? activeJob,
    List<String>? activeJobRollIds,
    bool? isStarting,
    bool? isResuming,
    Map<String, PersonalDriveBackupRecord>? history,
    String? errorMessage,
    bool clearError = false,
    String? freeUploadingRollId,
    bool clearFreeUploading = false,
    Map<String, FreePersonalDriveRollBackupResult>? freeResults,
    int? freeFrameDone,
    int? freeFrameTotal,
    bool clearFreeFrameProgress = false,
    bool? needsDriveReauth,
    bool clearNeedsDriveReauth = false,
    List<String>? pendingReauthRollIds,
  }) {
    return PersonalDriveBackupState(
      selectedRollIds: selectedRollIds ?? this.selectedRollIds,
      activeJob: activeJob ?? this.activeJob,
      activeJobRollIds: activeJobRollIds ?? this.activeJobRollIds,
      isStarting: isStarting ?? this.isStarting,
      isResuming: isResuming ?? this.isResuming,
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      freeUploadingRollId:
          clearFreeUploading ? null : (freeUploadingRollId ?? this.freeUploadingRollId),
      freeResults: freeResults ?? this.freeResults,
      freeFrameDone: clearFreeFrameProgress ? 0 : (freeFrameDone ?? this.freeFrameDone),
      freeFrameTotal: clearFreeFrameProgress ? 0 : (freeFrameTotal ?? this.freeFrameTotal),
      needsDriveReauth:
          clearNeedsDriveReauth ? false : (needsDriveReauth ?? this.needsDriveReauth),
      pendingReauthRollIds: pendingReauthRollIds ?? this.pendingReauthRollIds,
    );
  }
}

class PersonalDriveBackupController extends Notifier<PersonalDriveBackupState> {
  final PersonalDriveBackupService _service;
  final FreePersonalDriveBackupService _freeService;
  Timer? _pollTimer;

  PersonalDriveBackupController({
    PersonalDriveBackupService? service,
    FreePersonalDriveBackupService? freeService,
  })  : _service = service ?? PersonalDriveBackupService(),
        _freeService = freeService ?? FreePersonalDriveBackupService();

  @override
  PersonalDriveBackupState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    _init();
    return const PersonalDriveBackupState();
  }

  bool get _isFree => ref.read(userPlanProvider) == UserPlan.free;

  Future<void> _init() async {
    final history = await _service.loadHistory();
    if (!ref.mounted) return;
    state = state.copyWith(history: history, isResuming: false);

    // Only Pro resumes server-side jobs.
    if (_isFree) return;

    final active = await _service.loadActiveJob();
    if (active == null || !ref.mounted) return;
    try {
      final job = await _service.fetchJob(active.jobId);
      if (!ref.mounted) return;
      state = state.copyWith(activeJob: job, activeJobRollIds: active.rollIds);
      if (job.isFinished) {
        await _finishJob(job, active.rollIds);
      } else {
        _startPolling();
      }
    } catch (_) {
      await _service.clearActiveJob();
    }
  }

  void toggleSelection(String rollId) {
    if (state.isRunning) return;
    final next = Set<String>.from(state.selectedRollIds);
    if (!next.remove(rollId)) next.add(rollId);
    state = state.copyWith(selectedRollIds: next);
  }

  void selectAll(Iterable<String> rollIds) {
    if (state.isRunning) return;
    state = state.copyWith(selectedRollIds: Set<String>.from(rollIds));
  }

  void clearSelection() {
    if (state.isRunning) return;
    state = state.copyWith(selectedRollIds: {});
  }

  /// Starts a batch job for the currently-selected rolls.
  Future<bool> startBackup({bool force = false}) async {
    if (state.isRunning || state.selectedRollIds.isEmpty) return false;
    final rollIds = state.selectedRollIds.toList();

    if (_isFree) {
      return _startFreeDeviceBackup(rollIds);
    }

    state = state.copyWith(isStarting: true, clearError: true);
    try {
      final job = await _service.startBackup(rollIds: rollIds, force: force);
      if (!ref.mounted) return true;
      state = state.copyWith(
        isStarting: false,
        activeJob: job,
        activeJobRollIds: rollIds,
        selectedRollIds: {},
      );
      if (job.isFinished) {
        await _finishJob(job, rollIds);
      } else {
        _startPolling();
      }
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(isStarting: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> retryRoll(String rollId, {bool force = true}) async {
    if (state.isRunning) return false;
    if (_isFree) {
      return _startFreeDeviceBackup([rollId]);
    }
    state = state.copyWith(isStarting: true, clearError: true);
    try {
      final job = await _service.startBackup(rollIds: [rollId], force: force);
      if (!ref.mounted) return true;
      state = state.copyWith(
        isStarting: false,
        activeJob: job,
        activeJobRollIds: [rollId],
      );
      if (job.isFinished) {
        await _finishJob(job, [rollId]);
      } else {
        _startPolling();
      }
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(isStarting: false, errorMessage: _friendlyError(e));
      return false;
    }
  }

  Future<bool> _startFreeDeviceBackup(List<String> rollIds) async {
    state = state.copyWith(
      isStarting: true,
      clearError: true,
      clearNeedsDriveReauth: true,
      selectedRollIds: {},
      activeJobRollIds: rollIds,
      freeResults: {
        for (final e in state.freeResults.entries)
          if (!rollIds.contains(e.key)) e.key: e.value,
      },
    );

    GoogleDriveDeviceClient drive;
    try {
      drive = await GoogleDriveDeviceClient.connect(interactive: true);
    } on GoogleDriveDeviceException catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isStarting: false,
        errorMessage: e.message,
        needsDriveReauth: e.needsReauth,
        pendingReauthRollIds: e.needsReauth ? rollIds : const [],
      );
      return false;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isStarting: false,
        errorMessage: 'Could not sign in to Google Drive. Reconnect and try again.',
        needsDriveReauth: true,
        pendingReauthRollIds: rollIds,
      );
      return false;
    }

    String vaultId;
    try {
      vaultId = await drive.ensureVaultFolder();
    } on GoogleDriveDeviceException catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isStarting: false,
        errorMessage: e.message,
        needsDriveReauth: e.needsReauth,
        pendingReauthRollIds: e.needsReauth ? rollIds : const [],
      );
      return false;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isStarting: false,
        errorMessage: 'Could not create Agxel Vault folder on Drive.',
      );
      return false;
    }

    if (!ref.mounted) return false;
    state = state.copyWith(isStarting: false, clearNeedsDriveReauth: true);

    final rollsById = await _rollsById();
    final results = Map<String, FreePersonalDriveRollBackupResult>.from(state.freeResults);
    var failedCount = 0;

    for (final rollId in rollIds) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        freeUploadingRollId: rollId,
        freeFrameDone: 0,
        freeFrameTotal: 0,
      );
      final roll = rollsById[rollId];
      FreePersonalDriveRollBackupResult result;
      if (roll == null) {
        result = FreePersonalDriveRollBackupResult(
          rollId: rollId,
          error: 'Roll not found.',
        );
      } else {
        result = await _freeService.backupRoll(
          roll: roll,
          drive: drive,
          vaultFolderId: vaultId,
          onFrameProgress: (done, total) {
            if (!ref.mounted) return;
            state = state.copyWith(freeFrameDone: done, freeFrameTotal: total);
          },
        );
      }

      // Mid-upload 403 (stale scopes) → ask to reconnect and retry remaining.
      if (result.isRollLevelError && result.needsReauth) {
        final remaining = rollIds.skip(rollIds.indexOf(rollId)).toList();
        if (!ref.mounted) return false;
        state = state.copyWith(
          freeResults: {...results, rollId: result},
          clearFreeUploading: true,
          clearFreeFrameProgress: true,
          needsDriveReauth: true,
          pendingReauthRollIds: remaining,
          errorMessage: result.error ??
              'Google Drive needs updated permissions. Reconnect Drive and try again.',
        );
        return false;
      }

      results[rollId] = result;
      if (result.isRollLevelError) failedCount++;
      if (!ref.mounted) return false;
      state = state.copyWith(freeResults: results, clearFreeFrameProgress: true);
      await _recordFreeResult(rollId, result);
    }

    if (!ref.mounted) return false;
    final history = await _service.loadHistory();
    state = state.copyWith(
      history: history,
      freeResults: results,
      clearFreeUploading: true,
      clearFreeFrameProgress: true,
      clearError: true,
      clearNeedsDriveReauth: true,
    );
    return failedCount < rollIds.length;
  }

  void clearNeedsDriveReauth() {
    state = state.copyWith(
      clearNeedsDriveReauth: true,
      pendingReauthRollIds: const [],
    );
  }

  /// After the user reconnects Drive, retry the rolls that were waiting.
  Future<bool> retryAfterDriveReauth() async {
    final ids = state.pendingReauthRollIds;
    if (ids.isEmpty) return false;
    state = state.copyWith(
      clearNeedsDriveReauth: true,
      pendingReauthRollIds: const [],
      selectedRollIds: ids.toSet(),
      clearError: true,
    );
    return startBackup();
  }

  Future<Map<String, Roll>> _rollsById() async {
    try {
      final rolls = await ref.read(dashboardRollsProvider.future);
      return {for (final r in rolls) r.id: r};
    } catch (_) {
      return {};
    }
  }

  Future<void> _recordFreeResult(
    String rollId,
    FreePersonalDriveRollBackupResult result,
  ) async {
    // Reuse the same on-device history store as Pro jobs.
    final fakeJob = PersonalDriveSyncJob(
      id: 'free-local',
      status: result.isRollLevelError
          ? PersonalDriveSyncJobStatus.failed
          : PersonalDriveSyncJobStatus.succeeded,
      totalRolls: 1,
      completedRolls: result.isRollLevelError ? 0 : 1,
      failedRolls: result.isRollLevelError ? 1 : 0,
      result: [
        PersonalDriveRollSyncResult(
          rollId: rollId,
          uploaded: result.uploaded,
          skipped: result.skipped,
          failed: result.failed,
          errors: result.errors,
          error: result.error,
        ),
      ],
      error: result.error,
    );
    await _service.recordJobResult(fakeJob, [rollId]);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    final job = state.activeJob;
    if (job == null) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final updated = await _service.fetchJob(job.id);
      if (!ref.mounted) return;
      state = state.copyWith(activeJob: updated);
      if (updated.isFinished) {
        _pollTimer?.cancel();
        await _finishJob(updated, state.activeJobRollIds);
      }
    } catch (_) {
      // Transient network hiccup — keep polling.
    }
  }

  Future<void> _finishJob(PersonalDriveSyncJob job, List<String> rollIds) async {
    await _service.recordJobResult(job, rollIds);
    await _service.clearActiveJob();
    if (!ref.mounted) return;
    final history = await _service.loadHistory();
    if (!ref.mounted) return;
    state = state.copyWith(history: history);
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      if (detail != null && detail.trim().isNotEmpty) return detail;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'Network problem. Check your connection and try again.';
      }
      return e.message ?? 'Could not start backup. Please try again.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}

final personalDriveBackupControllerProvider =
    NotifierProvider.autoDispose<PersonalDriveBackupController, PersonalDriveBackupState>(
  PersonalDriveBackupController.new,
);
