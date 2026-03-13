import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gear_service.dart';
import '../providers/auth_provider.dart';

final gearServiceProvider = Provider<GearService>((ref) => GearService());

final userGearProvider = FutureProvider<List<dynamic>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final gearService = ref.watch(gearServiceProvider);
  
  final user = authService.currentUser;
  if (user == null) return [];
  
  final token = await user.getIdToken();
  if (token == null) return [];
  
  return await gearService.fetchUserGear(token);
});
