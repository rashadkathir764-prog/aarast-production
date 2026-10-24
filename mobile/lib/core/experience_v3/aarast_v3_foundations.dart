import 'package:flutter/material.dart';

/// Foundations for the rebuilt Aarast mobile experience.
///
/// Feature code consumes semantic roles from this file (or the V3 barrel).
/// The identity is the groom journey's teal with saffron accents (DECISIONS
/// 2026-10-22, D0). Text roles stay AA-readable on paper (D1): the lighter
/// prototype shades are fills only.
abstract final class AarastV3Color {
  // A quiet green-grey canvas lets white cards read as the content.
  static const canvas = Color(0xFFF2F4F3);
  static const paper = Color(0xFFFFFFFF);
  static const paperQuiet = Color(0xFFF7F8F8);
  static const ink = Color(0xFF13211F);
  static const inkSoft = Color(0xFF23332F);
  static const text = Color(0xFF13211F);
  static const textMuted = Color(0xFF55625E);
  static const textFaint = Color(0xFF8A9592);
  static const line = Color(0xFFE2E7E5);
  static const lineStrong = Color(0xFFC9D1CE);

  // Aarast identity roles. Names stay semantic so feature code never grows a
  // second local palette.
  static const primary = Color(0xFF0B6E69);
  static const primaryDark = Color(0xFF064B47);
  static const primarySoft = Color(0xFFDCEFEC);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryMuted = Color(0xFFDCEFEC);
  // Saffron: the light shade reads on teal, the strong shade reads on paper.
  static const brandAccent = Color(0xFFFBDFA6);
  static const brandAccentStrong = Color(0xFF9A5F0E);
  static const brandAccentSoft = Color(0xFFFCEFD8);
  // Decoration only (the wordmark dot, the lights): never text on paper.
  static const saffron = Color(0xFFF2A93B);

  // Status colours, each a readable text shade with a soft fill.
  static const cobalt = Color(0xFF2F6E9E);
  static const cobaltSoft = Color(0xFFE0EEF8);
  static const signal = brandAccentStrong;
  static const signalSoft = brandAccentSoft;
  static const mint = Color(0xFF25774F);
  static const mintSoft = Color(0xFFDDF1E6);
  static const amber = Color(0xFF9A5F0E);
  static const amberSoft = Color(0xFFFCEFD8);
  // The bride's colour, kept for her theme (D2).
  static const rose = Color(0xFFB4536A);
  static const roseSoft = Color(0xFFF8E4EA);
  static const danger = Color(0xFFB8432A);
  static const dangerSoft = Color(0xFFFBE5DF);
  // Lilac marks tentative states («مبدئي») and the guests section.
  static const lilac = Color(0xFF6A4FA3);
  static const lilacSoft = Color(0xFFECE6F6);
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
  // Root plan tabs carry the floating «+» above the tabs (D33). Their lists
  // need enough trailing space for the last row to scroll clear of it.
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
