import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:frontend/models/user_profile.dart';
import 'package:frontend/services/api_service.dart';

class ProfileService {
  final ApiService _api = ApiService();

  /// Load current user profile from backend (GET /api/v1/me).
  Future<UserProfile> getProfile() async {
    final response = await _api.get('/api/v1/me');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markOnboardingSeen() async {
    await _api.patch('/api/v1/user/onboarding-seen');
  }

  Future<void> markRollGuideSeen() async {
    await _api.patch('/api/v1/user/roll-guide-seen');
  }

  Future<void> markLabGuideSeen() async {
    await _api.patch('/api/v1/user/lab-guide-seen');
  }

  /// Persist device IANA timezone (PATCH /api/v1/user/timezone).
  Future<UserProfile> updateTimezone(String timezone) async {
    final response = await _api.patch(
      '/api/v1/user/timezone',
      data: {'timezone': timezone},
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Persist app UI language (PATCH /api/v1/user/locale). Use `system` to follow device.
  Future<UserProfile> updatePreferredLocale(String locale) async {
    final response = await _api.patch(
      '/api/v1/user/locale',
      data: {'locale': locale},
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sync device timezone to backend when it differs from the stored profile value.
  Future<void> syncDeviceTimezoneIfNeeded(UserProfile? profile) async {
    try {
      final deviceTz = await FlutterTimezone.getLocalTimezone();
      if (profile?.timezone != deviceTz) {
        await updateTimezone(deviceTz);
      }
    } catch (_) {
      // Non-fatal: analytics can still pass timezone per request.
    }
  }

  /// Update profile (PATCH /api/v1/user/profile) with optional avatar file.
  Future<UserProfile> updateProfile({
    String? name,
    String? professionalNickname,
    String? bio,
    String? avatarFilePath,
  }) async {
    final formData = FormData.fromMap({
      if (name != null) 'name': name,
      if (professionalNickname != null) 'professional_nickname': professionalNickname,
      if (bio != null) 'bio': bio,
    });
    if (avatarFilePath != null) {
      formData.files.add(MapEntry(
        'avatar',
        await MultipartFile.fromFile(avatarFilePath),
      ));
    }
    final response = await _api.patch('/api/v1/user/profile', data: formData);
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
