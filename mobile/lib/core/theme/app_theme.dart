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

  // ---- Aarast Dashboard design palette (from Claude Design handoff) ----
  static const dMaroon = Color(0xFF6E0E2C);
  static const dMaroon2 = Color(0xFF5B0A24);
  static const dMaroonDeep = Color(0xFF4A0A1E);
  static const dMaroonBright = Color(0xFF7A1232);
  static const dGold = Color(0xFFC5A25A);
  static const dGold2 = Color(0xFFD8BE86);
  static const dGoldDeep = Color(0xFFA9863F);
  static const dBg = Color(0xFFEFEAE4);
  static const dCard = Color(0xFFFBF9F6);
  static const dCard2 = Color(0xFFFFFFFF);
  static const dInk = Color(0xFF3C2B2F);
  static const dInkSoft = Color(0xFF6C5A5D);
  static const dMuted = Color(0xFFA89C9C);
  static const dLine = Color(0xFFECE5E0);
  static const dGreen = Color(0xFF4F9A43);
  static const dGreenBg = Color(0xFFE9F1E4);
  static const dOrange = Color(0xFFD6892C);
  static const dBlue = Color(0xFF3F6FB0);
  static const dBlueBg = Color(0xFFE6EDF6);
  static const dPinkBg = Color(0xFFF6E1E1);
  static const dCreamBg = Color(0xFFF4ECDD);
  static const dTrack = Color(0xFFCDC6C4);

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
