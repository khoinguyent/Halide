import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gear_service.dart';
import '../providers/auth_provider.dart';
import '../models/camera.dart';

final gearServiceProvider = Provider<GearService>((ref) => GearService());

final userGearProvider = FutureProvider<List<Camera>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];

  final gearService = ref.watch(gearServiceProvider);
  final token = await user.getIdToken(true);
  if (token == null || token.isEmpty) return [];

  final rawData = await gearService.fetchUserGear(token);
  return rawData.map((json) => Camera.fromJson(json as Map<String, dynamic>)).toList();
});
