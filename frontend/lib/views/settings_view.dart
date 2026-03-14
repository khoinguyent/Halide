import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return HalideScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          color: Colors.white,
        ),
        centerTitle: true,
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingsOption(
                icon: Icons.folder_special_outlined,
                label: 'Storage Strategy',
                onTap: () => context.push('/profile/settings/storage-strategy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsOption({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withOpacity(0.7)),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: onTap,
    );
  }
}
