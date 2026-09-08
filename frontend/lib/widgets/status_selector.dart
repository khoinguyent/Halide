import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../models/roll_status.dart';
import '../core/theme/halide_colors.dart';
import '../core/theme/roll_status_colors.dart';

class StatusSelector extends StatefulWidget {
  final RollStatus currentStatus;
  final Future<bool> Function(RollStatus) onStatusSelected;

  const StatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  State<StatusSelector> createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<StatusSelector> {
  bool _isBusy = false;

  /// User-pickable lifecycle (syncing is system-only during Drive import).
  static const List<RollStatus> _userStatuses = [
    RollStatus.shooting,
    RollStatus.lab,
    RollStatus.scanned,
    RollStatus.archived,
  ];

  static int _currentIndex(RollStatus current) {
    if (current == RollStatus.syncing) {
      return _userStatuses.indexOf(RollStatus.lab);
    }
    final i = _userStatuses.indexOf(current);
    return i >= 0 ? i : 0;
  }

  static int _forwardStartIndex(RollStatus current) {
    if (current == RollStatus.syncing) {
      return _userStatuses.indexOf(RollStatus.scanned);
    }
    return _currentIndex(current);
  }

  Color _statusColor(RollStatus status, HalideColors colors) =>
      RollStatusColors.forStatus(status, colors);

  static String _statusDescription(RollStatus status, AppLocalizations l10n) {
    switch (status) {
      case RollStatus.shooting:
        return l10n.statusDescShooting;
      case RollStatus.lab:
        return l10n.statusDescLab;
      case RollStatus.scanned:
        return l10n.statusDescScanned;
      case RollStatus.archived:
        return l10n.statusDescArchived;
      case RollStatus.syncing:
        return l10n.statusDescSyncing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final currentIndex = _currentIndex(widget.currentStatus);
    final startIndex = _forwardStartIndex(widget.currentStatus);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: BoxDecoration(
        color: HalideColors.of(context).surfaceSheet,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(color: HalideColors.of(context).glassBorder(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            halideCaps(l10n.updateRollStatus),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: HalideColors.of(context).textPrimary,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _LifecycleProgressStrip(
            statuses: _userStatuses,
            currentIndex: currentIndex,
            effectiveStatus: widget.currentStatus,
            l10n: l10n,
          ),
          const SizedBox(height: 24),
          ..._userStatuses.asMap().entries.map((entry) {
            final index = entry.key;
            final status = entry.value;
            final isSelected = status == widget.currentStatus ||
                (widget.currentStatus == RollStatus.syncing &&
                    status == RollStatus.lab);
            final isPast = index < startIndex;
            final isFuture = index > startIndex &&
                widget.currentStatus != RollStatus.syncing;
            final canSelect = !isPast && !isSelected && !_isBusy;
            final color = _statusColor(status, colors);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canSelect
                      ? () async {
                          setState(() => _isBusy = true);
                          try {
                            final success =
                                await widget.onStatusSelected(status);
                            if (!mounted) return;
                            if (success) {
                              Navigator.of(context).pop();
                            } else {
                              setState(() => _isBusy = false);
                            }
                          } catch (_) {
                            if (mounted) setState(() => _isBusy = false);
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: isPast ? 0.45 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.18)
                            : HalideColors.of(context).glassFill(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? color.withValues(alpha: 0.5)
                              : HalideColors.of(context).glassBorder(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPast
                                ? Icons.check_circle_outline
                                : isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                            size: 20,
                            color: isPast
                                ? HalideColors.of(context).steel
                                : isSelected
                                    ? color
                                    : HalideColors.of(context).iconMuted(),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  halideCaps(status.localizedLabel(l10n)),
                                  style: TextStyle(
                                    color: isSelected ? color : HalideColors.of(context).textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  isPast
                                      ? l10n.alreadyPassed
                                      : _statusDescription(status, l10n),
                                  style: TextStyle(
                                    color: HalideColors.of(context).textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check, color: color, size: 20)
                          else if (canSelect && !isFuture)
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: color.withOpacity(0.8),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_isBusy)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HalideColors.of(context).steel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LifecycleProgressStrip extends StatelessWidget {
  final List<RollStatus> statuses;
  final int currentIndex;
  final RollStatus effectiveStatus;
  final AppLocalizations l10n;

  const _LifecycleProgressStrip({
    required this.statuses,
    required this.currentIndex,
    required this.effectiveStatus,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    Color statusColor(RollStatus s) => RollStatusColors.forStatus(s, colors);
    return Row(
      children: [
        for (var i = 0; i < statuses.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIndex
                    ? statusColor(statuses[i - 1]).withValues(alpha: 0.6)
                    : colors.glassBorder(0.2),
              ),
            ),
          _StepDot(
            label: _shortLabel(statuses[i], l10n),
            color: statusColor(statuses[i]),
            isComplete: i < currentIndex,
            isCurrent: i == currentIndex,
            isSyncing: effectiveStatus == RollStatus.syncing && i == 1,
          ),
        ],
      ],
    );
  }

  String _shortLabel(RollStatus s, AppLocalizations l10n) {
    switch (s) {
      case RollStatus.shooting:
        return l10n.lifecycleShoot;
      case RollStatus.lab:
        return l10n.lifecycleLab;
      case RollStatus.scanned:
        return l10n.lifecycleScan;
      case RollStatus.archived:
        return l10n.lifecycleDone;
      case RollStatus.syncing:
        return l10n.lifecycleSync;
    }
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final Color color;
  final bool isComplete;
  final bool isCurrent;
  final bool isSyncing;

  const _StepDot({
    required this.label,
    required this.color,
    required this.isComplete,
    required this.isCurrent,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = isComplete || isCurrent;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color.withValues(alpha: 0.2) : HalideColors.of(context).glassFill(0.06),
            border: Border.all(
              color: active ? color : HalideColors.of(context).borderSubtle,
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Center(
            child: isComplete
                ? Icon(Icons.check, size: 14, color: color)
                : isSyncing
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent ? color : Colors.transparent,
                        ),
                      ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: active ? color : HalideColors.of(context).steel,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
