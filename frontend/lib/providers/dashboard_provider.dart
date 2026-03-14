import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
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
  return list
      .map((e) => Roll.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});
