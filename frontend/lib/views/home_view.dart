import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../widgets/roll_card.dart';
import '../providers/dashboard_provider.dart';
import 'package:frontend/providers/rolls_provider.dart';
import 'package:frontend/features/rolls/presentation/widgets/add_roll_form.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../models/roll_status.dart';
import '../models/roll.dart';
import '../services/guidance_service.dart';
import '../providers/guidance_pending_provider.dart';
import '../widgets/guidance/lab_drive_sync_guidance.dart';
import '../widgets/guidance/guidance_tokens.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  RollStatus? _statusFilter;

  final GlobalKey _guidanceStatusKey = GlobalKey();
  final GlobalKey _guidanceLinkSyncKey = GlobalKey();
  final ScrollController _archiveListScrollController = ScrollController();

  Object? _guidanceSignature;
  /// Bumped when a coach finishes so the next guidance step can schedule without looping the same step.
  int _guidanceEpoch = 0;
  bool _archiveGuidanceBusy = false;
  /// Which card receives coach keys (only one roll at a time).
  String? _guidanceTargetRollId;
  bool _highlightStatusKey = false;
  bool _highlightLinkSyncKey = false;

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
            setState(() => _statusFilter = null);
            ref.invalidate(dashboardRollsProvider);
          },
        ),
      ),
    );
  }

  static bool _showLinkFetchRow(Roll r) {
    return (r.status == RollStatus.lab || r.status == RollStatus.scanned) && r.imageUrls.isEmpty;
  }

  static bool _hasSavedDriveUrl(Roll r) => (r.driveUrl ?? '').trim().isNotEmpty;

  void _clearGuidanceHighlight() {
    _guidanceTargetRollId = null;
    _highlightStatusKey = false;
    _highlightLinkSyncKey = false;
  }

  Future<void> _scheduleArchiveGuidance(List<Roll> rolls, List<Roll> visibleRolls) async {
    if (!mounted || _archiveGuidanceBusy) return;
    if (rolls.isEmpty || visibleRolls.isEmpty) return;

    final g = GuidanceService.instance;
    final pendingSyncRollId = ref.read(syncGuidanceRollIdProvider);

    // —— Priority 1: after saving Drive URL in the sheet ————————————————
    if (pendingSyncRollId != null) {
      final seenSync = await g.hasSeenSyncAfterLinkGuidance;
      if (seenSync) {
        ref.read(syncGuidanceRollIdProvider.notifier).setPending(null);
      } else {
        Roll? roll;
        for (final r in visibleRolls) {
          if (r.id == pendingSyncRollId) {
            roll = r;
            break;
          }
        }
        if (roll != null && _showLinkFetchRow(roll)) {
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
            targetKey: _guidanceLinkSyncKey,
            identify: 'sync_after_link',
            body:
                'Your Drive link is saved. Tap the highlighted cloud icon to download scans from Google Drive (you can tap again later to refresh).',
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
          return;
        }
        ref.read(syncGuidanceRollIdProvider.notifier).setPending(null);
      }
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
          targetKey: _guidanceStatusKey,
          identify: 'at_lab_badge',
          body:
              'AT LAB means your film is with the lab. When you get a Google Drive link, use the link or cloud icon on the right to add it and sync your scans.',
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
        if (_showLinkFetchRow(r)) {
          linkRowRoll = r;
          break;
        }
      }
      if (linkRowRoll != null) {
        final ur = linkRowRoll;
        final hasUrl = _hasSavedDriveUrl(ur);
        final linkRowBody = hasUrl
            ? 'The cloud icon downloads scans from your saved Drive link. Tap the link icon if you need to change the URL.'
            : 'Tap the highlighted link icon (top right) to paste the Google Drive folder URL when your lab shares it. After saving, the icon becomes a cloud you can tap to download scans.';
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
  }

  void _enqueueGuidance(List<Roll> rolls, List<Roll> visibleRolls) {
    final pending = ref.read(syncGuidanceRollIdProvider);
    final sig = Object.hash(
      rolls.length,
      Object.hashAll(rolls.map((r) => r.id)),
      visibleRolls.length,
      Object.hashAll(visibleRolls.map((r) => r.id)),
      pending ?? '',
      _guidanceEpoch,
    );
    if (_guidanceSignature == sig) return;
    _guidanceSignature = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleArchiveGuidance(rolls, visibleRolls);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rollsAsync = ref.watch(dashboardRollsProvider);

    return HalideScaffold(
      backgroundColor: GuidanceTokens.zinc950,
      appBar: AppBar(
        title: const Text(
          'THE ARCHIVE',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add roll',
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
          final filtered = _statusFilter == null
              ? rolls.where((r) => r.status != RollStatus.archived).toList()
              : rolls.where((r) => r.status == _statusFilter).toList();

          _enqueueGuidance(rolls, filtered);

          if (filtered.isEmpty) {
            return _buildEmptyOrNoMatch(rolls.isEmpty || _statusFilter == null);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(dashboardRollsProvider),
            child: ListView(
              controller: _archiveListScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildStatusFilter(),
                const SizedBox(height: 16),
                ...List.generate(filtered.length, (index) {
                  final roll = filtered[index];
                  final isTarget = roll.id == _guidanceTargetRollId;
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
                        guidanceStatusKey: isTarget && _highlightStatusKey ? _guidanceStatusKey : null,
                        guidanceLinkSyncKey: isTarget && _highlightLinkSyncKey ? _guidanceLinkSyncKey : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (err, stack) => _ErrorState(
          error: err.toString(),
          onRetry: () => ref.refresh(dashboardRollsProvider),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: _statusFilter == null,
            onTap: () => setState(() => _statusFilter = null),
          ),
          const SizedBox(width: 8),
          ...RollStatus.values.map((status) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _FilterChip(
                  label: status.label,
                  selected: _statusFilter == status,
                  onTap: () => setState(() => _statusFilter = status),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyOrNoMatch(bool noRollsAtAll) {
    if (noRollsAtAll) {
      return _EmptyState(onAddFirstRoll: _showAddRollDialog);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'No rolls with status "${_statusFilter?.label ?? 'active'}"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _statusFilter = null),
              child: const Text('Clear filter', style: TextStyle(color: Colors.white70)),
            ),
          ],
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
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.white38 : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
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

  const _EmptyState({Key? key, required this.onAddFirstRoll}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_roll_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 20),
              const Text(
                'No rolls yet',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your first roll of film to start tracking your frames.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAddFirstRoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ADD FIRST ROLL'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({Key? key, required this.error, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
