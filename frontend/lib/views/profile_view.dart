import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile.dart';
import '../core/providers/notification_provider.dart';
import '../core/models/notification_model.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../services/auth_service.dart';
import '../services/local_avatar_storage.dart';
import '../widgets/debug_log_sheet.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref, AuthService authService) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF18181B),
      title: const Text(
        'Delete Account?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      content: const Text(
        'This action is permanent. All your film rolls, EXIF logs, and cloud-synced images will be wiped from our servers immediately.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await authService.deleteAccount();
    if (context.mounted) {
      context.go('/login');
    }
  } catch (e) {
    if (context.mounted) {
      ref.read(notificationProvider.notifier).show(
            e.toString(),
            type: NotificationType.error,
          );
    }
  }
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  /// Dev / staging / debug builds: long-press **PROFILE** for full in-app log (meter + sync + …).
  Widget _debugLogTitleGesture({required Widget child}) {
    if (!AppConfig.showInAppDiagnostics) return child;
    return GestureDetector(
      onLongPress: () {
        showHalideDebugLogSheet(
          context,
          title: 'HALIDE DEBUG LOG',
          channelFilter: null,
          emptyHint: '(no log lines yet — use meter tab or open rolls with images)',
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final firebaseUser = authService.currentUser;
    final profileAsync = ref.watch(userProfileProvider);

    final displayName = profileAsync.value?.displayName ?? firebaseUser?.displayName ?? 'Film Enthusiast';
    final email = profileAsync.value?.email ?? firebaseUser?.email ?? '';
    final bio = profileAsync.value?.bio;
    final avatarUrl = profileAsync.value?.avatarUrl ?? firebaseUser?.photoURL;

    return HalideScaffold(
      appBar: AppBar(
        title: _debugLogTitleGesture(
          child: const Text(
            'PROFILE',
            style: TextStyle(
              letterSpacing: 4,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          children: [
            _buildCenteredHeader(avatarUrl, displayName, email, bio, ref.watch(userPlanProvider)),
            const SizedBox(height: 32),
            GlassPanel(
              padding: EdgeInsets.zero,
              child: _ProfileOption(
                icon: Icons.star_rounded,
                label: 'Halide Premium',
                color: const Color(0xFFF97316),
                onTap: () => context.push('/paywall'),
              ),
            ),
            const SizedBox(height: 20),
            GlassPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileOption(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const _Divider(),
                  _ProfileOption(
                    icon: Icons.folder_special_outlined,
                    label: 'Storage strategy',
                    onTap: () => context.go('/profile/settings'),
                  ),
                  const _Divider(),
                  _ProfileOption(
                    icon: Icons.help_outline,
                    label: 'Support',
                    onTap: () => context.go('/profile/support'),
                  ),
                  const _Divider(),
                  _ProfileOption(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => context.go('/profile/privacy'),
                  ),
                  const _Divider(),
                  _ProfileOption(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => context.go('/profile/terms'),
                  ),
                  const _Divider(),
                  _ProfileOption(
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete Account',
                    color: Colors.redAccent,
                    onTap: () => _confirmDeleteAccount(context, ref, authService),
                  ),
                  const _Divider(),
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
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredHeader(String? avatarUrl, String displayName, String email, String? bio, UserPlan plan) {
    return Column(
      children: [
        FutureBuilder<String?>(
          future: LocalAvatarStorage.avatarPath,
          builder: (context, snapshot) {
            final localPath = snapshot.data;
            final hasLocal = localPath != null && File(localPath).existsSync();
            final useRemoteUrl = (avatarUrl ?? '').isNotEmpty && avatarUrl != 'local';
            
            return Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    backgroundImage: hasLocal
                        ? FileImage(File(localPath))
                        : useRemoteUrl
                            ? NetworkImage(avatarUrl!)
                            : null,
                    child: hasLocal || useRemoteUrl
                        ? null
                        : Icon(Icons.person, size: 50, color: Colors.white.withOpacity(0.5)),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _buildPlanBadge(plan),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            bio,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPlanBadge(UserPlan plan) {
    Color badgeColor;
    String label;
    List<Color> gradientColors;

    switch (plan) {
      case UserPlan.pro:
      case UserPlan.plus:
      case UserPlan.lifetime:
      case UserPlan.monthly:
      case UserPlan.annually:
        badgeColor = const Color(0xFFF59E0B);
        label = 'PRO';
        gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
        break;
      default:
        badgeColor = Colors.white.withOpacity(0.3);
        label = 'FREE';
        gradientColors = [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.2)];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: color.withOpacity(0.7), size: 24),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: color.withOpacity(0.2), size: 20),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 24,
      color: Colors.white.withOpacity(0.05),
    );
  }
}
