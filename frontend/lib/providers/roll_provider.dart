import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
import '../services/roll_service.dart';
import 'auth_provider.dart';

final rollServiceProvider = Provider<RollService>((ref) => RollService());

final userRollsProvider = FutureProvider<List<dynamic>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];

  final rollService = ref.watch(rollServiceProvider);
  final token = await user.getIdToken();
  if (token == null) return [];

  return rollService.fetchRolls(token);
});

/// Single roll from API (DB). Use for roll detail screen.
final rollDetailProvider = FutureProvider.family<Roll, String>((ref, rollId) async {
  final user = ref.watch(userProvider);
  if (user == null) throw Exception('Not signed in');

  final rollService = ref.watch(rollServiceProvider);
  final token = await user.getIdToken();
  if (token == null) throw Exception('No token');

  final raw = await rollService.fetchRoll(token, rollId);
  return Roll.fromJson(Map<String, dynamic>.from(raw));
});
