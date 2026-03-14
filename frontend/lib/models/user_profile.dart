/// Backend user profile (GET /api/v1/me, PATCH /api/v1/user/profile).
class UserProfile {
  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? professionalNickname;
  final String? bio;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.professionalNickname,
    this.bio,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      professionalNickname: json['professional_nickname'] as String?,
      bio: json['bio'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
