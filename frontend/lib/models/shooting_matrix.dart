class DailyCount {
  final String date;
  final int count;

  const DailyCount({required this.date, required this.count});

  factory DailyCount.fromJson(Map<String, dynamic> json) {
    return DailyCount(
      date: json['date'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StreakAnalytics {
  final int currentStreak;
  final int longestStreak;

  const StreakAnalytics({
    required this.currentStreak,
    required this.longestStreak,
  });

  factory StreakAnalytics.fromJson(Map<String, dynamic> json) {
    return StreakAnalytics(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
    );
  }
}

class RankedItem {
  final String name;
  final int count;
  final double percentage;

  const RankedItem({
    required this.name,
    required this.count,
    required this.percentage,
  });

  factory RankedItem.fromJson(Map<String, dynamic> json) {
    return RankedItem(
      name: json['name'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TopEmulsion {
  final String name;
  final String brand;
  final int count;
  final double percentage;

  const TopEmulsion({
    required this.name,
    required this.brand,
    required this.count,
    required this.percentage,
  });

  factory TopEmulsion.fromJson(Map<String, dynamic> json) {
    return TopEmulsion(
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TopHardware {
  final String name;
  final int count;
  final double percentage;

  const TopHardware({
    required this.name,
    required this.count,
    required this.percentage,
  });

  factory TopHardware.fromJson(Map<String, dynamic> json) {
    return TopHardware(
      name: json['name'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LightingInsight {
  final double goldenHourPercentage;
  final int goldenHourShots;
  final int totalShots;

  const LightingInsight({
    required this.goldenHourPercentage,
    required this.goldenHourShots,
    required this.totalShots,
  });

  factory LightingInsight.fromJson(Map<String, dynamic> json) {
    return LightingInsight(
      goldenHourPercentage: (json['golden_hour_percentage'] as num?)?.toDouble() ?? 0,
      goldenHourShots: (json['golden_hour_shots'] as num?)?.toInt() ?? 0,
      totalShots: (json['total_shots'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShootingMatrixTotals {
  final int totalShots;
  final int activeDays;
  final int periodDays;

  const ShootingMatrixTotals({
    required this.totalShots,
    required this.activeDays,
    required this.periodDays,
  });

  factory ShootingMatrixTotals.fromJson(Map<String, dynamic> json) {
    return ShootingMatrixTotals(
      totalShots: (json['total_shots'] as num?)?.toInt() ?? 0,
      activeDays: (json['active_days'] as num?)?.toInt() ?? 0,
      periodDays: (json['period_days'] as num?)?.toInt() ?? 365,
    );
  }
}

class ShootingMatrixResponse {
  final List<DailyCount> matrix;
  final StreakAnalytics streaks;
  final TopEmulsion? topEmulsion;
  final TopHardware? topHardware;
  final List<RankedItem> emulsionBreakdown;
  final List<RankedItem> hardwareBreakdown;
  final LightingInsight lightingInsight;
  final ShootingMatrixTotals totals;
  final String timezone;

  const ShootingMatrixResponse({
    required this.matrix,
    required this.streaks,
    this.topEmulsion,
    this.topHardware,
    required this.emulsionBreakdown,
    required this.hardwareBreakdown,
    required this.lightingInsight,
    required this.totals,
    required this.timezone,
  });

  factory ShootingMatrixResponse.fromJson(Map<String, dynamic> json) {
    return ShootingMatrixResponse(
      matrix: (json['matrix'] as List<dynamic>? ?? [])
          .map((e) => DailyCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      streaks: StreakAnalytics.fromJson(json['streaks'] as Map<String, dynamic>),
      topEmulsion: json['top_emulsion'] != null
          ? TopEmulsion.fromJson(json['top_emulsion'] as Map<String, dynamic>)
          : null,
      topHardware: json['top_hardware'] != null
          ? TopHardware.fromJson(json['top_hardware'] as Map<String, dynamic>)
          : null,
      emulsionBreakdown: (json['emulsion_breakdown'] as List<dynamic>? ?? [])
          .map((e) => RankedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      hardwareBreakdown: (json['hardware_breakdown'] as List<dynamic>? ?? [])
          .map((e) => RankedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      lightingInsight: LightingInsight.fromJson(json['lighting_insight'] as Map<String, dynamic>),
      totals: ShootingMatrixTotals.fromJson(json['totals'] as Map<String, dynamic>),
      timezone: json['timezone'] as String? ?? 'UTC',
    );
  }
}
