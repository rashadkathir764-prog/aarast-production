import 'package:flutter/material.dart';

import 'aarast_design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const textFontFamily = 'Tajawal';
  static const displayFontFamily = 'Amiri';

  // Core brand colors
  static const deepBurgundy = AarastDesignTokens.royalMaroon;
  static const warmGold = AarastDesignTokens.champagneGold;
  static const ivory = AarastDesignTokens.warmIvory;
  static const charcoal = Color(0xFF333333);
  static const mediumGray = Color(0xFF757575);
  static const danger = AarastDesignTokens.danger;

  // Premium Aarast palette
  static const dMaroon = AarastDesignTokens.royalMaroonMuted;
  static const dMaroon2 = Color(0xFF671028);
  static const dMaroonDeep = AarastDesignTokens.royalMaroonDeep;
  static const dMaroonBright = AarastDesignTokens.royalMaroonSoft;

  static const dGold = Color(0xFFC7A35D);
  static const dGold2 = AarastDesignTokens.champagneGoldSoft;
  static const dGoldDeep = AarastDesignTokens.champagneGoldDeep;

  static const dBg = AarastDesignTokens.warmIvory;
  static const dCard = AarastDesignTokens.pearl;
  static const dCard2 = Color(0xFFFFFFFF);

  static const dInk = AarastDesignTokens.ink;
  static const dInkSoft = AarastDesignTokens.inkSoft;
  static const dMuted = AarastDesignTokens.muted;
  static const dLine = AarastDesignTokens.hairline;

  static const dGreen = AarastDesignTokens.success;
  static const dGreenBg = AarastDesignTokens.successBg;

  static const dOrange = AarastDesignTokens.warning;

  static const dBlue = AarastDesignTokens.info;
  static const dBlueBg = AarastDesignTokens.infoBg;

  static const dPinkBg = AarastDesignTokens.mutedRose;
  static const dCreamBg = AarastDesignTokens.softSand;
  static const dTrack = Color(0xFFCDC6C4);

  // Welcome Light Luxury specific colors
  static const wWarmIvory = Color(0xFFFBF7F1);
  static const wPearlWhite = Color(0xFFFFFFFF);
  static const wRoyalBurgundy = Color(0xFF6D1024);
  static const wDeepBurgundy = Color(0xFF4B0B19);
  static const wChampagneGold = Color(0xFFD6B36A);
  static const wSoftGold = Color(0xFFF1E1B8);
  static const wPrimaryText = Color(0xFF2D1A1E);
  static const wSecondaryText = Color(0xFF6C5A5D);

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
  static const double radiusSm = AarastDesignTokens.radiusSm;
  static const double radiusMd = AarastDesignTokens.radiusMd;
  static const double radiusLg = AarastDesignTokens.radiusLg;
  static const double radiusXl = AarastDesignTokens.radiusXl;

  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gapMd = 14;
  static const double gapLg = 18;
  static const double gapXl = 24;

  static const EdgeInsets screenPadding = AarastDesignTokens.screenPadding;
  static const EdgeInsets compactScreenPadding =
      AarastDesignTokens.screenPadding;

  static const Duration motionFast = AarastDesignTokens.motionFast;
  static const Duration motionMedium = AarastDesignTokens.motionStandard;

  static const LinearGradient heroGradient = AarastDesignTokens.royalGradient;

  static const LinearGradient goldGradient =
      AarastDesignTokens.champagneGradient;
  static const LinearGradient pageGradient = AarastDesignTokens.pageGradient;

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
        color: dMaroonDeep.withAlpha(12),
        blurRadius: 14,
        offset: const Offset(0, 5),
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

  static BoxDecoration screenDecoration() {
    return const BoxDecoration(gradient: pageGradient);
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
        onPrimary: Colors.white,
        secondary: dGold,
        onSecondary: dInk,
        tertiary: dGoldDeep,
        surface: dCard2,
        onSurface: dInk,
        surfaceContainerHighest: dCard,
        outline: dLine,
        error: danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: dBg,
      canvasColor: dBg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = _buildTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: dInk, displayColor: dInk);

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryColor: dMaroon,
      scaffoldBackgroundColor: dBg,
      canvasColor: dBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dMaroon,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dMaroon,
          minimumSize: const Size.fromHeight(52),
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
          vertical: 13,
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
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: dCreamBg,
        selectedColor: dPinkBg,
        disabledColor: dLine.withAlpha(120),
        side: const BorderSide(color: dLine),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: dInk,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: dMaroon,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return dCard2;
          return dMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return dMaroon;
          return dLine;
        }),
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
