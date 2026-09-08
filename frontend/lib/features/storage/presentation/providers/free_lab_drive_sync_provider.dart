import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Progress / status for a Free-tier lab Drive → local sync.
///
/// Lab Drive URL sync is Pro-only now. Free users add photos from the device.
/// This controller remains so any stale UI still fails closed with a clear message.
class FreeLabDriveSyncState {
  final String? rollId;
  final bool isRunning;
  final int done;
  final int total;
  final String? errorMessage;
  final String? successMessage;
  final int? savedCount;

  const FreeLabDriveSyncState({
    this.rollId,
    this.isRunning = false,
    this.done = 0,
    this.total = 0,
    this.errorMessage,
    this.successMessage,
    this.savedCount,
  });

  double? get progress {
    if (!isRunning || total <= 0) return null;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Whole-number percent for banners; null while indeterminate.
  int? get percent {
    final p = progress;
    if (p == null) return null;
    return (p * 100).round();
  }

  String get progressLabel {
    if (!isRunning) return '';
    if (total > 0) {
      return 'Downloading $done of $total… Keep the app open.';
    }
    return 'Starting download… Keep the app open.';
  }

  FreeLabDriveSyncState copyWith({
    String? rollId,
    bool? isRunning,
    int? done,
    int? total,
    String? errorMessage,
    String? successMessage,
    int? savedCount,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return FreeLabDriveSyncState(
      rollId: rollId ?? this.rollId,
      isRunning: isRunning ?? this.isRunning,
      done: done ?? this.done,
      total: total ?? this.total,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      savedCount: savedCount ?? this.savedCount,
    );
  }
}

/// Lab Drive → device sync is disabled for Free. Prefer device photo pick / Pro cloud sync.
class FreeLabDriveSyncController extends Notifier<FreeLabDriveSyncState> {
  @override
  FreeLabDriveSyncState build() => const FreeLabDriveSyncState();

  bool get isBusy => state.isRunning;

  Future<bool> start({
    required String rollId,
    required String driveUrl,
  }) async {
    debugPrint(
      '[FreeLabSync] blocked — Drive URL lab sync requires Pro (roll=$rollId)',
    );
    state = FreeLabDriveSyncState(
      rollId: rollId,
      isRunning: false,
      errorMessage:
          'Syncing scans from a Drive link requires Halide Pro. Add photos from this device instead.',
    );
    return false;
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final freeLabDriveSyncControllerProvider =
    NotifierProvider<FreeLabDriveSyncController, FreeLabDriveSyncState>(
  FreeLabDriveSyncController.new,
);
