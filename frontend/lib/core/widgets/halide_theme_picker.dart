import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import '../providers/theme_provider.dart';
import '../theme/halide_colors.dart';
import '../theme/halide_palette.dart';

/// Theme selector for profile theme settings.
class HalideThemePicker extends ConsumerWidget {
  const HalideThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(halideThemeIdProvider);
    final colors = HalideColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appTheme.toUpperCase(),
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...HalidePalettes.all.map((palette) {
          final isSelected = palette.id == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ThemeOptionTile(
              palette: palette,
              isSelected: isSelected,
              onTap: () => ref.read(halideThemeIdProvider.notifier).setTheme(palette.id),
            ),
          );
        }),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  final HalidePalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? colors.glassFill(0.12) : colors.glassFill(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.accent : colors.glassBorder(0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palette.id.localizedName(l10n),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final swatch in palette.swatch) ...[
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: swatch,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: colors.accent, size: 22)
              else
                Icon(Icons.circle_outlined, color: colors.iconMuted(), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
