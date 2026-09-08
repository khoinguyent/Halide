import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shooting_matrix.dart';
import '../services/analytics_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

final shootingAnalyticsProvider = FutureProvider.autoDispose<ShootingMatrixResponse>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  return service.fetchShootingMatrix();
});

class SelectedAnalyticsDayNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? date) => state = date;
}

final selectedAnalyticsDayProvider =
    NotifierProvider<SelectedAnalyticsDayNotifier, String?>(SelectedAnalyticsDayNotifier.new);
