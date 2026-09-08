import 'package:flutter/material.dart';

import '../core/theme/halide_colors.dart';

/// Shared sync/backup progress: animated bar + optional percentage.
///
/// Pass [progress] in `0..1` for a determinate fill, or `null` for an
/// indeterminate (moving) bar while work is starting / unknown.
class SyncProgressBanner extends StatelessWidget {
  final String label;
  final double? progress;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const SyncProgressBanner({
    super.key,
    required this.label,
    this.progress,
    this.accentColor,
    this.padding = EdgeInsets.zero,
    this.compact = false,
  });

  /// 0–100 for display; null when indeterminate.
  int? get percent {
    final p = progress;
    if (p == null) return null;
    return (p.clamp(0.0, 1.0) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    final accent = accentColor ?? colors.accent;
    final pct = percent;

    return Padding(
      padding: padding,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: compact ? 12 : 14,
                  height: compact ? 12 : 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                if (pct != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: accent,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: compact ? 5 : 6,
                backgroundColor: colors.glassFill(0.15),
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact inline progress (e.g. inside a roll card) with % when known.
class SyncProgressInline extends StatelessWidget {
  final String label;
  final double? progress;
  final Color? accentColor;

  const SyncProgressInline({
    super.key,
    required this.label,
    this.progress,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    final accent = accentColor ?? colors.accent;
    final pct = progress == null ? null : (progress!.clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (pct != null)
              Text(
                '$pct%',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: colors.glassFill(0.12),
            color: accent,
          ),
        ),
      ],
    );
  }
}
