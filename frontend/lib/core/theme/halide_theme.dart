import 'package:flutter/material.dart';
import 'halide_colors.dart';
import 'halide_typography.dart';

abstract final class HalideTheme {
  static ThemeData fromColors(HalideColors colors) {
    final scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: colors.accent,
      onPrimary: colors.light,
      secondary: colors.mid,
      onSecondary: colors.darkest,
      surface: colors.surface,
      onSurface: colors.light,
      onSurfaceVariant: colors.muted,
      outline: colors.borderSubtle,
      error: colors.error,
      onError: colors.light,
    );

    final textTheme = Typography.material2021(platform: TargetPlatform.iOS)
        .white
        .apply(
          fontFamily: HalideTypography.fontFamily,
          bodyColor: colors.textPrimary,
          displayColor: colors.textPrimary,
        )
        .copyWith(
          bodySmall: Typography.material2021(platform: TargetPlatform.iOS)
              .white
              .bodySmall
              ?.copyWith(
                fontFamily: HalideTypography.fontFamily,
                color: colors.textSecondary,
              ),
          titleLarge: Typography.material2021(platform: TargetPlatform.iOS)
              .white
              .titleLarge
              ?.copyWith(
                fontFamily: HalideTypography.fontFamily,
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: HalideTypography.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary, size: 26),
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: colors.borderSubtle,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.light,
          foregroundColor: colors.textOnLight,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.muted),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceSheet),
        ),
      ),
    );
  }

  static ThemeData get dark => fromColors(HalideColors.fallback);
}
