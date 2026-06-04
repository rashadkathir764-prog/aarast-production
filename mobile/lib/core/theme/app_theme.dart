import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const deepBurgundy = Color(0xFF800020);
  static const warmGold = Color(0xFFD4AF37);
  static const ivory = Color(0xFFF9F6F0);
  static const charcoal = Color(0xFF333333);
  static const mediumGray = Color(0xFF757575);
  static const danger = Color(0xFFD32F2F);

  static ThemeData light() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: deepBurgundy,
        primary: deepBurgundy,
        secondary: warmGold,
        surface: Colors.white,
        error: danger,
      ),
      scaffoldBackgroundColor: ivory,
    );

    final textTheme = GoogleFonts.cairoTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: charcoal, displayColor: charcoal);

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: ivory,
        foregroundColor: charcoal,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: charcoal,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepBurgundy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deepBurgundy,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: deepBurgundy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: deepBurgundy, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
