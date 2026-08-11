import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3_foundations.dart';

class AarastDesignTokens {
  const AarastDesignTokens._();

  // Spacing values
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space18 = 18;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space28 = 28;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  // Modern shape roles.
  static const double radiusControl = AarastV3Radius.control;
  static const double radiusSurface = AarastV3Radius.surface;
  static const double radiusOverlay = AarastV3Radius.feature;

  // Transitional legacy radii retained until feature consumers migrate.
  static const double radiusSm = AarastV3Radius.control;
  static const double radiusMd = AarastV3Radius.surface;
  static const double radiusLg = 20;
  static const double radiusXl = AarastV3Radius.feature;
  static const double radius2xl = 32;
  static const double radiusPill = AarastV3Radius.pill;

  // Icon Sizes
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 30;

  // Metrics
  static const double minTapTarget = 48;
  static const double cardMinHeight = 72;
  static const double bottomNavHeight = 76;
  static const double screenMaxWidth = 560;

  // Motion
  static const Duration motionQuick = AarastV3Motion.quick;
  static const Duration motionFast = Duration(milliseconds: 190);
  static const Duration motionStandard = AarastV3Motion.standard;
  static const Duration motionSlow = Duration(milliseconds: 460);
  static const Curve motionCurve = AarastV3Motion.curve;
  static const Curve motionExitCurve = Curves.easeInCubic;

  // Padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: AarastV3Space.x5,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  // V3 separates surfaces with borders and spacing, never decorative shadows.
  static List<BoxShadow> cardShadow({double opacity = 0.05}) => const [];

  static List<BoxShadow> liftedShadow({double opacity = 0.08}) => const [];
}

/// Semantic roles for new and migrated UI. The legacy [AarastDesignTokens]
/// palette remains isolated until each existing screen is deliberately
/// migrated and its reviewed Golden is replaced.
class AarastSemanticTokens {
  const AarastSemanticTokens._();

  // V3 is the single source for all active semantic roles. Compatibility
  // names below survive only so unmigrated business screens keep compiling;
  // they no longer define a second visual system.
  static const Color canvas = AarastV3Color.canvas;
  static const Color surface = AarastV3Color.paper;
  static const Color surfaceRaised = AarastV3Color.paper;
  static const Color surfaceMuted = AarastV3Color.paperQuiet;
  static const Color textPrimary = AarastV3Color.ink;
  static const Color textSecondary = AarastV3Color.textMuted;
  static const Color textDisabled = AarastV3Color.textFaint;
  static const Color border = AarastV3Color.line;
  static const Color borderStrong = AarastV3Color.lineStrong;
  static const Color brand = AarastV3Color.primary;
  static const Color brandMuted = AarastV3Color.primarySoft;
  static const Color brandDeep = AarastV3Color.primaryDark;
  static const Color onBrand = AarastV3Color.onPrimary;
  static const Color onBrandMuted = AarastV3Color.onPrimaryMuted;
  static const Color brandAccent = AarastV3Color.brandAccentStrong;
  static const Color brandAccentDecorative = AarastV3Color.brandAccent;
  static const Color brandAccentMuted = AarastV3Color.brandAccentSoft;
  static const Color focus = AarastV3Color.cobalt;
  static const Color inkSurface = AarastV3Color.ink;
  static const Color inkSurfaceRaised = AarastV3Color.inkSoft;
  static const Color accent = AarastV3Color.brandAccentStrong;
  static const Color accentMuted = AarastV3Color.brandAccentSoft;
  static const Color success = AarastV3Color.mint;
  static const Color successMuted = AarastV3Color.mintSoft;
  static const Color warning = AarastV3Color.amber;
  static const Color warningMuted = AarastV3Color.amberSoft;
  static const Color danger = AarastV3Color.danger;
  static const Color dangerMuted = AarastV3Color.dangerSoft;
  static const Color info = AarastV3Color.cobalt;
  static const Color infoMuted = AarastV3Color.cobaltSoft;
}
