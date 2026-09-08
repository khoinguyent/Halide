import 'package:flutter/material.dart';

/// Metadata for languages Halide supports in-app.
///
/// Order: English & Vietnamese first, then Spanish, Japanese, and French.
@immutable
class HalideLanguageOption {
  const HalideLanguageOption({
    required this.locale,
    required this.nativeLabel,
    required this.flagEmoji,
  });

  final Locale locale;
  /// Shown in the language picker (always in that language).
  final String nativeLabel;
  final String flagEmoji;
}

/// All user-selectable app languages (device default is implicit when unset).
const kHalideSelectableLanguages = <HalideLanguageOption>[
  HalideLanguageOption(
    locale: Locale('en'),
    nativeLabel: 'English',
    flagEmoji: '🇺🇸',
  ),
  HalideLanguageOption(
    locale: Locale('vi'),
    nativeLabel: 'Tiếng Việt',
    flagEmoji: '🇻🇳',
  ),
  HalideLanguageOption(
    locale: Locale('es'),
    nativeLabel: 'Español',
    flagEmoji: '🇪🇸',
  ),
  HalideLanguageOption(
    locale: Locale('ja'),
    nativeLabel: '日本語',
    flagEmoji: '🇯🇵',
  ),
  HalideLanguageOption(
    locale: Locale('fr'),
    nativeLabel: 'Français',
    flagEmoji: '🇫🇷',
  ),
];

const supportedAppLocales = <Locale>[
  Locale('en'),
  Locale('vi'),
  Locale('es'),
  Locale('ja'),
  Locale('fr'),
];

bool isSupportedLanguageCode(String? code) {
  if (code == null || code.isEmpty) return false;
  return supportedAppLocales.any((l) => l.languageCode == code);
}

HalideLanguageOption? languageOptionFor(Locale locale) {
  for (final opt in kHalideSelectableLanguages) {
    if (opt.locale.languageCode == locale.languageCode) return opt;
  }
  return null;
}
