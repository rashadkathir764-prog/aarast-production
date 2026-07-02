import 'package:aarast_mobile/core/theme/aarast_design_tokens.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aarast Premium 2027 design tokens', () {
    test('define the approved Soft Royal Wedding palette', () {
      expect(AarastDesignTokens.ivory, const Color(0xFFFBF4EA));
      expect(AarastDesignTokens.pearl, const Color(0xFFFFF8EF));
      expect(AarastDesignTokens.surface, Colors.white);
      expect(AarastDesignTokens.surfaceElevated, Colors.white);
      expect(AarastDesignTokens.burgundy, const Color(0xFF7A1F2B));
      expect(AarastDesignTokens.burgundyDark, const Color(0xFF4A0F18));
      expect(AarastDesignTokens.gold, const Color(0xFFD8B26E));
      expect(AarastDesignTokens.ink, const Color(0xFF23181A));
      expect(AarastDesignTokens.muted, const Color(0xFF75666A));
      expect(AarastDesignTokens.border, const Color(0xFFEADBC9));
      expect(AarastDesignTokens.success, const Color(0xFF2E7D5B));
      expect(AarastDesignTokens.warning, const Color(0xFFC9963E));
      expect(AarastDesignTokens.danger, const Color(0xFFB94A48));
    });

    test('back the legacy AppTheme aliases used by production screens', () {
      expect(AppTheme.deepBurgundy, AarastDesignTokens.royalMaroon);
      expect(AppTheme.warmGold, AarastDesignTokens.champagneGold);
      expect(AppTheme.dBg, AarastDesignTokens.warmIvory);
      expect(AppTheme.dCard, AarastDesignTokens.pearl);
      expect(AppTheme.dInk, AarastDesignTokens.ink);
      expect(AppTheme.dLine, AarastDesignTokens.hairline);
      expect(AppTheme.dBlue, AarastDesignTokens.info);
      expect(AppTheme.dBlueBg, AarastDesignTokens.infoSoft);
      expect(AppTheme.dTrack, AarastDesignTokens.disabled);
    });

    test('define a complete visual rhythm for cards and motion', () {
      expect(
        AarastDesignTokens.radiusSm,
        lessThan(AarastDesignTokens.radiusMd),
      );
      expect(
        AarastDesignTokens.radiusMd,
        lessThan(AarastDesignTokens.radiusLg),
      );
      expect(AarastDesignTokens.motionQuick.inMilliseconds, lessThan(200));
      expect(
        AarastDesignTokens.motionStandard.inMilliseconds,
        greaterThan(AarastDesignTokens.motionFast.inMilliseconds),
      );
      expect(AarastDesignTokens.bottomNavHeight, 76);
    });
  });
}
