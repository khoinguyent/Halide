import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/roll.dart';
import '../models/roll_gallery.dart';
import '../services/roll_service.dart';
import '../services/local_image_path_index.dart';
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

/// Resolved gallery URLs + stable [imageIds] for [SyncedImage] (cloud and on-device lab import).
final rollGalleryPairsProvider =
    FutureProvider.family<RollGalleryTriple, String>((ref, rollId) async {
  final roll = await ref.watch(rollDetailProvider(rollId).future);
  return RollGalleryPairs.tripleAsync(roll);
});

/// True when this roll has on-device lab imports (`lab:*` in [LocalImagePathIndex]).
final rollHasLocalLabScansProvider = FutureProvider.family<bool, String>((ref, rollId) async {
  final entries = await LocalImagePathIndex.instance.listLabEntriesSorted(rollId);
  return entries.isNotEmpty;
});
