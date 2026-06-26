import 'package:flutter/material.dart';

class AarastDesignTokens {
  const AarastDesignTokens._();

  static const Color royalMaroon = Color(0xFF800020);
  static const Color royalMaroonSoft = Color(0xFF8B183B);
  static const Color royalMaroonDeep = Color(0xFF4E0B20);
  static const Color royalMaroonMuted = Color(0xFF7B1232);

  static const Color champagneGold = Color(0xFFD4AF37);
  static const Color champagneGoldSoft = Color(0xFFE1CA96);
  static const Color champagneGoldDeep = Color(0xFFA98642);

  static const Color pearl = Color(0xFFFDFBF9);
  static const Color warmIvory = Color(0xFFFBF7F1);
  static const Color softSand = Color(0xFFF4ECDD);
  static const Color mutedRose = Color(0xFFF6E1E1);

  static const Color ink = Color(0xFF2D1A1E);
  static const Color inkSoft = Color(0xFF6C5A5D);
  static const Color muted = Color(0xFFA89C9C);
  static const Color hairline = Color(0xFFE9DED3);

  static const Color success = Color(0xFF4F9A43);
  static const Color successBg = Color(0xFFE9F1E4);
  static const Color warning = Color(0xFFD6892C);
  static const Color warningBg = Color(0xFFFFF2D8);
  static const Color danger = Color(0xFFD32F2F);
  static const Color dangerBg = Color(0xFFFCE8E8);
  static const Color info = Color(0xFF3F6FB0);
  static const Color infoBg = Color(0xFFE6EDF6);

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

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radius2xl = 32;
  static const double radiusPill = 999;

  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 30;

  static const double minTapTarget = 48;
  static const double cardMinHeight = 72;
  static const double bottomNavHeight = 76;
  static const double screenMaxWidth = 560;

  static const Duration motionQuick = Duration(milliseconds: 140);
  static const Duration motionFast = Duration(milliseconds: 190);
  static const Duration motionStandard = Duration(milliseconds: 300);
  static const Duration motionSlow = Duration(milliseconds: 460);

  static const Curve motionCurve = Cubic(0.22, 1, 0.36, 1);
  static const Curve motionExitCurve = Cubic(0.4, 0, 1, 1);

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  static const LinearGradient royalGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [royalMaroonSoft, royalMaroon, royalMaroonDeep],
  );

  static const LinearGradient champagneGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [champagneGoldSoft, champagneGold, champagneGoldDeep],
  );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pearl, warmIvory, softSand],
    stops: [0, 0.64, 1],
  );

  static List<BoxShadow> cardShadow({double opacity = 0.07}) {
    return [
      BoxShadow(
        color: royalMaroonDeep.withAlpha((opacity * 255).round()),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static List<BoxShadow> liftedShadow({double opacity = 0.12}) {
    return [
      BoxShadow(
        color: royalMaroonDeep.withAlpha((opacity * 255).round()),
        blurRadius: 34,
        offset: const Offset(0, 16),
      ),
    ];
  }
}
