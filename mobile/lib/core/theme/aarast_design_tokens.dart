import 'package:flutter/material.dart';

class AarastDesignTokens {
  const AarastDesignTokens._();

  // Primary Colors
  static const Color ivory = Color(0xFFFBF4EA); // Warm Ivory
  static const Color pearl = Color(0xFFFFF9F2); // Soft white for cards
  static const Color surface = Color(0xFFFFFDF8);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color burgundy = Color(0xFF8A0B2F);
  static const Color burgundyDark = Color(0xFF4B0618);
  static const Color burgundySoft = Color(0xFFF8E9EE);

  static const Color gold = Color(0xFFD9B15F);
  static const Color goldSoft = Color(0xFFFFF4DC);

  static const Color ink = Color(0xFF2F2A27);
  static const Color title = Color(0xFF3B1B22);
  static const Color muted = Color(0xFF8B7C72);
  static const Color border = Color(0xFFEADFD2);

  // Semantic Status Colors
  static const Color success = Color(0xFF4F9D72);
  static const Color successSoft = Color(0xFFEAF7EF);
  static const Color warning = Color(0xFFC98A2C);
  static const Color warningSoft = Color(0xFFFFF3DF);
  static const Color danger = Color(0xFFB23A48);
  static const Color dangerSoft = Color(0xFFFBEAEC);
  static const Color disabled = Color(0xFFD8CEC4);
  static const Color empty = Color(0xFFF3E8DA);

  // Backward compatibility for tests
  static const Color royalMaroon = burgundy;
  static const Color champagneGold = gold;
  static const Color warmIvory = ivory;
  static const Color hairline = border;

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

  // Border Radii
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radius2xl = 32;
  static const double radiusPill = 999;

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
  static const Duration motionQuick = Duration(milliseconds: 140);
  static const Duration motionFast = Duration(milliseconds: 190);
  static const Duration motionStandard = Duration(milliseconds: 300);
  static const Duration motionSlow = Duration(milliseconds: 460);
  static const Curve motionCurve = Curves.easeOutCubic;
  static const Curve motionExitCurve = Curves.easeInCubic;

  // Padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  // Gradients
  static const LinearGradient burgundyGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF8A0B2F),
      Color(0xFF6E0826),
      Color(0xFF4B0618),
    ],
  );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pearl, ivory],
    stops: [0.0, 1.0],
  );

  // Shadows
  static List<BoxShadow> cardShadow({double opacity = 0.05}) {
    return [
      BoxShadow(
        color: ink.withAlpha((opacity * 255).round()),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> liftedShadow({double opacity = 0.08}) {
    return [
      BoxShadow(
        color: ink.withAlpha((opacity * 255).round()),
        blurRadius: 34,
        offset: const Offset(0, 16),
      ),
    ];
  }
}
