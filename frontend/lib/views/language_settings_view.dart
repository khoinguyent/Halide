import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n_extension.dart';
import '../core/l10n/locale_provider.dart';
import '../core/l10n/supported_languages.dart';
import '../core/theme/halide_colors.dart';
import '../core/widgets/halide_scaffold.dart';
import '../providers/profile_provider.dart';

class LanguageSettingsView extends ConsumerWidget {
  const LanguageSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    final selected = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final profileService = ref.read(profileServiceProvider);

    return HalideScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          l10n.languageSettingsTitle,
          style: TextStyle(
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.languageChooseTitle,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.languageChooseSubtitle,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            ...kHalideSelectableLanguages.map((option) {
              final isSelected = selected?.languageCode == option.locale.languageCode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LanguageCard(
                  option: option,
                  isSelected: isSelected,
                  colors: colors,
                  onTap: () => notifier.setLocale(
                    option.locale,
                    profileService: profileService,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.option,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final HalideLanguageOption option;
  final bool isSelected;
  final HalideColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = colors.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: colors.glassFill(isSelected ? 0.10 : 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? accent : colors.glassBorder(0.22),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Text(option.flagEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  option.nativeLabel,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              _SelectionIndicator(selected: isSelected, accent: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({
    required this.selected,
    required this.accent,
  });

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : Colors.white.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
