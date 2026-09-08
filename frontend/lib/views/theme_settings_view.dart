import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';

import '../core/theme/halide_colors.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/halide_theme_picker.dart';

class ThemeSettingsView extends ConsumerWidget {
  const ThemeSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);

    return HalideScaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          color: colors.textPrimary,
        ),
        centerTitle: true,
        title: Text(
          l10n.themesTitle,
          style: TextStyle(
            letterSpacing: 2.0,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: const HalideThemePicker(),
      ),
    );
  }
}
