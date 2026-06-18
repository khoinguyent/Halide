import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/free_tier_limits.dart';
import '../core/models/notification_model.dart';
import '../core/providers/notification_provider.dart';
import '../services/gear_service.dart';
import '../providers/auth_provider.dart';
import '../models/camera.dart';
import '../models/lens.dart';
import '../models/gear_status.dart';

final gearServiceProvider = Provider<GearService>((ref) => GearService());

class UserGearNotifier extends AsyncNotifier<List<Camera>> {
  @override
  Future<List<Camera>> build() async {
    try {
      final authService = ref.read(authServiceProvider);
      final gearService = ref.read(gearServiceProvider);

      final user = authService.currentUser;
      if (user == null) {
        return [];
      }

      final token = await user.getIdToken();
      if (token == null) return [];

      final rawData = await gearService.fetchUserGear(token);
      return rawData.map((json) => Camera.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      throw AsyncError(e, stackTrace);
    }
  }

  void updateCameraStatus(String id, GearStatus newStatus) {
    state.whenData((cameras) {
      final index = cameras.indexWhere((c) => c.id == id);
      if (index == -1) return;
      final updated = List<Camera>.from(cameras);
      updated[index] = cameras[index].copyWith(status: newStatus);
      state = AsyncValue.data(updated);
      _persistCameraStatus(id, newStatus);
    });
  }

  void updateCameraDetails(String id, {
    String? nickname,
    String? brand,
    String? model,
    String? serialNumber,
    String? format,
    GearStatus? status,
  }) {
    state.whenData((cameras) {
      final index = cameras.indexWhere((c) => c.id == id);
      if (index == -1) return;
      final c = cameras[index];
      final updated = List<Camera>.from(cameras);
      updated[index] = c.copyWith(
        nickname: nickname ?? c.nickname,
        brand: brand ?? c.brand,
        model: model ?? c.model,
        serialNumber: serialNumber ?? c.serialNumber,
        format: format ?? c.format,
        status: status ?? c.status,
      );
      state = AsyncValue.data(updated);
      _persistCameraDetails(
        id,
        nickname: nickname,
        brand: brand,
        model: model,
        serialNumber: serialNumber,
        format: format,
        status: status,
      );
    });
  }

  Camera? _cameraById(String id) {
    final list = state.value;
    if (list == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Null if allowed; otherwise user-facing block reason.
  String? blockReasonForNewCamera() {
    final plan = ref.read(userPlanProvider);
    final count = state.value?.length ?? 0;
    if (!canAddCameraOnPlan(plan, count)) return freeTierCameraLimitMessage();
    return null;
  }

  /// Null if allowed; otherwise user-facing block reason.
  String? blockReasonForMountLens(String cameraId) {
    final plan = ref.read(userPlanProvider);
    final cam = _cameraById(cameraId);
    if (cam == null) return null;
    if (!canMountLensOnCamera(plan, cam.lenses.length)) return freeTierLensLimitMessage();
    return null;
  }

  void _showBlock(String message) {
    ref.read(notificationProvider.notifier).show(
          message,
          type: NotificationType.warning,
        );
  }

  void addCameraImages(String id, List<String> newPathsOrUrls) {
    state.whenData((cameras) {
      final index = cameras.indexWhere((c) => c.id == id);
      if (index == -1) return;
      final camera = cameras[index];
      final updatedUrls = List<String>.from(camera.imageUrls)..addAll(newPathsOrUrls);
      final updated = List<Camera>.from(cameras);
      updated[index] = camera.copyWith(imageUrls: updatedUrls);
      state = AsyncValue.data(updated);
      _persistCameraImages(id, updatedUrls);
    });
  }

  /// Replace all gear images (e.g. after remove or reorder). Persists to backend.
  void setCameraImages(String id, List<String> imageUrls) {
    state.whenData((cameras) {
      final index = cameras.indexWhere((c) => c.id == id);
      if (index == -1) return;
      final camera = cameras[index];
      final updated = List<Camera>.from(cameras);
      updated[index] = camera.copyWith(imageUrls: imageUrls);
      state = AsyncValue.data(updated);
      _persistCameraImages(id, imageUrls);
    });
  }

  /// Set which image is used as the card thumbnail (0-based index).
  void setPrimaryImage(String id, int primaryImageIndex) {
    state.whenData((cameras) {
      final index = cameras.indexWhere((c) => c.id == id);
      if (index == -1) return;
      final camera = cameras[index];
      final updated = List<Camera>.from(cameras);
      updated[index] = camera.copyWith(primaryImageIndex: primaryImageIndex.clamp(0, camera.imageUrls.length - 1));
      state = AsyncValue.data(updated);
      _persistPrimaryImage(id, primaryImageIndex);
    });
  }

  Future<void> _persistCameraStatus(String id, GearStatus status) async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final token = user == null ? null : await user.getIdToken();
      if (token == null) return;
      await ref.read(gearServiceProvider).updateUserCamera(token, id, status: status.label);
    } catch (_) {}
  }

  Future<void> _persistCameraDetails(String id, {
    String? nickname,
    String? brand,
    String? model,
    String? serialNumber,
    String? format,
    GearStatus? status,
  }) async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final token = user == null ? null : await user.getIdToken();
      if (token == null) return;
      await ref.read(gearServiceProvider).updateUserCamera(
        token,
        id,
        gearNickname: nickname,
        status: status?.label,
      );
    } catch (_) {}
  }

  Future<void> _persistCameraImages(String id, List<String> imageUrls) async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final token = user == null ? null : await user.getIdToken();
      if (token == null) return;
      await ref.read(gearServiceProvider).updateUserCamera(token, id, imageUrls: imageUrls);
    } catch (_) {
      // Optimistic update already applied; backend sync will retry on next fetch
    }
  }

  Future<void> _persistPrimaryImage(String id, int primaryImageIndex) async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final token = user == null ? null : await user.getIdToken();
      if (token == null) return;
      await ref.read(gearServiceProvider).updateUserCamera(token, id, primaryImageIndex: primaryImageIndex);
    } catch (_) {}
  }
  Future<void> linkLens(String lensId, String? cameraId) async {
    if (cameraId != null) {
      final reason = blockReasonForMountLens(cameraId);
      if (reason != null) {
        _showBlock(reason);
        return;
      }
    }
    try {
      final user = ref.read(authServiceProvider).currentUser;
      final token = user == null ? null : await user.getIdToken();
      if (token == null) return;
      
      await ref.read(gearServiceProvider).updateUserLens(
        token,
        lensId,
        parentCameraId: cameraId,
      );
      
      // Refresh gear list to show updated lenses
      ref.invalidateSelf();
    } catch (_) {}
  }

  Future<void> addAndLinkLens(Map<String, dynamic> data, String cameraId) async {
    final reason = blockReasonForMountLens(cameraId);
    if (reason != null) {
      _showBlock(reason);
      return;
    }
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;
      final token = await user.getIdToken();
      if (token == null) return;

      // Ensure the lens is linked to this camera from the start
      data['parent_camera_id'] = cameraId;
      
      await ref.read(gearServiceProvider).addUserLens(token, data);
      ref.invalidateSelf();
    } catch (_) {}
  }
}

final userGearProvider = AsyncNotifierProvider<UserGearNotifier, List<Camera>>(UserGearNotifier.new);

final allUserLensesProvider = FutureProvider<List<Lens>>((ref) async {
  final user = ref.read(authServiceProvider).currentUser;
  final token = user == null ? null : await user.getIdToken();
  if (token == null) return [];
  
  final rawData = await ref.read(gearServiceProvider).fetchUserLenses(token);
  return rawData.map((json) => Lens.fromJson(json as Map<String, dynamic>)).toList();
});

final cameraProvider = Provider.family<Camera?, String>((ref, id) {
  final gearAsync = ref.watch(userGearProvider);
  final gearList = gearAsync.value;
  if (gearList == null) return null;
  for (final c in gearList) {
    if (c.id == id) return c;
  }
  return null;
});
