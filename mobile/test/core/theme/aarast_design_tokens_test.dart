import 'package:aarast_mobile/core/theme/aarast_design_tokens.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aarast Premium 2027 design tokens', () {
    test('back the legacy AppTheme aliases used by production screens', () {
      expect(AppTheme.deepBurgundy, AarastDesignTokens.royalMaroon);
      expect(AppTheme.warmGold, AarastDesignTokens.champagneGold);
      expect(AppTheme.dBg, AarastDesignTokens.warmIvory);
      expect(AppTheme.dCard, AarastDesignTokens.pearl);
      expect(AppTheme.dInk, AarastDesignTokens.ink);
      expect(AppTheme.dLine, AarastDesignTokens.hairline);
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
