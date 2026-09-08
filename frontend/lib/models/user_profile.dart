enum UserPlan {
  free,
  plus,
  pro,
  weekly,
  monthly,
  annually,
  lifetime;

  bool get isPro => this != UserPlan.free;

  static UserPlan fromString(String? val) {
    if (val == null) return UserPlan.free;
    return UserPlan.values.firstWhere(
      (e) => e.name == val.toLowerCase(),
      orElse: () => UserPlan.free,
    );
  }
}

/// Backend user profile (GET /api/v1/me, PATCH /api/v1/user/profile).
class UserProfile {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? professionalNickname;
  final String? bio;
  final UserPlan plan;
  final DateTime? createdAt;
  final bool hasSeenOnboarding;
  final bool hasSeenRollGuide;
  final bool hasSeenLabGuide;
  /// IANA timezone from backend (e.g. Asia/Bangkok). Used for analytics golden-hour math.
  final String? timezone;
  /// App UI language from backend: `system`, `en`, `vi`, or null if never set.
  final String? preferredLocale;
  /// From GET /api/v1/me (System Cloud quota). Null if older backend responses omit fields.
  final int? storageUsedBytes;
  final int? additionalStorageBytes;
  final int? totalStorageLimitBytes;

  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.professionalNickname,
    this.bio,
    this.plan = UserPlan.free,
    this.createdAt,
    this.hasSeenOnboarding = false,
    this.hasSeenRollGuide = false,
    this.hasSeenLabGuide = false,
    this.timezone,
    this.preferredLocale,
    this.storageUsedBytes,
    this.additionalStorageBytes,
    this.totalStorageLimitBytes,
  });

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      professionalNickname: json['professional_nickname'] as String?,
      bio: json['bio'] as String?,
      plan: UserPlan.fromString(json['plan'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      hasSeenOnboarding: json['has_seen_onboarding'] as bool? ?? false,
      hasSeenRollGuide: json['has_seen_roll_guide'] as bool? ?? false,
      hasSeenLabGuide: json['has_seen_lab_guide'] as bool? ?? false,
      timezone: json['timezone'] as String?,
      preferredLocale: json['preferred_locale'] as String?,
      storageUsedBytes: _parseInt(json['storage_used_bytes']),
      additionalStorageBytes: _parseInt(json['additional_storage_bytes']),
      totalStorageLimitBytes: _parseInt(json['total_storage_limit']),
    );
  }
}
