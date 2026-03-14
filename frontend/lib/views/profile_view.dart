import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

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
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person, color: Colors.white54),
                ),
                title: Text(
                  user?.displayName ?? 'Film Enthusiast',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  user?.email ?? 'premium@halide.app',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GlassPanel(
              child: Column(
                children: [
                   _ProfileOption(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.go('/profile/settings'),
                  ),
                  _ProfileOption(
                    icon: Icons.help_outline,
                    label: 'Support',
                    onTap: () {},
                  ),
                  _ProfileOption(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => context.go('/profile/privacy'),
                  ),
                  _ProfileOption(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => context.go('/profile/terms'),
                  ),
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
