import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../widgets/roll_card.dart';
import '../providers/dashboard_provider.dart';
import 'package:frontend/providers/rolls_provider.dart';
import 'package:frontend/features/rolls/presentation/widgets/add_roll_form.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../core/theme/halide_colors.dart';
import '../models/roll_status.dart';
import '../models/roll.dart';
import '../services/guidance_service.dart';
import '../providers/guidance_pending_provider.dart'
    show newRollGuidanceRollIdProvider, syncGuidanceRollIdProvider;
import '../widgets/guidance/lab_drive_sync_guidance.dart';
import '../widgets/guidance/guidance_tokens.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import '../widgets/sync_progress_banner.dart';
import '../features/storage/presentation/providers/free_lab_drive_sync_provider.dart';
import '../features/storage/presentation/providers/personal_drive_backup_provider.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

/// Fields that affect archive / new-roll guidance; must change when [Roll] data updates so guidance can reschedule.
int _guidanceRollsSignature(List<Roll> rolls) {
  return Object.hashAll(
    rolls.map(
      (r) => Object.hash(
        r.id,
        r.status,
        r.imageUrls.length,
        (r.driveUrl ?? '').trim(),
      ),
    ),
  );
}

/// Archive list filter — All (default, non-archived), In Progress, Archived.
enum _ArchiveListFilter { all, inProgress, archived }

class _HomeViewState extends ConsumerState<HomeView> {
  _ArchiveListFilter _listFilter = _ArchiveListFilter.all;

  final GlobalKey _guidanceStatusKey = GlobalKey();
  final GlobalKey _guidanceLinkSyncKey = GlobalKey();
  final GlobalKey _shootingIntroStatusKey = GlobalKey();
  final GlobalKey _shootingIntroExifKey = GlobalKey();
  final GlobalKey _shootingIntroViewLogsKey = GlobalKey();
  final GlobalKey _backupUploadKey = GlobalKey();
  final ScrollController _archiveListScrollController = ScrollController();

  Object? _guidanceSignature;
  /// Bumped when a coach finishes so the next guidance step can schedule without looping the same step.
  int _guidanceEpoch = 0;
  bool _archiveGuidanceBusy = false;
  /// Which card receives coach keys (only one roll at a time).
  String? _guidanceTargetRollId;
  /// New-roll shooting intro (status / EXIF / VIEW LOGS); exclusive of archive keys.
  String? _newRollGuidanceTargetRollId;
  bool _highlightStatusKey = false;
  bool _highlightLinkSyncKey = false;
  /// Dismissible tip under filters for personal Drive backup.
  bool _showBackupGuideTip = false;
  bool _backupGuideTipLoaded = false;
  bool _trialPaywallScheduled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureBackupGuideTipLoaded());
  }

  void _maybeShowTrialPaywall() {
    if (_trialPaywallScheduled) return;
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;
    if (profile.hasSeenOnboarding) return;
    if (profile.plan.isPro || ref.read(userPlanProvider).isPro) {
      _trialPaywallScheduled = true;
      unawaited(ref.read(profileServiceProvider).markOnboardingSeen());
      return;
    }
    // Existing accounts never used this flag — don't spam them with a paywall.
    final created = profile.createdAt;
    if (created != null) {
      final age = DateTime.now().toUtc().difference(created.toUtc());
      if (age > const Duration(days: 1)) {
        _trialPaywallScheduled = true;
        unawaited(ref.read(profileServiceProvider).markOnboardingSeen());
        return;
      }
    }
    _trialPaywallScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push('/paywall?trial=1');
    });
  }

  @override
  void dispose() {
    _archiveListScrollController.dispose();
    super.dispose();
  }

  void _showAddRollDialog() {
    final bloc = ref.read(rollsBlocProvider);
    showHalideDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: AddRollForm(
          repository: ref.read(rollsRepositoryProvider),
          onRollAdded: () {
            setState(() => _listFilter = _ArchiveListFilter.all);
            ref.invalidate(dashboardRollsProvider);
          },
        ),
      ),
    );
  }

  static bool _hasSavedDriveUrl(Roll r) => (r.driveUrl ?? '').trim().isNotEmpty;

  void _clearGuidanceHighlight() {
    _guidanceTargetRollId = null;
    _highlightStatusKey = false;
    _highlightLinkSyncKey = false;
  }

  Future<void> _ensureKeyVisible(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.25,
      );
    }
  }

  void _finishNewRollShootingIntro(GuidanceService g) {
    g.setNewRollShootingIntroSeen().then((_) {
      if (!mounted) return;
      ref.read(newRollGuidanceRollIdProvider.notifier).setPending(null);
      setState(() {
        _archiveGuidanceBusy = false;
        _newRollGuidanceTargetRollId = null;
        _guidanceEpoch++;
      });
    });
  }

  void _showShootingIntroStep2(GuidanceService g) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _ensureKeyVisible(_shootingIntroExifKey);
      if (!mounted) return;
      final coach = buildSingleStepArchiveGuidance(
        context: context,
        targetKey: _shootingIntroExifKey,
        identify: 'new_roll_exif_log',
        contentAlign: ContentAlign.top,
        body:
            context.l10n.guidanceNewRollExif,
        onCompleted: () => _showShootingIntroStep3(g),
        beforeFocus: (_) async {
          final c = _shootingIntroExifKey.currentContext;
          if (c != null) {
            await Scrollable.ensureVisible(
              c,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              alignment: 0.35,
            );
          }
        },
      );
      coach.show(context: context);
    });
  }

  void _showShootingIntroStep3(GuidanceService g) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _ensureKeyVisible(_shootingIntroViewLogsKey);
      if (!mounted) return;
      final coach = buildSingleStepArchiveGuidance(
        context: context,
        targetKey: _shootingIntroViewLogsKey,
        identify: 'new_roll_view_shot_log',
        contentAlign: ContentAlign.top,
        body: context.l10n.guidanceNewRollViewLogs,
        onCompleted: () => _finishNewRollShootingIntro(g),
        beforeFocus: (_) async {
          final c = _shootingIntroViewLogsKey.currentContext;
          if (c != null) {
            await Scrollable.ensureVisible(
              c,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              alignment: 0.35,
            );
          }
        },
      );
      coach.show(context: context);
    });
  }

  Future<void> _scheduleNewRollShootingIntro(List<Roll> rolls, List<Roll> visibleRolls) async {
    if (!mounted || _archiveGuidanceBusy) return;
    final pending = ref.read(newRollGuidanceRollIdProvider);
    if (pending == null) return;

    final g = GuidanceService.instance;
    if (await g.hasSeenNewRollShootingIntro) {
      ref.read(newRollGuidanceRollIdProvider.notifier).setPending(null);
      return;
    }

    Roll? match;
    for (final r in visibleRolls) {
      if (r.id == pending && r.status == RollStatus.shooting) {
        match = r;
        break;
      }
    }
    if (match == null) return;

    setState(() {
      _archiveGuidanceBusy = true;
      _newRollGuidanceTargetRollId = pending;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _ensureKeyVisible(_shootingIntroStatusKey);
    if (!mounted) return;

    final coach = buildSingleStepArchiveGuidance(
      context: context,
      targetKey: _shootingIntroStatusKey,
      identify: 'new_roll_change_status',
      body: context.l10n.guidanceNewRollStatus,
      onCompleted: () => _showShootingIntroStep2(g),
      beforeFocus: (_) async {
        final c = _shootingIntroStatusKey.currentContext;
        if (c != null) {
          await Scrollable.ensureVisible(
            c,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: 0.15,
          );
        }
      },
    );
    coach.show(context: context);
  }

  /// After saving a Drive URL: coach the cloud/sync control — only if [RollCard] actually shows it.
  Future<void> _scheduleSyncAfterDriveUrlGuidance(List<Roll> visibleRolls) async {
    final pendingSyncRollId = ref.read(syncGuidanceRollIdProvider);
    if (pendingSyncRollId == null) return;

    final g = GuidanceService.instance;
    if (await g.hasSeenSyncAfterLinkGuidance) {
      ref.read(syncGuidanceRollIdProvider.notifier).setPending(null);
      return;
    }

    Roll? roll;
    for (final r in visibleRolls) {
      if (r.id == pendingSyncRollId) {
        roll = r;
        break;
      }
    }
    if (roll == null) return;

    final hasUrl = _hasSavedDriveUrl(roll);
    final slotVisible = rollShowsLinkSyncControl(roll, ref);

    if (!slotVisible || !hasUrl) {
      ref.read(syncGuidanceRollIdProvider.notifier).setPending(null);
      return;
    }

    final matched = roll;
    setState(() {
      _archiveGuidanceBusy = true;
      _guidanceTargetRollId = matched.id;
      _highlightStatusKey = false;
      _highlightLinkSyncKey = true;
    });
    ref.read(syncGuidanceRollIdProvider.notifier).setPending(null);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    final ctx = _guidanceLinkSyncKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.22,
      );
    }
    if (!mounted) return;
    final coach = buildSingleStepArchiveGuidance(
      context: context,
      targetKey: _guidanceLinkSyncKey,
      identify: 'sync_after_link',
      body: context.l10n.guidanceSyncAfterLink,
      onCompleted: () async {
        await g.setSyncAfterLinkGuidanceSeen();
        await g.setDriveUrlOnCardGuidanceSeen();
        if (mounted) {
          setState(() {
            _archiveGuidanceBusy = false;
            _clearGuidanceHighlight();
            _guidanceEpoch++;
          });
        }
      },
      beforeFocus: (_) async {
        final c = _guidanceLinkSyncKey.currentContext;
        if (c != null) {
          await Scrollable.ensureVisible(
            c,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: 0.25,
          );
        }
      },
    );
    coach.show(context: context);
  }

  Future<void> _scheduleArchiveGuidance(List<Roll> rolls, List<Roll> visibleRolls) async {
    if (!mounted || _archiveGuidanceBusy) return;
    if (rolls.isEmpty || visibleRolls.isEmpty) return;

    final g = GuidanceService.instance;

    // —— Priority 1: after saving Drive URL (only when top-right link/sync slot + saved URL) ——
    if (ref.read(syncGuidanceRollIdProvider) != null) {
      await _scheduleSyncAfterDriveUrlGuidance(visibleRolls);
      if (_archiveGuidanceBusy) return;
      if (ref.read(syncGuidanceRollIdProvider) != null) return;
    }

    // —— Priority 2: first time any roll is At Lab ————————————————————————
    final seenAtLab = await g.hasSeenAtLabGuidance;
    if (!seenAtLab) {
      Roll? labRoll;
      for (final r in visibleRolls) {
        if (r.status == RollStatus.lab) {
          labRoll = r;
          break;
        }
      }
      if (labRoll != null) {
        final lr = labRoll;
        setState(() {
          _archiveGuidanceBusy = true;
          _guidanceTargetRollId = lr.id;
          _highlightStatusKey = true;
          _highlightLinkSyncKey = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        final ctx = _guidanceStatusKey.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            alignment: 0.12,
          );
        }
        if (!mounted) return;
        final coach = buildSingleStepArchiveGuidance(
          context: context,
          targetKey: _guidanceStatusKey,
          identify: 'at_lab_badge',
          body: context.l10n.guidanceAtLabBadge,
          onCompleted: () async {
            await g.setAtLabGuidanceSeen();
            if (mounted) {
              setState(() {
                _archiveGuidanceBusy = false;
                _clearGuidanceHighlight();
                _guidanceEpoch++;
              });
            }
          },
          beforeFocus: (_) async {
            final c = _guidanceStatusKey.currentContext;
            if (c != null) {
              await Scrollable.ensureVisible(
                c,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                alignment: 0.12,
              );
            }
          },
        );
        coach.show(context: context);
        return;
      }
    }

    // —— Priority 3: first time the link / cloud row is relevant (At Lab or Scanned, no images yet) ——
    // Include rolls with **no** URL yet — that’s when only the link icon shows (top right).
    final seenDrive = await g.hasSeenDriveUrlOnCardGuidance;
    if (!seenDrive) {
      Roll? linkRowRoll;
      for (final r in visibleRolls) {
        if (rollShowsLinkSyncControl(r, ref)) {
          linkRowRoll = r;
          break;
        }
      }
      if (linkRowRoll != null) {
        final ur = linkRowRoll;
        final hasUrl = _hasSavedDriveUrl(ur);
        final linkRowBody = hasUrl
            ? context.l10n.guidanceDriveLinkWithUrl
            : context.l10n.guidanceDriveLinkNoUrl;
        setState(() {
          _archiveGuidanceBusy = true;
          _guidanceTargetRollId = ur.id;
          _highlightStatusKey = false;
          _highlightLinkSyncKey = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        final ctx = _guidanceLinkSyncKey.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            alignment: 0.22,
          );
        }
        if (!mounted) return;
        final coach = buildSingleStepArchiveGuidance(
          context: context,
          targetKey: _guidanceLinkSyncKey,
          identify: 'drive_link_row_on_card',
          body: linkRowBody,
          onCompleted: () async {
            await g.setDriveUrlOnCardGuidanceSeen();
            if (mounted) {
              setState(() {
                _archiveGuidanceBusy = false;
                _clearGuidanceHighlight();
                _guidanceEpoch++;
              });
            }
          },
          beforeFocus: (_) async {
            final c = _guidanceLinkSyncKey.currentContext;
            if (c != null) {
              await Scrollable.ensureVisible(
                c,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                alignment: 0.25,
              );
            }
          },
        );
        coach.show(context: context);
      }
    }

    // —— Priority 4: personal Drive backup (cloud upload in app bar) ——
    if (!_archiveGuidanceBusy) {
      await _schedulePersonalDriveBackupGuidance();
    }
  }

  Future<void> _ensureBackupGuideTipLoaded() async {
    if (_backupGuideTipLoaded) return;
    _backupGuideTipLoaded = true;
    final seen = await GuidanceService.instance.hasSeenPersonalDriveBackupGuidance;
    if (!mounted) return;
    setState(() => _showBackupGuideTip = !seen);
  }

  Future<void> _dismissBackupGuideTip({bool markSeen = true}) async {
    if (!_showBackupGuideTip) return;
    setState(() => _showBackupGuideTip = false);
    if (markSeen) {
      await GuidanceService.instance.setPersonalDriveBackupGuidanceSeen();
    }
  }

  Future<void> _schedulePersonalDriveBackupGuidance() async {
    if (!mounted || _archiveGuidanceBusy) return;
    final g = GuidanceService.instance;
    if (await g.hasSeenPersonalDriveBackupGuidance) return;

    setState(() {
      _archiveGuidanceBusy = true;
      _showBackupGuideTip = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    if (_backupUploadKey.currentContext == null) {
      setState(() => _archiveGuidanceBusy = false);
      return;
    }

    final coach = buildSingleStepArchiveGuidance(
      context: context,
      targetKey: _backupUploadKey,
      identify: 'personal_drive_backup_upload',
      contentAlign: ContentAlign.bottom,
      contentPadding: const EdgeInsets.fromLTRB(20, 72, 20, 28),
      radius: 22,
      paddingFocus: 6,
      body: context.l10n.guidancePersonalDriveBackup,
      onCompleted: () async {
        await g.setPersonalDriveBackupGuidanceSeen();
        if (mounted) {
          setState(() {
            _archiveGuidanceBusy = false;
            _showBackupGuideTip = false;
            _guidanceEpoch++;
          });
        }
      },
    );
    coach.show(context: context);
  }

  void _enqueueGuidance(List<Roll> rolls, List<Roll> visibleRolls) {
    final pendingSync = ref.read(syncGuidanceRollIdProvider);
    final pendingNewRoll = ref.read(newRollGuidanceRollIdProvider);
    final sig = Object.hash(
      rolls.length,
      _guidanceRollsSignature(rolls),
      visibleRolls.length,
      _guidanceRollsSignature(visibleRolls),
      pendingSync ?? '',
      pendingNewRoll ?? '',
      _newRollGuidanceTargetRollId ?? '',
      _guidanceEpoch,
    );
    if (_guidanceSignature == sig) return;
    _guidanceSignature = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _scheduleNewRollShootingIntro(rolls, visibleRolls);
      if (!mounted) return;
      await _scheduleArchiveGuidance(rolls, visibleRolls);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rollsAsync = ref.watch(dashboardRollsProvider);
    final l10n = context.l10n;
    ref.listen(userProfileProvider, (prev, next) {
      next.whenData((_) => _maybeShowTrialPaywall());
    });
    _maybeShowTrialPaywall();

    return HalideScaffold(
      backgroundColor: GuidanceTokens.zinc950(context),
      appBar: AppBar(
        title: Text(
          l10n.archiveTitle,
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: HalideColors.of(context).textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: HalideColors.of(context).textPrimary,
        iconTheme: IconThemeData(color: HalideColors.of(context).textPrimary, size: 26),
        actions: [
          IconButton(
            key: _backupUploadKey,
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Backup to Personal Drive',
            onPressed: () {
              unawaited(_dismissBackupGuideTip());
              context.push('/personal-drive-backup');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.openNewRoll,
            onPressed: _showAddRollDialog,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () async {
              await context.push('/profile');
              if (!mounted) return;
              ref.invalidate(dashboardRollsProvider);
            },
          ),
        ],
      ),
      child: rollsAsync.when(
        data: (rolls) {
          final filtered = _sortRollsForDisplay(
            _filterRolls(rolls, _listFilter),
          );

          _enqueueGuidance(rolls, filtered);

          if (filtered.isEmpty) {
            final emptyBody = _buildEmptyOrNoMatch(rolls.isEmpty, l10n);
            if (rolls.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildStatusFilter(l10n),
                  ),
                  Expanded(child: emptyBody),
                ],
              );
            }
            return emptyBody;
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(dashboardRollsProvider),
            child: ListView(
              controller: _archiveListScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildStatusFilter(l10n),
                if (_showBackupGuideTip) ...[
                  const SizedBox(height: 14),
                  _BackupGuideTip(
                    body: l10n.archiveBackupGuideBody,
                    onDismiss: () => unawaited(_dismissBackupGuideTip()),
                    onTap: () {
                      unawaited(_dismissBackupGuideTip());
                      context.push('/personal-drive-backup');
                    },
                  ),
                ],
                _buildActiveSyncBanner(),
                const SizedBox(height: 16),
                ...List.generate(filtered.length, (index) {
                  final roll = filtered[index];
                  final isTarget = roll.id == _guidanceTargetRollId;
                  final isNewRollIntro = roll.id == _newRollGuidanceTargetRollId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await context.push('/roll/${roll.id}');
                        if (!mounted) return;
                        ref.invalidate(dashboardRollsProvider);
                      },
                      child: RollCard(
                        roll: roll,
                        guidanceStatusKey: isNewRollIntro
                            ? _shootingIntroStatusKey
                            : (isTarget && _highlightStatusKey ? _guidanceStatusKey : null),
                        guidanceLinkSyncKey:
                            isNewRollIntro ? null : (isTarget && _highlightLinkSyncKey ? _guidanceLinkSyncKey : null),
                        guidanceExifKey: isNewRollIntro ? _shootingIntroExifKey : null,
                        guidanceViewLogsKey: isNewRollIntro ? _shootingIntroViewLogsKey : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: HalideColors.of(context).slateTeal, strokeWidth: 2),
        ),
        error: (err, stack) => _ErrorState(
          error: err.toString(),
          onRetry: () => ref.refresh(dashboardRollsProvider),
        ),
      ),
    );
  }

  List<Roll> _filterRolls(List<Roll> rolls, _ArchiveListFilter filter) {
    switch (filter) {
      case _ArchiveListFilter.all:
        return rolls.where((r) => r.status != RollStatus.archived).toList();
      case _ArchiveListFilter.inProgress:
        return rolls
            .where((r) =>
                r.status == RollStatus.shooting ||
                r.status == RollStatus.lab ||
                r.status == RollStatus.syncing)
            .toList();
      case _ArchiveListFilter.archived:
        return rolls.where((r) => r.status == RollStatus.archived).toList();
    }
  }

  /// Scanned rolls with thumbnails first so the archive feels alive on open.
  List<Roll> _sortRollsForDisplay(List<Roll> rolls) {
    final sorted = List<Roll>.from(rolls);
    sorted.sort((a, b) {
      final visual = _rollVisualScore(b).compareTo(_rollVisualScore(a));
      if (visual != 0) return visual;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int _rollVisualScore(Roll roll) {
    var score = roll.imageUrls.length * 10;
    switch (roll.status) {
      case RollStatus.scanned:
        score += 5;
        break;
      case RollStatus.syncing:
        score += 3;
        break;
      case RollStatus.lab:
        score += 2;
        break;
      case RollStatus.shooting:
        score += 1;
        break;
      case RollStatus.archived:
        break;
    }
    return score;
  }

  Widget _buildStatusFilter(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: l10n.filterAll,
            selected: _listFilter == _ArchiveListFilter.all,
            onTap: () => setState(() => _listFilter = _ArchiveListFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.filterInProgress,
            selected: _listFilter == _ArchiveListFilter.inProgress,
            onTap: () => setState(() => _listFilter = _ArchiveListFilter.inProgress),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.filterArchived,
            selected: _listFilter == _ArchiveListFilter.archived,
            onTap: () => setState(() => _listFilter = _ArchiveListFilter.archived),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSyncBanner() {
    final freeSync = ref.watch(freeLabDriveSyncControllerProvider);
    final backup = ref.watch(personalDriveBackupControllerProvider);

    if (freeSync.isRunning) {
      return SyncProgressBanner(
        padding: const EdgeInsets.only(top: 14),
        label: freeSync.progressLabel.isNotEmpty
            ? freeSync.progressLabel
            : 'Downloading lab scans…',
        progress: freeSync.progress,
        accentColor: Colors.blueAccent,
        compact: true,
      );
    }

    if (backup.isRunning || backup.isStarting) {
      final progress = backup.bannerProgress;
      final label = backup.freeUploadingRollId != null && backup.freeFrameTotal > 0
          ? 'Backing up — frame ${backup.freeFrameDone}/${backup.freeFrameTotal}'
          : 'Backing up rolls to Google Drive…';
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: GestureDetector(
          onTap: () => context.push('/personal-drive-backup'),
          child: SyncProgressBanner(
            label: label,
            progress: progress,
            compact: true,
          ),
        ),
      );
    }

    final rolls = ref.watch(dashboardRollsProvider).asData?.value;
    final syncing = rolls?.any((r) => r.status == RollStatus.syncing) ?? false;
    if (syncing) {
      return const SyncProgressBanner(
        padding: EdgeInsets.only(top: 14),
        label: 'Syncing scans from Google Drive…',
        progress: null,
        accentColor: Colors.blueAccent,
        compact: true,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyOrNoMatch(bool noRollsAtAll, AppLocalizations l10n) {
    if (noRollsAtAll) {
      return _EmptyState(onAddFirstRoll: _showAddRollDialog, l10n: l10n);
    }
    final filterLabel = switch (_listFilter) {
      _ArchiveListFilter.all => 'rolls',
      _ArchiveListFilter.inProgress => 'in-progress',
      _ArchiveListFilter.archived => 'archived',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 48, color: HalideColors.of(context).steel),
            SizedBox(height: 16),
            Text(
              'No $filterLabel rolls',
              textAlign: TextAlign.center,
              style: TextStyle(color: HalideColors.of(context).textMuted(), fontSize: 16),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _listFilter = _ArchiveListFilter.all),
              child: Text(l10n.showAllRolls, style: TextStyle(color: HalideColors.of(context).textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupGuideTip extends StatelessWidget {
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _BackupGuideTip({
    required this.body,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_upload_outlined, color: colors.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  body,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
                tooltip: context.l10n.guidanceGotIt,
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? HalideColors.of(context).slateTeal.withValues(alpha: 0.35)
              : HalideColors.of(context).glassFill(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? HalideColors.of(context).sage.withValues(alpha: 0.5) : HalideColors.of(context).borderSubtle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? HalideColors.of(context).textPrimary : HalideColors.of(context).textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddFirstRoll;
  final AppLocalizations l10n;

  const _EmptyState({Key? key, required this.onAddFirstRoll, required this.l10n}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_roll_outlined, size: 64, color: HalideColors.of(context).steel),
              SizedBox(height: 20),
              Text(
                l10n.noRollsYet,
                style: TextStyle(color: HalideColors.of(context).textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Track a roll from shoot to scan — log frames, sync lab scans, and browse your gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HalideColors.of(context).textSecondary),
              ),
              SizedBox(height: 24),
              _LifecycleHintRow(l10n: l10n),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAddFirstRoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HalideColors.of(context).ash,
                  foregroundColor: HalideColors.of(context).textOnLight,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(halideCaps(l10n.loadYourFirstRoll)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifecycleHintRow extends StatelessWidget {
  final AppLocalizations l10n;

  const _LifecycleHintRow({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    final steps = [
      _LifecycleStep(label: l10n.lifecycleShoot, color: colors.slateTeal),
      _LifecycleStep(label: l10n.lifecycleLab, color: colors.sage),
      _LifecycleStep(label: l10n.lifecycleScan, color: colors.ash),
      _LifecycleStep(label: l10n.lifecycleArchive, color: colors.steel),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Icon(
                Icons.arrow_forward,
                size: 14,
                color: HalideColors.of(context).steel.withValues(alpha: 0.45),
              ),
            ),
          steps[i],
        ],
      ],
    );
  }
}

class _LifecycleStep extends StatelessWidget {
  final String label;
  final Color color;

  const _LifecycleStep({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              label[0],
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({Key? key, required this.error, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 20),
              Text(
                l10n.somethingWentWrong,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(halideCaps(l10n.retry)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
