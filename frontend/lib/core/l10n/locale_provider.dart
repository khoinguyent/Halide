import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/services/profile_service.dart';
import 'supported_languages.dart';

const _kLocaleKey = 'halide_app_locale';
const backendLocaleSystem = 'system';

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _loadFromLocal();
    return null;
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kLocaleKey);
    if (stored == null || stored == backendLocaleSystem) return;
    final locale = localeFromStorageCode(stored);
    if (locale != null) state = locale;
  }

  Future<bool> hasExplicitLocalPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kLocaleKey);
    if (stored == null || stored == backendLocaleSystem) return false;
    return localeFromStorageCode(stored) != null;
  }

  Future<void> syncFromBackend(String? preferredLocale) async {
    if (preferredLocale == null) return;
    final locale = localeFromBackendCode(preferredLocale);
    state = locale;
    await _persistLocal(locale);
  }

  Future<void> migrateLocalToBackend(ProfileService profileService) async {
    if (!await hasExplicitLocalPreference()) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kLocaleKey)!;
    try {
      await profileService.updatePreferredLocale(stored);
    } catch (_) {}
  }

  /// Persist an explicit user language choice (never `system` from the picker).
  Future<void> setLocale(
    Locale locale, {
    ProfileService? profileService,
  }) async {
    state = locale;
    await _persistLocal(locale);
    if (profileService != null) {
      try {
        await profileService.updatePreferredLocale(locale.languageCode);
      } catch (_) {}
    }
  }

  Future<void> _persistLocal(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, localeToStorageCode(locale));
  }
}

Locale? localeFromBackendCode(String? code) {
  final normalized = (code ?? '').trim().toLowerCase();
  if (normalized.isEmpty || normalized == backendLocaleSystem) return null;
  if (!isSupportedLanguageCode(normalized)) return null;
  return Locale(normalized);
}

Locale? localeFromStorageCode(String code) => localeFromBackendCode(code);

String localeToStorageCode(Locale? locale) {
  if (locale == null) return backendLocaleSystem;
  return locale.languageCode;
}

/// Device language when the user has not chosen a language yet.
Locale resolveDeviceLocale(Locale? deviceLocale) {
  final code = deviceLocale?.languageCode.toLowerCase();
  if (isSupportedLanguageCode(code)) return Locale(code!);
  return const Locale('en');
}

/// Priority: explicit user choice → supported device language → English.
Locale resolveAppLocale(Locale? userLocale, Locale? deviceLocale) {
  if (userLocale != null && isSupportedLanguageCode(userLocale.languageCode)) {
    return Locale(userLocale.languageCode);
  }
  return resolveDeviceLocale(deviceLocale);
}
