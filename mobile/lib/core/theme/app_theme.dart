import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  // Core brand colors
  static const deepBurgundy = Color(0xFF800020);
  static const warmGold = Color(0xFFD4AF37);
  static const ivory = Color(0xFFF9F6F0);
  static const charcoal = Color(0xFF333333);
  static const mediumGray = Color(0xFF757575);
  static const danger = Color(0xFFD32F2F);

  // Premium Aarast palette
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

  // Semantic aliases for new UI work
  static const background = dBg;
  static const card = dCard;
  static const cardWhite = dCard2;
  static const textPrimary = dInk;
  static const textSecondary = dInkSoft;
  static const textMuted = dMuted;
  static const border = dLine;
  static const success = dGreen;
  static const warning = dOrange;
  static const info = dBlue;

  // Common sizing
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;

  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gapMd = 14;
  static const double gapLg = 18;
  static const double gapXl = 24;

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      dMaroonBright,
      dMaroon,
      dMaroonDeep,
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      dGold2,
      dGold,
      dGoldDeep,
    ],
  );

  static List<BoxShadow> softShadow({double opacity = 0.08}) {
    return [
      BoxShadow(
        color: Colors.black.withAlpha((opacity * 255).round()),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> cardShadow() {
    return [
      BoxShadow(
        color: dMaroonDeep.withAlpha(16),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static BoxDecoration premiumCardDecoration({
    Color color = dCard2,
    double radius = radiusLg,
    Border? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: dLine),
      boxShadow: cardShadow(),
    );
  }

  static BoxDecoration heroDecoration() {
    return BoxDecoration(
      gradient: heroGradient,
      borderRadius: BorderRadius.circular(radiusXl),
      boxShadow: [
        BoxShadow(
          color: dMaroonDeep.withAlpha(50),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    );
  }

  static ThemeData light() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: dMaroon,
        primary: dMaroon,
        secondary: dGold,
        surface: dCard2,
        error: danger,
      ),
      scaffoldBackgroundColor: dBg,
    );

    final textTheme = GoogleFonts.cairoTextTheme(
      baseTheme.textTheme,
    ).apply(
      bodyColor: dInk,
      displayColor: dInk,
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryColor: dMaroon,
      scaffoldBackgroundColor: dBg,
      appBarTheme: AppBarTheme(
        backgroundColor: dBg,
        foregroundColor: dInk,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: dInk,
        ),
        iconTheme: const IconThemeData(color: dInk),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dMaroon,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dMaroon,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: dMaroon, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dMaroon,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dCard2,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: dInkSoft),
        hintStyle: textTheme.bodyMedium?.copyWith(color: dMuted),
        prefixIconColor: dGoldDeep,
        suffixIconColor: dInkSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: dLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: dLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: dMaroon, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: dCard2,
        elevation: 0,
        shadowColor: Colors.black.withAlpha(15),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: dLine),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dInk,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: dLine,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dCard2,
        selectedItemColor: dMaroon,
        unselectedItemColor: dMuted,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}