import 'package:flutter/material.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';

import '../../core/theme/halide_colors.dart';
import '../../models/shooting_matrix.dart';

List<String> monthLabels(AppLocalizations l10n) => [
      l10n.monthJan,
      l10n.monthFeb,
      l10n.monthMar,
      l10n.monthApr,
      l10n.monthMay,
      l10n.monthJun,
      l10n.monthJul,
      l10n.monthAug,
      l10n.monthSep,
      l10n.monthOct,
      l10n.monthNov,
      l10n.monthDec,
    ];

List<String> dowLabels(AppLocalizations l10n) => [
      l10n.dowSun,
      l10n.dowMon,
      l10n.dowTue,
      l10n.dowWed,
      l10n.dowThu,
      l10n.dowFri,
      l10n.dowSat,
    ];

int heatLevel(int count) {
  if (count <= 0) return 0;
  if (count <= 3) return 1;
  if (count <= 9) return 2;
  if (count <= 17) return 3;
  return 4;
}

List<Color> buildHeatColors(Color highlight, Color base) => [
      base,
      highlight.withValues(alpha: 0.15),
      highlight.withValues(alpha: 0.35),
      highlight.withValues(alpha: 0.65),
      highlight,
    ];

Color heatColorFromPalette(int count, List<Color> heatColors) =>
    heatColors[heatLevel(count)];

String sessionLabel(int count, AppLocalizations l10n) {
  if (count >= 18) return l10n.sessionFullRoll;
  if (count >= 10) return l10n.sessionHeavy;
  if (count >= 4) return l10n.sessionActive;
  if (count > 0) return l10n.sessionLight;
  return l10n.sessionNoShots;
}

class DailyGridCell {
  final String date;
  final int count;

  const DailyGridCell({required this.date, required this.count});
}

List<List<DailyGridCell?>> buildWeekColumns(List<DailyCount> matrix) {
  if (matrix.isEmpty) return [];

  final first = DateTime.parse(matrix.first.date);
  final leading = first.weekday % 7;

  final cells = <DailyGridCell?>[
    for (var i = 0; i < leading; i++) null,
    for (final day in matrix) DailyGridCell(date: day.date, count: day.count),
  ];

  while (cells.length % 7 != 0) {
    cells.add(null);
  }

  final columns = <List<DailyGridCell?>>[];
  for (var i = 0; i < cells.length; i += 7) {
    columns.add(cells.sublist(i, i + 7));
  }
  return columns;
}

class ExposureMatrixWidget extends StatelessWidget {
  final List<DailyCount> matrix;
  final String? selectedDate;
  final ValueChanged<String?> onDaySelected;

  const ExposureMatrixWidget({
    super.key,
    required this.matrix,
    required this.selectedDate,
    required this.onDaySelected,
  });

  static const double _cell = 11;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final heatColors = buildHeatColors(colors.light, colors.background);
    final months = monthLabels(l10n);
    final dows = dowLabels(l10n);

    final columns = buildWeekColumns(matrix);
    final monthMarkers = <int, String>{};
    var lastMonth = -1;

    for (var ci = 0; ci < columns.length; ci++) {
      for (final cell in columns[ci]) {
        if (cell != null) {
          final month = DateTime.parse(cell.date).month - 1;
          if (month != lastMonth) {
            monthMarkers[ci] = months[month];
            lastMonth = month;
          }
          break;
        }
      }
    }

    DailyCount? selectedDay;
    if (selectedDate != null) {
      for (final day in matrix) {
        if (day.date == selectedDate) {
          selectedDay = day;
          break;
        }
      }
    }

    final mutedText = colors.textPrimary.withValues(alpha: 0.28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Row(
                  children: [
                    for (var ci = 0; ci < columns.length; ci++) ...[
                      SizedBox(
                        width: _cell,
                        height: 14,
                        child: monthMarkers[ci] != null
                            ? Text(
                                monthMarkers[ci]!,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: colors.textPrimary.withValues(alpha: 0.35),
                                ),
                              )
                            : null,
                      ),
                      if (ci < columns.length - 1) const SizedBox(width: _gap),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      for (var i = 0; i < 7; i++)
                        SizedBox(
                          width: 14,
                          height: _cell,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: i.isOdd
                                ? Text(
                                    dows[i],
                                    style: TextStyle(fontSize: 7, color: mutedText),
                                  )
                                : null,
                          ),
                        ),
                      for (var i = 0; i < 6; i++) const SizedBox(height: _gap),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Row(
                    children: [
                      for (var ci = 0; ci < columns.length; ci++) ...[
                        Column(
                          children: [
                            for (var ri = 0; ri < columns[ci].length; ri++) ...[
                              _HeatCell(
                                cell: columns[ci][ri],
                                selected: columns[ci][ri]?.date == selectedDate,
                                heatColors: heatColors,
                                highlightColor: colors.light,
                                onTap: () {
                                  final date = columns[ci][ri]?.date;
                                  if (date == null) return;
                                  onDaySelected(selectedDate == date ? null : date);
                                },
                              ),
                              if (ri < columns[ci].length - 1) const SizedBox(height: _gap),
                            ],
                          ],
                        ),
                        if (ci < columns.length - 1) const SizedBox(width: _gap),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(l10n.heatLess, style: TextStyle(fontSize: 9, color: mutedText)),
            const SizedBox(width: 6),
            for (final color in heatColors)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: colors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
              ),
            const SizedBox(width: 3),
            Text(l10n.heatMore, style: TextStyle(fontSize: 9, color: mutedText)),
          ],
        ),
        const SizedBox(height: 10),
        Divider(color: colors.textPrimary.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 10),
        if (selectedDay != null)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: heatColorFromPalette(selectedDay.count, heatColors),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selectedDay.date,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selectedDay.count == 0
                    ? l10n.noExposuresRecorded
                    : l10n.exposureCount(selectedDay.count),
                style: TextStyle(
                  color: colors.textPrimary.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.light.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  sessionLabel(selectedDay.count, l10n),
                  style: TextStyle(
                    color: colors.light,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            l10n.tapCellToInspect,
            style: TextStyle(
              fontSize: 11,
              color: colors.textPrimary.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

class _HeatCell extends StatelessWidget {
  final DailyGridCell? cell;
  final bool selected;
  final List<Color> heatColors;
  final Color highlightColor;
  final VoidCallback onTap;

  const _HeatCell({
    required this.cell,
    required this.selected,
    required this.heatColors,
    required this.highlightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cell == null) {
      return const SizedBox(
        width: ExposureMatrixWidget._cell,
        height: ExposureMatrixWidget._cell,
      );
    }

    final level = heatLevel(cell!.count);
    final color = heatColorFromPalette(cell!.count, heatColors);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ExposureMatrixWidget._cell,
        height: ExposureMatrixWidget._cell,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: selected ? Border.all(color: Colors.white, width: 1.5) : null,
          boxShadow: level == 4
              ? [
                  BoxShadow(
                    color: highlightColor.withValues(alpha: 0.35),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
