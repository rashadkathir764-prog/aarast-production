import 'package:flutter/material.dart';

class AarastDesignTokens {
  const AarastDesignTokens._();

  // Primary Colors
  static const Color ivory = Color(0xFFFCF8F5); // Soft Bridal Ivory
  static const Color pearl = Color(0xFFFFF8F3); // Warm Pearl Cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFDFB);

  static const Color burgundy = Color(0xFF800020); // Royal Rose Burgundy
  static const Color burgundyDark = Color(0xFF5A0015); // Deep Burgundy
  static const Color burgundySoft = Color(0xFFF8E8EC);

  static const Color gold = Color(0xFFD4AF37); // Royal Champagne Gold
  static const Color goldSoft = Color(0xFFFFF3CF);

  static const Color ink = Color(0xFF2D1A1E);
  static const Color title = burgundyDark;
  static const Color muted = Color(0xFF8A7B7E);
  static const Color border = Color(0xFFEADDE2);

  // Premium gradient stops — للتدرجات الملكية والحلقة الذهبية فقط.
  static const Color burgundyLight = Color(0xFF8E0B2C);
  static const Color goldDeep = Color(0xFFB8912A);
  static const Color goldLight = Color(0xFFF2D888);
  static const Color goldGlow = Color(0xFFF7E7B3);
  static const Color dangerLight = Color(0xFFD95A6B);
  static const Color warningLight = Color(0xFFE8A94F);
  static const Color goldMonogram = Color(0xFFF3E4C0);

  // Semantic Status Colors
  static const Color success = Color(0xFF3D8252);
  static const Color successSoft = Color(0xFFE8F4EE);
  static const Color warning = Color(0xFFD98A2C);
  static const Color warningSoft = Color(0xFFFFF3CF);
  static const Color danger = Color(0xFFBA2D3F);
  static const Color dangerSoft = Color(0xFFFBECEF);
  static const Color info = Color(0xFF4F6D7A);
  static const Color infoSoft = Color(0xFFEAF1F4);
  static const Color disabled = Color(0xFFC7BABD);
  static const Color empty = Color(0xFFFFF8EF);

  // Contributor workspace — cool porcelain surfaces with an oxblood hero.
  // These tokens are intentionally scoped and do not replace the global
  // Soft Royal ivory/burgundy palette used by owner and provider screens.
  static const Color contributorCanvas = Color(0xFFF7F8FA);
  static const Color contributorSurface = Color(0xFFFFFFFF);
  static const Color contributorSurfaceAlt = Color(0xFFF1F3F5);
  static const Color contributorBorder = Color(0xFFE3E6EA);
  static const Color contributorInk = Color(0xFF17181B);
  static const Color contributorMuted = Color(0xFF6F737B);
  static const Color contributorOxblood = Color(0xFF550A1D);
  static const Color contributorOxbloodDark = Color(0xFF350610);
  static const Color contributorWine = Color(0xFF7A1432);
  static const Color contributorWineSoft = Color(0xFFF8EEF2);
  static const Color contributorBronze = Color(0xFFB69255);
  static const Color contributorMoneyTint = Color(0xFFEAF5EF);
  static const Color contributorGuestsTint = Color(0xFFEBF2F8);
  static const Color contributorProvidersTint = Color(0xFFF4F0E8);

  // Backward compatibility for tests
  static const Color royalMaroon = burgundy;
  static const Color royalMaroonSoft = burgundy;
  static const Color royalMaroonDeep = burgundyDark;
  static const Color champagneGold = gold;
  static const Color champagneGoldDeep = warning;
  static const Color warmIvory = ivory;
  static const Color softSand = empty;
  static const Color mutedRose = dangerSoft;
  static const Color inkSoft = muted;
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
    colors: [burgundy, Color(0xFF74182B), burgundyDark],
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
