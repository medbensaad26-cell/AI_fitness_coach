import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual system: pine green on cool mist backgrounds (not purple / cream kitsch).
class AppTheme {
  AppTheme._();

  static const Color pine = Color(0xFF0E6B4F);
  static const Color pineDeep = Color(0xFF0A4D39);
  static const Color mist = Color(0xFFE7F0EB);
  static const Color mistDeep = Color(0xFFD5E5DC);
  static const Color ink = Color(0xFF14231C);
  static const Color stone = Color(0xFF5C6F66);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: pine,
      brightness: Brightness.light,
      primary: pine,
      onPrimary: Colors.white,
      secondary: pineDeep,
      surface: const Color(0xFFF7FAF8),
      onSurface: ink,
      onSurfaceVariant: stone,
      error: const Color(0xFFB42318),
    );

    final textTheme = _textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: mist,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: pine,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: pineDeep,
          side: const BorderSide(color: pine, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: pineDeep),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: mistDeep),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: mistDeep),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: pine, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: pineDeep,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: pine,
        thumbColor: pineDeep,
        inactiveTrackColor: mistDeep,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: pine),
    );
  }

  static ThemeData get dark {
    // Keep a dark variant available, but the product default is light.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: pine,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(Brightness.dark),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    final display = GoogleFonts.soraTextTheme(base);
    final body = GoogleFonts.sourceSans3TextTheme(base);
    return display.copyWith(
      displayLarge: display.displayLarge,
      displayMedium: display.displayMedium,
      displaySmall: display.displaySmall,
      headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: display.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.35),
      bodySmall: body.bodySmall?.copyWith(height: 1.3),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: body.labelMedium,
      labelSmall: body.labelSmall,
    );
  }
}
