import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3_foundations.dart';

class AarastDesignTokens {
  const AarastDesignTokens._();

  // Legacy names, kept as aliases of the one grid (D74). New code takes
  // AarastV3Space / AarastV3Radius / AarastV3Icon directly.
  static const double space4 = AarastV3Space.x1;
  static const double space8 = AarastV3Space.x2;
  static const double space12 = AarastV3Space.x3;
  static const double space16 = AarastV3Space.x4;
  static const double space20 = AarastV3Space.x5;
  static const double space24 = AarastV3Space.x6;
  static const double space32 = AarastV3Space.x8;
  static const double space40 = AarastV3Space.x10;
  static const double space48 = AarastV3Space.x12;

  static const double radiusControl = AarastV3Radius.control;
  static const double radiusSurface = AarastV3Radius.surface;
  static const double radiusOverlay = AarastV3Radius.feature;
  static const double radiusSm = AarastV3Radius.control;
  static const double radiusMd = AarastV3Radius.surface;
  static const double radiusLg = AarastV3Radius.card;
  static const double radiusXl = AarastV3Radius.feature;
  static const double radiusPill = AarastV3Radius.pill;

  static const double iconSm = AarastV3Icon.sm;
  static const double iconMd = AarastV3Icon.md;
  static const double iconLg = AarastV3Icon.lg;

  static const double minTapTarget = AarastV3Space.x12;
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
    horizontal: AarastV3Density.pageHorizontal,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(AarastV3Space.x4);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: AarastV3Space.x4,
    vertical: AarastV3Space.x3,
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
  static const Color highlight = AarastV3Color.lilac;
  static const Color highlightMuted = AarastV3Color.lilacSoft;
}
