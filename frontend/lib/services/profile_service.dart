import 'package:dio/dio.dart';

import 'package:frontend/models/user_profile.dart';
import 'package:frontend/services/api_service.dart';

class ProfileService {
  final ApiService _api = ApiService();

  /// Load current user profile from backend (GET /api/v1/me).
  Future<UserProfile> getProfile() async {
    final response = await _api.get('/api/v1/me');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
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
