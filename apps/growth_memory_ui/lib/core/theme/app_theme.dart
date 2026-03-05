import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    const seed = Color(0xFF4F46E5);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0B1220),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      cardTheme: CardTheme(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: 0.5),
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.6),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: scheme.onSurface),
      ),
    );
  }

  static ThemeData light() {
    const seed = Color(0xFF4F46E5);
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
    );
  }
}

