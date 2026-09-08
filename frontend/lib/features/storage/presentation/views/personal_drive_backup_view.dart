import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/notification_model.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/theme/halide_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/halide_dialog.dart';
import '../../../../core/widgets/halide_scaffold.dart';
import '../../../../models/roll.dart';
import '../../../../models/roll_status.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../services/api_service.dart';
import '../../../../services/gdrive_connection_guard.dart';
import '../../../../widgets/sync_progress_banner.dart';
import '../providers/personal_drive_backup_provider.dart';

/// Lets the user pick which rolls to back up to their personal Google Drive
/// ("Agxel Vault") and kicks off a batch job, showing live per-roll progress.
/// Rolls can be selected and backed up incrementally over multiple visits —
/// on-device history shows what's already been archived.
class PersonalDriveBackupView extends ConsumerStatefulWidget {
  const PersonalDriveBackupView({Key? key}) : super(key: key);

  @override
  ConsumerState<PersonalDriveBackupView> createState() => _PersonalDriveBackupViewState();
}

enum _DriveConnectionState { checking, connected, notConnected }

class _PersonalDriveBackupViewState extends ConsumerState<PersonalDriveBackupView> {
  _DriveConnectionState _connection = _DriveConnectionState.checking;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await isGoogleDriveConnected(ApiService());
    if (!mounted) return;
    setState(() {
      _connection = connected ? _DriveConnectionState.connected : _DriveConnectionState.notConnected;
    });
  }

  Future<void> _connectDrive() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final ok = await ensureGoogleDriveConnected(context, ref);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _connection = ok ? _DriveConnectionState.connected : _DriveConnectionState.notConnected;
    });
  }

  List<Roll> _eligibleRolls(List<Roll> rolls) {
    // "Shooting" rolls have no scans yet — nothing to mirror to Drive.
    final eligible = rolls.where((r) => r.status != RollStatus.shooting).toList();
    eligible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return eligible;
  }

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    final rollsAsync = ref.watch(dashboardRollsProvider);
    final backupState = ref.watch(personalDriveBackupControllerProvider);

    ref.listen(personalDriveBackupControllerProvider, (previous, next) {
      if (next.needsDriveReauth && !(previous?.needsDriveReauth ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final ok = await promptReconnectGoogleDriveForVault(context, ref);
          if (!mounted) return;
          final ctrl = ref.read(personalDriveBackupControllerProvider.notifier);
          if (ok) {
            await ctrl.retryAfterDriveReauth();
          } else {
            ctrl.clearNeedsDriveReauth();
          }
        });
      }

      final err = next.errorMessage;
      if (err != null &&
          err != previous?.errorMessage &&
          !next.needsDriveReauth) {
        ref.read(notificationProvider.notifier).show(err, type: NotificationType.error);
      }
      final wasRunning = previous?.isRunning ?? false;
      if (!wasRunning || next.isRunning) return;

      // Free device→Drive batch finished.
      if (previous?.freeUploadingRollId != null ||
          (previous?.activeJobRollIds.isNotEmpty == true && next.freeResults.isNotEmpty && next.activeJob == null)) {
        final failed = next.freeResults.values.where((r) => r.isRollLevelError).length;
        final total = next.activeJobRollIds.isNotEmpty
            ? next.activeJobRollIds.length
            : next.freeResults.length;
        if (failed > 0) {
          ref.read(notificationProvider.notifier).show(
                failed >= total
                    ? 'Backup failed for all selected rolls.'
                    : 'Backup finished with $failed roll(s) failed.',
                type: NotificationType.warning,
              );
        } else {
          ref.read(notificationProvider.notifier).show(
                'Backup complete — rolls saved to Agxel Vault on Google Drive.',
                type: NotificationType.success,
              );
        }
        return;
      }

      final job = next.activeJob;
      if (job != null) {
        final failed = job.failedRolls;
        if (failed > 0) {
          ref.read(notificationProvider.notifier).show(
                failed == job.totalRolls
                    ? 'Backup failed for all selected rolls.'
                    : 'Backup finished with $failed roll(s) failed.',
                type: NotificationType.warning,
              );
        } else {
          ref.read(notificationProvider.notifier).show(
                'Backup complete — rolls saved to Agxel Vault on Google Drive.',
                type: NotificationType.success,
              );
        }
      }
    });

    return HalideScaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          color: Colors.white,
        ),
        centerTitle: true,
        title: const Text(
          'PERSONAL DRIVE BACKUP',
          style: TextStyle(
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: _buildBody(context, colors, rollsAsync, backupState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HalideColors colors,
    AsyncValue<List<Roll>> rollsAsync,
    PersonalDriveBackupState backupState,
  ) {
    if (_connection == _DriveConnectionState.checking) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }

    if (_connection == _DriveConnectionState.notConnected) {
      return _buildConnectPrompt(colors);
    }

    return rollsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
      error: (e, __) => Center(
        child: Text(
          'Could not load rolls.',
          style: TextStyle(color: colors.textSecondary),
        ),
      ),
      data: (rolls) {
        final eligible = _eligibleRolls(rolls);
        if (eligible.isEmpty) {
          return _buildEmptyState(colors);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Back up full-quality scans to your personal Google Drive, under '
                'an Agxel Vault folder. Pick a few rolls now — you can archive more '
                'anytime.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
            _buildToolbar(colors, eligible, backupState),
            if (backupState.isRunning) _buildProgressBanner(colors, backupState),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                itemCount: eligible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final roll = eligible[index];
                  return _RollPickerTile(
                    roll: roll,
                    selected: backupState.selectedRollIds.contains(roll.id),
                    phase: backupState.phaseFor(roll.id),
                    lastSyncedAt: backupState.lastSyncedAtFor(roll.id),
                    errorDetail: backupState.errorDetailFor(roll.id),
                    interactive: !backupState.isRunning,
                    onTap: () => ref
                        .read(personalDriveBackupControllerProvider.notifier)
                        .toggleSelection(roll.id),
                    onRetry: () => ref
                        .read(personalDriveBackupControllerProvider.notifier)
                        .retryRoll(roll.id),
                  );
                },
              ),
            ),
            _buildBottomBar(colors, backupState),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(HalideColors colors, List<Roll> eligible, PersonalDriveBackupState backupState) {
    final allSelected = eligible.isNotEmpty &&
        eligible.every((r) => backupState.selectedRollIds.contains(r.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Text(
            backupState.selectedRollIds.isEmpty
                ? '${eligible.length} ${eligible.length == 1 ? 'roll' : 'rolls'}'
                : '${backupState.selectedRollIds.length} selected',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: backupState.isRunning
                ? null
                : () {
                    final notifier = ref.read(personalDriveBackupControllerProvider.notifier);
                    if (allSelected) {
                      notifier.clearSelection();
                    } else {
                      notifier.selectAll(eligible.map((r) => r.id));
                    }
                  },
            child: Text(
              allSelected ? 'CLEAR' : 'SELECT ALL',
              style: TextStyle(
                color: colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBanner(HalideColors colors, PersonalDriveBackupState backupState) {
    final job = backupState.activeJob;
    final total = job != null
        ? (job.totalRolls == 0 ? backupState.activeJobRollIds.length : job.totalRolls)
        : backupState.activeJobRollIds.length;
    final processed = job != null
        ? job.processedRolls
        : backupState.freeResults.length;
    // Prefer frame-level % while uploading a free roll (moves every file).
    final double? progress;
    if (backupState.freeUploadingRollId != null && backupState.freeFrameTotal > 0) {
      final completed = backupState.freeResults.length;
      final frameFrac =
          (backupState.freeFrameDone / backupState.freeFrameTotal).clamp(0.0, 1.0);
      progress = ((completed + frameFrac) / (total <= 0 ? 1 : total)).clamp(0.0, 1.0);
    } else {
      progress = backupState.bannerProgress;
    }

    final String label;
    if (backupState.freeUploadingRollId != null && backupState.freeFrameTotal > 0) {
      label =
          'Backing up roll ${processed + 1} of $total — '
          'frame ${backupState.freeFrameDone}/${backupState.freeFrameTotal}';
    } else if (backupState.freeUploadingRollId != null) {
      label = 'Backing up ${processed + 1} of $total rolls…';
    } else {
      label = 'Backing up $processed of $total rolls…';
    }

    return SyncProgressBanner(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      label: label,
      progress: progress,
      accentColor: colors.accent,
    );
  }

  Widget _buildBottomBar(HalideColors colors, PersonalDriveBackupState backupState) {
    final count = backupState.selectedRollIds.length;
    final canStart = count > 0 && !backupState.isRunning && !backupState.isStarting;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: canStart
                ? () => ref.read(personalDriveBackupControllerProvider.notifier).startBackup()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: colors.glassFill(0.18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: backupState.isStarting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    backupState.isRunning
                        ? 'BACKUP IN PROGRESS…'
                        : count == 0
                            ? 'SELECT ROLLS TO BACK UP'
                            : count == 1
                                ? 'BACKUP 1 ROLL'
                                : 'BACKUP $count ROLLS',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectPrompt(HalideColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassPanel(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload_outlined, color: colors.accent, size: 40),
              const SizedBox(height: 16),
              Text(
                'CONNECT GOOGLE DRIVE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Connect your personal Google Drive to back up rolls under an '
                'Agxel Vault folder — full-quality frames, on your own storage.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              HalideActionButton(
                text: 'Connect Google Drive',
                isLoading: _connecting,
                onPressed: _connectDrive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(HalideColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, color: colors.textSecondary, size: 40),
            const SizedBox(height: 16),
            Text(
              'No scanned rolls yet',
              style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Once a roll is at the lab or scanned, it\'ll show up here to back up.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RollPickerTile extends StatelessWidget {
  final Roll roll;
  final bool selected;
  final RollBackupPhase phase;
  final DateTime? lastSyncedAt;
  final String? errorDetail;
  final bool interactive;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  const _RollPickerTile({
    required this.roll,
    required this.selected,
    required this.phase,
    required this.lastSyncedAt,
    required this.errorDetail,
    required this.interactive,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    final title = (roll.title?.trim().isNotEmpty ?? false) ? roll.title!.trim() : roll.name;
    final thumb = roll.imageUrls.isNotEmpty ? roll.imageUrls.first : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: selected ? colors.accent.withOpacity(0.10) : colors.glassFill(0.05),
        child: InkWell(
          onTap: interactive ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? colors.accent.withOpacity(0.55) : colors.glassBorder(0.2),
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _SelectionCheckbox(selected: selected, color: colors.accent, dim: !interactive),
                const SizedBox(width: 12),
                _RollThumb(color: roll.color, imageUrl: thumb),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phase == RollBackupPhase.error && (errorDetail?.isNotEmpty ?? false)
                            ? errorDetail!
                            : '${roll.name} · ${roll.status.label}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: phase == RollBackupPhase.error ? colors.error : colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(phase: phase, lastSyncedAt: lastSyncedAt, onRetry: interactive ? onRetry : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  final bool selected;
  final Color color;
  final bool dim;
  const _SelectionCheckbox({required this.selected, required this.color, required this.dim});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(dim ? 0.4 : 1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? color.withOpacity(dim ? 0.4 : 1) : Colors.white.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
    );
  }
}

class _RollThumb extends StatelessWidget {
  final Color color;
  final String? imageUrl;
  const _RollThumb({required this.color, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        color: color.withOpacity(0.35),
        child: (imageUrl != null && imageUrl!.startsWith('http'))
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : Icon(Icons.camera_alt_outlined, color: Colors.white.withOpacity(0.6), size: 18),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final RollBackupPhase phase;
  final DateTime? lastSyncedAt;
  final VoidCallback? onRetry;

  const _StatusChip({required this.phase, required this.lastSyncedAt, required this.onRetry});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    switch (phase) {
      case RollBackupPhase.uploading:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
        );
      case RollBackupPhase.done:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_done_outlined, color: Color(0xFF6FCF97), size: 16),
            if (lastSyncedAt != null) ...[
              const SizedBox(width: 4),
              Text(
                _relativeTime(lastSyncedAt!),
                style: TextStyle(color: colors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        );
      case RollBackupPhase.error:
        return InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colors.error, size: 16),
                if (onRetry != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    'RETRY',
                    style: TextStyle(color: colors.error, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
        );
      case RollBackupPhase.idle:
        return const SizedBox.shrink();
    }
  }
}
