import 'package:flutter/material.dart';

import 'aarast_design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const textFontFamily = 'Tajawal';
  static const displayFontFamily = 'Amiri';

  // Expose colors directly for easy access
  static const ivory = AarastDesignTokens.ivory;
  static const pearl = AarastDesignTokens.pearl;
  static const surface = AarastDesignTokens.surface;
  static const surfaceElevated = AarastDesignTokens.surfaceElevated;

  static const burgundy = AarastDesignTokens.burgundy;
  static const burgundyDark = AarastDesignTokens.burgundyDark;
  static const burgundySoft = AarastDesignTokens.burgundySoft;

  static const gold = AarastDesignTokens.gold;
  static const goldSoft = AarastDesignTokens.goldSoft;

  static const ink = AarastDesignTokens.ink;
  static const title = AarastDesignTokens.title;
  static const muted = AarastDesignTokens.muted;
  static const border = AarastDesignTokens.border;

  static const success = AarastDesignTokens.success;
  static const successSoft = AarastDesignTokens.successSoft;
  static const warning = AarastDesignTokens.warning;
  static const warningSoft = AarastDesignTokens.warningSoft;
  static const danger = AarastDesignTokens.danger;
  static const dangerSoft = AarastDesignTokens.dangerSoft;
  static const info = AarastDesignTokens.info;
  static const infoSoft = AarastDesignTokens.infoSoft;
  static const disabled = AarastDesignTokens.disabled;
  static const empty = AarastDesignTokens.empty;

  // Semantic Aliases
  static const background = ivory;
  static const cardWhite = surface;
  static const textPrimary = ink;
  static const textSecondary = muted;

  // Backward Compatibility Aliases for other screens
  static const deepBurgundy = burgundy;
  static const warmGold = gold;
  static const charcoal = ink;
  static const mediumGray = muted;
  static const burgundyDeep = burgundyDark;
  static const burgundyBright = burgundy;
  static const burgundy2 = burgundyDark;
  static const gold2 = goldSoft;
  static const successBg = successSoft;

  static const dMaroon = burgundy;
  static const dMaroonDeep = burgundyDark;
  static const dMaroonBright = burgundy;
  static const dGold = gold;
  static const dGold2 = gold;
  static const dGoldDeep = gold;
  static const dBg = ivory;
  static const dCard = pearl;
  static const dCard2 = surface;
  static const dInk = ink;
  static const dInkSoft = muted;
  static const dMuted = muted;
  static const dLine = border;
  static const dGreen = success;
  static const dGreenBg = successSoft;
  static const dOrange = warning;
  static const dBlue = AarastDesignTokens.info;
  static const dBlueBg = AarastDesignTokens.infoSoft;
  static const dPinkBg = dangerSoft;
  static const dCreamBg = pearl;
  static const dMaroon2 = burgundyDark;
  static const dTrack = disabled;

  // Common sizing
  static const double radiusSm = AarastDesignTokens.radiusSm;
  static const double radiusMd = AarastDesignTokens.radiusMd;
  static const double radiusLg = AarastDesignTokens.radiusLg;
  static const double radiusXl = AarastDesignTokens.radiusXl;
  static const double radiusCard = 24;

  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gapMd = 14;
  static const double gapLg = 18;
  static const double gapXl = 24;

  static const EdgeInsets screenPadding = AarastDesignTokens.screenPadding;

  static const Duration motionFast = AarastDesignTokens.motionFast;
  static const Duration motionMedium = AarastDesignTokens.motionStandard;

  static const LinearGradient pageGradient = AarastDesignTokens.pageGradient;
  static const LinearGradient heroGradient =
      AarastDesignTokens.burgundyGradient;
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [goldSoft, gold, warning],
  );

  static List<BoxShadow> cardShadow() {
    return AarastDesignTokens.cardShadow();
  }

  static List<BoxShadow> softShadow({double opacity = 0.08}) {
    return [
      BoxShadow(
        color: ink.withAlpha((opacity * 255).round()),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static BoxDecoration premiumCardDecoration({
    Color color = surface,
    double radius = radiusCard,
    Border? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: AppTheme.border.withAlpha(210)),
      boxShadow: cardShadow(),
    );
  }

  static BoxDecoration screenDecoration() {
    return const BoxDecoration(color: ivory);
  }

  static BoxDecoration heroDecoration() {
    return BoxDecoration(
      gradient: heroGradient,
      borderRadius: BorderRadius.circular(radiusXl),
      boxShadow: [
        BoxShadow(
          color: burgundyDark.withValues(alpha: 0.1),
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
        seedColor: burgundy,
        primary: burgundy,
        onPrimary: Colors.white,
        secondary: gold,
        onSecondary: ink,
        surface: surface,
        onSurface: ink,
        outline: border,
        error: danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: ivory,
      canvasColor: ivory,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = _buildTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: ink, displayColor: ink);

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryColor: burgundy,
      scaffoldBackgroundColor: ivory,
      canvasColor: ivory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        iconTheme: const IconThemeData(color: ink),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: burgundy,
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: const BorderSide(color: border),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: burgundy,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusLg),
              ),
              textStyle: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return burgundyDark;
                }
                return null;
              }),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: burgundy,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusLg),
              ),
              textStyle: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return burgundyDark;
                }
                return null;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: burgundy,
          backgroundColor: surface,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: burgundy,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: ink),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        helperStyle: textTheme.bodySmall?.copyWith(color: muted),
        prefixIconColor: gold,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: burgundy, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: ink.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: border.withAlpha(210)),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: burgundy,
        disabledColor: surface,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: muted,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: ivory,
        modalBarrierColor: Color(0x66000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: burgundy,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 8,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: burgundy,
        textColor: ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return burgundy;
          return surface;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return surface;
          return surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return burgundy;
          return disabled;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: burgundy,
        circularTrackColor: border,
        linearTrackColor: border,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceElevated.withAlpha(240),
        selectedItemColor: burgundy,
        unselectedItemColor: disabled,
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
        backgroundColor: surfaceElevated.withAlpha(240),
        surfaceTintColor: Colors.transparent,
        indicatorColor: empty,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: isSelected ? burgundy : muted,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(color: isSelected ? burgundy : disabled);
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
