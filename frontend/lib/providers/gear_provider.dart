import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gear_service.dart';
import '../providers/auth_provider.dart';
import '../models/camera.dart';

final gearServiceProvider = Provider<GearService>((ref) => GearService());

final userGearProvider = FutureProvider<List<Camera>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final gearService = ref.watch(gearServiceProvider);
  
  final user = authService.currentUser;
  if (user == null) {
     // Return mock data for development
    return [
      Camera(
        id: '1',
        nickname: 'Main Shooter',
        brand: 'Leica',
        model: 'M6',
        serialNumber: '2468135',
        lenses: [],
      ),
      Camera(
        id: '2',
        nickname: 'Pocket Beast',
        brand: 'Contax',
        model: 'T2',
        serialNumber: '9876543',
        lenses: [],
      ),
    ];
  }
  
  final token = await user.getIdToken();
  if (token == null) return [];
  
  final rawData = await gearService.fetchUserGear(token);
  return rawData.map((json) => Camera.fromJson(json as Map<String, dynamic>)).toList();
});
