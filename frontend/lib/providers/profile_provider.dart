import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/models/user_profile.dart';
import 'package:frontend/services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

/// Current user profile from backend (GET /api/v1/me).
/// Invalidated after update so profile is refetched.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final service = ref.watch(profileServiceProvider);
  try {
    return await service.getProfile();
  } catch (_) {
    return null;
  }
});
