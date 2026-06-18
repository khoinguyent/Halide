import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
import '../models/roll_status.dart';
import '../features/gyro_scan/services/gyro_scan_session_service.dart';
import 'auth_provider.dart';
import 'roll_provider.dart';

final dashboardRollsProvider = FutureProvider<List<Roll>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) {
    return [];
  }

  final token = await user.getIdToken();
  if (token == null) return [];

  final rollService = ref.watch(rollServiceProvider);
  final rawRolls = await rollService.fetchRolls(token);
  final list = rawRolls is List ? rawRolls : [];
  
  final rolls = list
      .map((e) => Roll.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  final reconciled = await GyroScanSessionService.instance.reconcileScannedRolls(
    rolls: rolls,
    token: token,
    rollService: rollService,
  );
  if (reconciled) {
    final refreshed = await rollService.fetchRolls(token);
    final refreshedList = refreshed is List ? refreshed : [];
    return refreshedList
        .map((e) => Roll.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // If any roll is syncing, schedule a refresh in 5 seconds
  final hasSyncing = rolls.any((r) => r.status == RollStatus.syncing);
  if (hasSyncing) {
    final timer = Timer(const Duration(seconds: 5), () {
      ref.invalidateSelf();
    });
    ref.onDispose(() => timer.cancel());
  }

  return rolls;
});
