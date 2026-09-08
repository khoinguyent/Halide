import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/halide_colors.dart';
import '../core/widgets/glass_panel.dart';
import '../core/widgets/halide_scaffold.dart';
import '../models/shooting_matrix.dart';
import '../providers/analytics_provider.dart';
import '../widgets/analytics/exposure_matrix_widget.dart';

class ShootingAnalyticsView extends ConsumerWidget {
  const ShootingAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final analyticsAsync = ref.watch(shootingAnalyticsProvider);
    final selectedDate = ref.watch(selectedAnalyticsDayProvider);

    return HalideScaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          color: colors.textPrimary,
        ),
        centerTitle: true,
        title: Text(
          l10n.analyticsTitle,
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            tooltip: l10n.refreshTooltip,
            icon: Icon(Icons.refresh, color: colors.textSecondary),
            onPressed: () {
              ref.invalidate(shootingAnalyticsProvider);
              ref.read(selectedAnalyticsDayProvider.notifier).select(null);
            },
          ),
        ],
      ),
      child: analyticsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.light),
        ),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(shootingAnalyticsProvider),
        ),
        data: (data) => _AnalyticsBody(
          data: data,
          selectedDate: selectedDate,
          onDaySelected: (date) =>
              ref.read(selectedAnalyticsDayProvider.notifier).select(date),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.light, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.couldNotLoadAnalytics,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.tryAgain, style: TextStyle(color: colors.light)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsBody extends ConsumerWidget {
  final ShootingMatrixResponse data;
  final String? selectedDate;
  final ValueChanged<String?> onDaySelected;

  const _AnalyticsBody({
    required this.data,
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final periodLabel = _periodLabel(data.matrix, l10n);

    return RefreshIndicator(
      color: colors.light,
      onRefresh: () async {
        ref.invalidate(shootingAnalyticsProvider);
        await ref.read(shootingAnalyticsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              periodLabel,
              style: TextStyle(
                fontSize: 11,
                color: colors.textPrimary.withValues(alpha: 0.4),
              ),
            ),
            if (data.totals.totalShots == 0) ...[
              const SizedBox(height: 12),
              const _EmptyAnalyticsBanner(),
            ],
            const SizedBox(height: 16),
            _SectionHeader(
              title: l10n.exposureMatrix,
              trailing: l10n.shotsCount(data.totals.totalShots),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              borderRadius: 16,
              child: ExposureMatrixWidget(
                matrix: data.matrix,
                selectedDate: selectedDate,
                onDaySelected: onDaySelected,
              ),
            ),
            const SizedBox(height: 16),
            _StatsGrid(data: data),
            const SizedBox(height: 16),
            if (data.emulsionBreakdown.isNotEmpty) ...[
              _BreakdownCard(
                title: l10n.favoriteEmulsion,
                items: data.emulsionBreakdown,
              ),
              const SizedBox(height: 12),
            ],
            if (data.hardwareBreakdown.isNotEmpty)
              _BreakdownCard(
                title: l10n.activeHardware,
                items: data.hardwareBreakdown,
              ),
            const SizedBox(height: 12),
            _LightingCard(insight: data.lightingInsight),
          ],
        ),
      ),
    );
  }

  String _periodLabel(List<DailyCount> matrix, AppLocalizations l10n) {
    if (matrix.isEmpty) return l10n.last365Days;
    final months = monthLabels(l10n);
    final start = DateTime.parse(matrix.first.date);
    final end = DateTime.parse(matrix.last.date);
    return l10n.periodRange(
      '${months[start.month - 1]} ${start.year}',
      '${months[end.month - 1]} ${end.year}',
    );
  }
}

class _EmptyAnalyticsBanner extends StatelessWidget {
  const _EmptyAnalyticsBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.camera_roll_outlined,
            color: colors.textPrimary.withValues(alpha: 0.45),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.noShotsLoggedYear,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: colors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colors.textPrimary.withValues(alpha: 0.45),
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: TextStyle(
            fontSize: 10,
            color: colors.textPrimary.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final ShootingMatrixResponse data;

  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: [
        _StatTile(
          label: l10n.streak,
          value: '${data.streaks.currentStreak}',
          unit: l10n.daysUnit,
          subtitle: l10n.current,
          accent: true,
          icon: Icons.local_fire_department_rounded,
        ),
        _StatTile(
          label: l10n.best,
          value: '${data.streaks.longestStreak}',
          unit: l10n.daysUnit,
          subtitle: l10n.longestStreak,
        ),
        _StatTile(
          label: l10n.total,
          value: '${data.totals.totalShots}',
          unit: '',
          subtitle: l10n.shotsFired,
        ),
        _StatTile(
          label: l10n.active,
          value: '${data.totals.activeDays}',
          unit: l10n.periodDaysOf(data.totals.periodDays),
          subtitle: l10n.activeDays,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String subtitle;
  final bool accent;
  final IconData? icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.subtitle,
    this.accent = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: colors.light),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: colors.textPrimary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: accent ? colors.light : colors.textPrimary,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textPrimary.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: colors.textPrimary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final List<RankedItem> items;

  const _BreakdownCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.textPrimary.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            _BreakdownRow(item: items[i], highlight: i == 0),
            if (i < items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final RankedItem item;
  final bool highlight;

  const _BreakdownRow({required this.item, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final colors = HalideColors.of(context);
    final barColor =
        highlight ? colors.light : colors.textPrimary.withValues(alpha: 0.2);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      highlight ? FontWeight.w600 : FontWeight.w400,
                  color: highlight
                      ? colors.textPrimary
                      : colors.textPrimary.withValues(alpha: 0.65),
                ),
              ),
            ),
            Text(
              '${item.percentage.toStringAsFixed(item.percentage % 1 == 0 ? 0 : 1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? colors.light
                    : colors.textPrimary.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: (item.percentage / 100).clamp(0, 1),
            minHeight: 3,
            backgroundColor: colors.textPrimary.withValues(alpha: 0.08),
            color: barColor,
          ),
        ),
      ],
    );
  }
}

class _LightingCard extends StatelessWidget {
  final LightingInsight insight;

  const _LightingCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final pct = insight.goldenHourPercentage;
    final narrative = pct >= 50
        ? l10n.goldenHourBiasStrong
        : pct >= 25
            ? l10n.goldenHourBiasModerate
            : l10n.goldenHourBiasLow;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.lightingHabit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colors.textPrimary.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.light.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.goldenHour,
                  style: TextStyle(
                    color: colors.light,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: colors.light,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  narrative,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: colors.textPrimary.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            color: colors.textPrimary.withValues(alpha: 0.08),
            height: 1,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.goldenHourShotsSummary(insight.goldenHourShots, insight.totalShots),
            style: TextStyle(
              fontSize: 10,
              color: colors.textPrimary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
