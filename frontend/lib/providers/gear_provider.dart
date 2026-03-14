import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gear_service.dart';
import '../providers/auth_provider.dart';
import '../models/camera.dart';
import '../models/gear_status.dart';

final gearServiceProvider = Provider<GearService>((ref) => GearService());

class UserGearNotifier extends StateNotifier<AsyncValue<List<Camera>>> {
  final Ref ref;

  UserGearNotifier(this.ref) : super(const AsyncValue.loading()) {
    _fetchGear();
  }

  Future<void> _fetchGear() async {
    try {
      final authService = ref.read(authServiceProvider);
      final gearService = ref.read(gearServiceProvider);

      final user = authService.currentUser;
      if (user == null) {
        // Mock data
        state = AsyncValue.data([
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
        ]);
        return;
      }

      final token = await user.getIdToken();
      if (token == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final rawData = await gearService.fetchUserGear(token);
      final cameras = rawData.map((json) => Camera.fromJson(json as Map<String, dynamic>)).toList();
      state = AsyncValue.data(cameras);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  void updateCameraStatus(String id, GearStatus newStatus) {
    if (state.value == null) return;
    final cameras = state.value!;
    final index = cameras.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final List<Camera> updatedCameras = List.from(cameras);
    updatedCameras[index] = cameras[index].copyWith(status: newStatus);
    state = AsyncValue.data(updatedCameras);

    // In a real app we would call gearService.updateCamera(id, newStatus) here
  }

  void addCameraImages(String id, List<String> newPaths) {
    if (state.value == null) return;
    final cameras = state.value!;
    final index = cameras.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final camera = cameras[index];
    final updatedUrls = List<String>.from(camera.imageUrls)..addAll(newPaths);

    final List<Camera> updatedCameras = List.from(cameras);
    updatedCameras[index] = camera.copyWith(imageUrls: updatedUrls);
    state = AsyncValue.data(updatedCameras);
    
    // In a real app we'd trigger an API update as well if needed
  }
}

final userGearProvider = StateNotifierProvider<UserGearNotifier, AsyncValue<List<Camera>>>((ref) {
  return UserGearNotifier(ref);
});

final cameraProvider = Provider.family<Camera?, String>((ref, id) {
  final gearList = ref.watch(userGearProvider).value;
  if (gearList == null) return null;
  return gearList.firstWhere(
    (camera) => camera.id == id,
    orElse: () => Camera(
      id: id,
      nickname: 'Unknown Camera',
      brand: 'Unknown',
      model: 'Model',
    ),
  );
});
  
