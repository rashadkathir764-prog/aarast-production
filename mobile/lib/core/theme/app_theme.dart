import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const textFontFamily = 'Tajawal';
  static const displayFontFamily = 'Amiri';

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

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 24);
  static const EdgeInsets compactScreenPadding = EdgeInsets.symmetric(
    horizontal: 16,
  );

  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionMedium = Duration(milliseconds: 300);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [dMaroonBright, dMaroon, dMaroonDeep],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [dGold2, dGold, dGoldDeep],
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
      fontFamily: textFontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: dMaroon,
        primary: dMaroon,
        secondary: dGold,
        surface: dCard2,
        error: danger,
      ),
      scaffoldBackgroundColor: dBg,
    );

    final textTheme = _buildTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: dInk, displayColor: dInk);

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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dMaroon,
          backgroundColor: dCard2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: const BorderSide(color: dLine),
          ),
        ),
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
            letterSpacing: 0,
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
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dMaroon,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
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
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: dCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dCard,
        modalBarrierColor: Color(0x66000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dCard2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: dMaroon,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 8,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: dMaroon,
        textColor: dInk,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return dMaroon;
          return dCard2;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: dLine, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: dMaroon,
        circularTrackColor: dLine,
        linearTrackColor: dLine,
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dCard2,
        surfaceTintColor: Colors.transparent,
        indicatorColor: dPinkBg,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: isSelected ? dMaroon : dMuted,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          );
        }),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    TextStyle? style(
      TextStyle? source, {
      double? size,
      FontWeight? weight,
      String? family,
      double height = 1.35,
    }) {
      return source?.copyWith(
        fontFamily: family ?? textFontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0,
      );
    }

    return base.copyWith(
      displayLarge: style(base.displayLarge, family: displayFontFamily),
      displayMedium: style(base.displayMedium, family: displayFontFamily),
      displaySmall: style(base.displaySmall, family: displayFontFamily),
      headlineLarge: style(
        base.headlineLarge,
        size: 28,
        weight: FontWeight.w700,
        family: displayFontFamily,
        height: 1.2,
      ),
      headlineMedium: style(
        base.headlineMedium,
        size: 24,
        weight: FontWeight.w700,
        family: displayFontFamily,
        height: 1.2,
      ),
      headlineSmall: style(
        base.headlineSmall,
        size: 22,
        weight: FontWeight.w700,
        height: 1.25,
      ),
      titleLarge: style(base.titleLarge, size: 20, weight: FontWeight.w800),
      titleMedium: style(base.titleMedium, size: 16, weight: FontWeight.w700),
      titleSmall: style(base.titleSmall, size: 14, weight: FontWeight.w700),
      bodyLarge: style(base.bodyLarge, size: 16, weight: FontWeight.w400),
      bodyMedium: style(base.bodyMedium, size: 14, weight: FontWeight.w400),
      bodySmall: style(base.bodySmall, size: 12, weight: FontWeight.w400),
      labelLarge: style(base.labelLarge, size: 14, weight: FontWeight.w800),
      labelMedium: style(base.labelMedium, size: 12, weight: FontWeight.w700),
      labelSmall: style(base.labelSmall, size: 11, weight: FontWeight.w600),
    );
  }
}
