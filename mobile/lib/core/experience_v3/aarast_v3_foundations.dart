import 'package:flutter/material.dart';

/// Foundations for the rebuilt Aarast mobile experience.
///
/// Feature code consumes semantic roles from this file (or the V3 barrel).
/// The identity is warm and wedding-specific without restoring ornamental
/// gradients, glow, glass, crowns, or feature-owned palette aliases.
abstract final class AarastV3Color {
  // White owns the product canvas. Warmth now lives in selective quiet and
  // accent roles so repeated surfaces never accumulate into a beige screen.
  static const canvas = Color(0xFFFFFEFD);
  static const paper = Color(0xFFFFFFFF);
  static const paperQuiet = Color(0xFFF7F6F5);
  static const ink = Color(0xFF2D1A1E);
  static const inkSoft = Color(0xFF3B2B30);
  static const text = Color(0xFF352D30);
  static const textMuted = Color(0xFF6F6467);
  static const textFaint = Color(0xFF9A8F91);
  static const line = Color(0xFFE8E3E4);
  static const lineStrong = Color(0xFFD3C9CC);

  // Aarast identity roles. Names stay semantic so feature code never grows a
  // second local bridal palette.
  static const primary = Color(0xFF800020);
  static const primaryDark = Color(0xFF5A0015);
  static const primarySoft = Color(0xFFF8E8EC);
  static const onPrimary = Color(0xFFFFFEFD);
  static const onPrimaryMuted = Color(0xFFEFDCE1);
  static const brandAccent = Color(0xFFD9B15F);
  static const brandAccentStrong = Color(0xFF8A6A24);
  static const brandAccentSoft = Color(0xFFFBF3DE);

  // Information remains a rare operational signal, not a competing identity.
  static const cobalt = Color(0xFF5A788D);
  static const cobaltSoft = Color(0xFFEAF0F4);
  static const signal = brandAccentStrong;
  static const signalSoft = brandAccentSoft;
  static const mint = Color(0xFF4E8A78);
  static const mintSoft = Color(0xFFE7F2EE);
  static const amber = Color(0xFFA56D34);
  static const amberSoft = Color(0xFFF7EDDE);
  static const rose = Color(0xFFB86170);
  static const roseSoft = Color(0xFFF8E8EB);
  static const danger = Color(0xFFB74452);
  static const dangerSoft = Color(0xFFF9E7EA);
}

abstract final class AarastV3Space {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
}

abstract final class AarastV3Radius {
  static const control = 12.0;
  static const surface = 16.0;
  static const feature = 30.0;
  static const pill = 999.0;
}

abstract final class AarastV3Motion {
  static const quick = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 220);
  static const deliberate = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
}

/// Density rules shared by every routed Mobile archetype.
///
/// These values keep the first real decision above the fold and prevent every
/// feature from inventing its own vertical rhythm.
abstract final class AarastV3Density {
  static const pageHorizontal = AarastV3Space.x5;
  static const pageTop = AarastV3Space.x3;
  static const pageBottom = 112.0;
  // Root plan tabs use an extended quick action above a floating navigation
  // surface. Lists need enough trailing space for their final row to scroll
  // completely clear of both controls.
  static const pageBottomWithQuickAction = 184.0;
  static const sectionGap = AarastV3Space.x5;
  static const compactGap = AarastV3Space.x3;
  static const rowMinHeight = 68.0;
  static const metricMinHeight = 82.0;
}

abstract final class AarastV3Type {
  static const bodyFamily = 'Tajawal';
  static const displayFamily = 'IBMPlexSansArabic';

  static TextStyle display(BuildContext context) =>
      Theme.of(context).textTheme.displaySmall!.copyWith(
        color: AarastV3Color.ink,
        fontFamily: displayFamily,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.3,
      );

  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!.copyWith(
        color: AarastV3Color.ink,
        fontFamily: displayFamily,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle section(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
        color: AarastV3Color.ink,
        fontWeight: FontWeight.w800,
        height: 1.25,
      );

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
        color: AarastV3Color.textMuted,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle label(BuildContext context) => Theme.of(context)
      .textTheme
      .labelMedium!
      .copyWith(color: AarastV3Color.textMuted, fontWeight: FontWeight.w700);
}
