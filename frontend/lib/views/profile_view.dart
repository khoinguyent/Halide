import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../services/local_avatar_storage.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final firebaseUser = authService.currentUser;
    final profileAsync = ref.watch(userProfileProvider);

    final displayName = profileAsync.value?.displayName ?? firebaseUser?.displayName ?? 'Film Enthusiast';
    final bio = profileAsync.value?.bio;
    final avatarUrl = profileAsync.value?.avatarUrl ?? firebaseUser?.photoURL;

    return HalideScaffold(
      appBar: AppBar(
        title: const Text(
          'PROFILE',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GlassPanel(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FutureBuilder<String?>(
                    future: LocalAvatarStorage.avatarPath,
                    builder: (context, snapshot) {
                      final localPath = snapshot.data;
                      final hasLocal = localPath != null && File(localPath).existsSync();
                      final useRemoteUrl = (avatarUrl ?? '').isNotEmpty && avatarUrl != 'local';
                      return CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        backgroundImage: hasLocal
                            ? FileImage(File(localPath))
                            : useRemoteUrl
                                ? NetworkImage(avatarUrl!)
                                : null,
                        child: hasLocal || useRemoteUrl
                            ? null
                            : Icon(Icons.person, size: 44, color: Colors.white.withOpacity(0.5)),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (bio ?? '').isEmpty ? 'Add a bio in Edit Profile' : bio!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassPanel(
              child: Column(
                children: [
                  _ProfileOption(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  _ProfileOption(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.go('/profile/settings'),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  _ProfileOption(
                    icon: Icons.help_outline,
                    label: 'Support',
                    onTap: () {},
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  _ProfileOption(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => context.go('/profile/privacy'),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  _ProfileOption(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => context.go('/profile/terms'),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  _ProfileOption(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    color: Colors.redAccent,
                    onTap: () async {
                      await authService.signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ProfileOption({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color.withOpacity(0.7)),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: onTap,
    );
  }
}
