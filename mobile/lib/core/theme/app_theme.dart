import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3_foundations.dart';
import 'aarast_design_tokens.dart';
import 'aarast_motion.dart';

class AppTheme {
  const AppTheme._();

  static const textFontFamily = AarastV3Type.bodyFamily;

  /// وجه أعرست الحديث للعناوين — IBM Plex Sans Arabic.
  /// خط Amiri بقي مسجلًا في pubspec لهوية الشعار فقط، لا للعناوين.
  static const displayFontFamily = AarastV3Type.displayFamily;

  // Modern semantic roles for all new and migrated UI.
  static const canvas = AarastSemanticTokens.canvas;
  static const surfaceRaised = AarastSemanticTokens.surfaceRaised;
  static const surfaceMuted = AarastSemanticTokens.surfaceMuted;
  static const textPrimary = AarastSemanticTokens.textPrimary;
  static const textSecondary = AarastSemanticTokens.textSecondary;
  static const textDisabled = AarastSemanticTokens.textDisabled;
  static const border = AarastSemanticTokens.border;
  static const borderStrong = AarastSemanticTokens.borderStrong;
  static const brand = AarastSemanticTokens.brand;
  static const brandMuted = AarastSemanticTokens.brandMuted;
  static const brandDeep = AarastSemanticTokens.brandDeep;
  static const onBrand = AarastSemanticTokens.onBrand;
  static const onBrandMuted = AarastSemanticTokens.onBrandMuted;
  static const brandAccent = AarastSemanticTokens.brandAccent;
  static const brandAccentDecorative =
      AarastSemanticTokens.brandAccentDecorative;
  static const brandAccentMuted = AarastSemanticTokens.brandAccentMuted;
  static const focus = AarastSemanticTokens.focus;
  static const inkSurface = AarastSemanticTokens.inkSurface;
  static const inkSurfaceRaised = AarastSemanticTokens.inkSurfaceRaised;
  static const accent = AarastSemanticTokens.accent;
  static const accentMuted = AarastSemanticTokens.accentMuted;

  static const success = AarastSemanticTokens.success;
  static const successSoft = AarastSemanticTokens.successMuted;
  static const warning = AarastSemanticTokens.warning;
  static const warningSoft = AarastSemanticTokens.warningMuted;
  static const danger = AarastSemanticTokens.danger;
  static const dangerSoft = AarastSemanticTokens.dangerMuted;
  static const info = AarastSemanticTokens.info;
  static const infoSoft = AarastSemanticTokens.infoMuted;

  // Common sizing
  static const double radiusSm = AarastDesignTokens.radiusSm;
  static const double radiusMd = AarastDesignTokens.radiusMd;
  static const double radiusLg = AarastDesignTokens.radiusLg;
  static const double radiusXl = AarastDesignTokens.radiusXl;
  static const double radius2xl = AarastDesignTokens.radius2xl;
  static const double radiusPill = AarastDesignTokens.radiusPill;
  static const double radiusCard = 24;
  static const double radiusControl = AarastDesignTokens.radiusControl;
  static const double radiusSurface = AarastDesignTokens.radiusSurface;
  static const double radiusOverlay = AarastDesignTokens.radiusOverlay;

  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gapMd = 14;
  static const double gapLg = 18;
  static const double gapXl = 24;

  // Canonical spacing scale (re-exported so features import AppTheme only)
  static const double space2 = AarastDesignTokens.space2;
  static const double space4 = AarastDesignTokens.space4;
  static const double space6 = AarastDesignTokens.space6;
  static const double space8 = AarastDesignTokens.space8;
  static const double space10 = AarastDesignTokens.space10;
  static const double space12 = AarastDesignTokens.space12;
  static const double space14 = AarastDesignTokens.space14;
  static const double space16 = AarastDesignTokens.space16;
  static const double space18 = AarastDesignTokens.space18;
  static const double space20 = AarastDesignTokens.space20;
  static const double space24 = AarastDesignTokens.space24;
  static const double space28 = AarastDesignTokens.space28;
  static const double space32 = AarastDesignTokens.space32;
  static const double space40 = AarastDesignTokens.space40;
  static const double space48 = AarastDesignTokens.space48;

  // Icon sizes + metrics
  static const double iconSm = AarastDesignTokens.iconSm;
  static const double iconMd = AarastDesignTokens.iconMd;
  static const double iconLg = AarastDesignTokens.iconLg;
  static const double iconXl = AarastDesignTokens.iconXl;
  static const double minTapTarget = AarastDesignTokens.minTapTarget;
  static const double bottomNavHeight = AarastDesignTokens.bottomNavHeight;
  static const double screenMaxWidth = AarastDesignTokens.screenMaxWidth;

  static const EdgeInsets screenPadding = AarastDesignTokens.screenPadding;
  static const EdgeInsets cardPadding = AarastDesignTokens.cardPadding;
  static const EdgeInsets listItemPadding = AarastDesignTokens.listItemPadding;

  static const Duration motionQuick = AarastDesignTokens.motionQuick;
  static const Duration motionFast = AarastDesignTokens.motionFast;
  static const Duration motionMedium = AarastDesignTokens.motionStandard;
  static const Duration motionSlow = AarastDesignTokens.motionSlow;
  static const Curve motionCurve = AarastDesignTokens.motionCurve;
  static const Curve motionExitCurve = AarastDesignTokens.motionExitCurve;

  static List<BoxShadow> cardShadow({double opacity = 0.05}) {
    return AarastDesignTokens.cardShadow(opacity: opacity);
  }

  static List<BoxShadow> softShadow({double opacity = 0.08}) => const [];

  static BoxDecoration surfaceDecoration({
    Color color = surfaceRaised,
    double radius = radiusSurface,
    Border? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: AarastSemanticTokens.border),
    );
  }

  static BoxDecoration screenDecoration() {
    return const BoxDecoration(color: canvas);
  }

  static ThemeData light() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamily: textFontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        primary: brand,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surfaceRaised,
        onSurface: textPrimary,
        outline: AarastSemanticTokens.border,
        error: danger,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AarastPageTransitionsBuilder(),
          TargetPlatform.iOS: AarastPageTransitionsBuilder(),
          TargetPlatform.macOS: AarastPageTransitionsBuilder(),
          TargetPlatform.windows: AarastPageTransitionsBuilder(),
          TargetPlatform.linux: AarastPageTransitionsBuilder(),
          TargetPlatform.fuchsia: AarastPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = _buildTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryColor: brand,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surfaceMuted,
          shape: const CircleBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: brand,
              foregroundColor: onBrand,
              elevation: 0,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusControl),
              ),
              textStyle: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return brandDeep;
                }
                return null;
              }),
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: brand,
              foregroundColor: onBrand,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusControl),
              ),
              textStyle: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return brandDeep;
                }
                return null;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surfaceRaised,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(
            color: AarastSemanticTokens.border,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      // القوائم المنبثقة: سطح أبيض نظيف بحد رفيع — يلغي التلوين الوردي
      // القادم من M3 surface tint (fromSeed) الذي كان يشوّه فلتر المدن.
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: const Color(0x1F171922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSurface),
          side: const BorderSide(color: AarastSemanticTokens.border),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        // A quiet filled field is easier to discover than a lone underline on
        // the white canvas, while the focused bottom line keeps forms light.
        fillColor: surfaceMuted,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 42,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 42,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        helperStyle: textTheme.bodySmall?.copyWith(color: textSecondary),
        prefixIconColor: brand,
        suffixIconColor: textSecondary,
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: AarastSemanticTokens.border),
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: AarastSemanticTokens.border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: brand, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0,
        shadowColor: textPrimary.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSurface),
          side: const BorderSide(color: AarastSemanticTokens.border),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: surfaceRaised,
        selectedColor: brand,
        disabledColor: surfaceMuted,
        side: const BorderSide(color: AarastSemanticTokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: onBrand,
          fontWeight: FontWeight.w800,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surfaceRaised,
        modalBarrierColor: Color(0x66000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusOverlay),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusOverlay),
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Color(0x1A2D1A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusXl)),
          side: BorderSide(color: border),
        ),
        headerBackgroundColor: surfaceRaised,
        headerForegroundColor: textPrimary,
        dividerColor: border,
        rangePickerBackgroundColor: surfaceRaised,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangePickerElevation: 6,
        rangePickerShadowColor: Color(0x1A2D1A1E),
        rangePickerShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusXl)),
          side: BorderSide(color: border),
        ),
        rangePickerHeaderBackgroundColor: surfaceRaised,
        rangePickerHeaderForegroundColor: textPrimary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: onBrand,
        shape: CircleBorder(),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: brand,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: const RoundedRectangleBorder(),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return surfaceRaised;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AarastSemanticTokens.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return surfaceRaised;
          return surfaceRaised;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return textDisabled;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brand,
        circularTrackColor: AarastSemanticTokens.border,
        linearTrackColor: AarastSemanticTokens.border,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inkSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AarastSemanticTokens.border,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceRaised.withAlpha(246),
        selectedItemColor: brand,
        unselectedItemColor: textDisabled,
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
        backgroundColor: surfaceRaised.withAlpha(246),
        surfaceTintColor: Colors.transparent,
        indicatorColor: brandMuted,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: isSelected ? brand : textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(color: isSelected ? brand : textDisabled);
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
