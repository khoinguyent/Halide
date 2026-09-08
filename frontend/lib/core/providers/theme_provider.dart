import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/halide_colors.dart';
import '../theme/halide_palette.dart';

const _kThemeKey = 'halide_theme_id';

final halideThemeIdProvider =
    NotifierProvider<HalideThemeNotifier, HalideThemeId>(
  HalideThemeNotifier.new,
);

final halideColorsProvider = Provider<HalideColors>((ref) {
  final id = ref.watch(halideThemeIdProvider);
  return HalidePalettes.byId(id).toColors();
});

class HalideThemeNotifier extends Notifier<HalideThemeId> {
  @override
  HalideThemeId build() {
    _load();
    return HalideThemeId.deepHarbor;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeKey);
    if (stored == null) return;
    final match = HalideThemeId.values.where((e) => e.name == stored);
    if (match.isNotEmpty) state = match.first;
  }

  Future<void> setTheme(HalideThemeId id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, id.name);
  }
}
