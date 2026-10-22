import 'dart:io';

import 'package:aarast_mobile/core/experience_v3/aarast_v3_foundations.dart';
import 'package:aarast_mobile/core/theme/aarast_design_tokens.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color foreground, Color background) {
  final high = foreground.computeLuminance() + 0.05;
  final low = background.computeLuminance() + 0.05;
  return high > low ? high / low : low / high;
}

void main() {
  group('Aarast V3 design tokens', () {
    test('define the active mobile palette', () {
      expect(AarastSemanticTokens.canvas, const Color(0xFFF2F4F3));
      expect(AarastSemanticTokens.surface, const Color(0xFFFFFFFF));
      expect(AarastSemanticTokens.surfaceRaised, const Color(0xFFFFFFFF));
      expect(AarastSemanticTokens.surfaceMuted, const Color(0xFFF7F8F8));
      expect(AarastSemanticTokens.textPrimary, const Color(0xFF13211F));
      expect(AarastSemanticTokens.textSecondary, const Color(0xFF55625E));
      expect(AarastSemanticTokens.textDisabled, const Color(0xFF8A9592));
      expect(AarastSemanticTokens.border, const Color(0xFFE2E7E5));
      expect(AarastSemanticTokens.borderStrong, const Color(0xFFC9D1CE));
      expect(AarastSemanticTokens.brand, const Color(0xFF0B6E69));
      expect(AarastSemanticTokens.brandDeep, const Color(0xFF064B47));
      expect(AarastSemanticTokens.brandMuted, const Color(0xFFDCEFEC));
      expect(AarastSemanticTokens.onBrand, const Color(0xFFFFFFFF));
      expect(AarastSemanticTokens.brandAccent, const Color(0xFF9A5F0E));
      expect(
        AarastSemanticTokens.brandAccentDecorative,
        const Color(0xFFFBDFA6),
      );
      expect(AarastSemanticTokens.brandAccentMuted, const Color(0xFFFCEFD8));
      expect(AarastSemanticTokens.focus, const Color(0xFF2F6E9E));
      expect(AarastSemanticTokens.success, const Color(0xFF25774F));
      expect(AarastSemanticTokens.warning, const Color(0xFF9A5F0E));
      expect(AarastSemanticTokens.danger, const Color(0xFFB8432A));
      expect(AarastSemanticTokens.info, const Color(0xFF2F6E9E));
      expect(AarastSemanticTokens.highlight, const Color(0xFF6A4FA3));
      expect(AarastSemanticTokens.highlightMuted, const Color(0xFFECE6F6));
    });

    test('keeps text-capable roles AA-readable on paper', () {
      const surface = AarastSemanticTokens.surface;
      for (final color in [
        AarastSemanticTokens.textPrimary,
        AarastSemanticTokens.textSecondary,
        AarastSemanticTokens.brand,
        AarastSemanticTokens.brandDeep,
        AarastSemanticTokens.brandAccent,
        AarastSemanticTokens.danger,
        AarastSemanticTokens.info,
      ]) {
        expect(_contrastRatio(color, surface), greaterThanOrEqualTo(4.5));
      }
      expect(
        _contrastRatio(
          AarastSemanticTokens.onBrand,
          AarastSemanticTokens.brand,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          AarastSemanticTokens.brandAccentDecorative,
          AarastSemanticTokens.brand,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('resolves every active semantic role from V3 foundations', () {
      expect(AarastSemanticTokens.canvas, AarastV3Color.canvas);
      expect(AarastSemanticTokens.surface, AarastV3Color.paper);
      expect(AarastSemanticTokens.surfaceMuted, AarastV3Color.paperQuiet);
      expect(AarastSemanticTokens.textPrimary, AarastV3Color.ink);
      expect(AarastSemanticTokens.textSecondary, AarastV3Color.textMuted);
      expect(AarastSemanticTokens.border, AarastV3Color.line);
      expect(AarastSemanticTokens.brand, AarastV3Color.primary);
      expect(AarastSemanticTokens.focus, AarastV3Color.cobalt);
      expect(AarastSemanticTokens.success, AarastV3Color.mint);
      expect(AarastSemanticTokens.warning, AarastV3Color.amber);
      expect(AarastSemanticTokens.danger, AarastV3Color.danger);
    });

    test('exposes V3 roles through AppTheme for migrated screens', () {
      expect(AppTheme.canvas, AarastSemanticTokens.canvas);
      expect(AppTheme.surfaceRaised, AarastSemanticTokens.surfaceRaised);
      expect(AppTheme.surfaceMuted, AarastSemanticTokens.surfaceMuted);
      expect(AppTheme.textPrimary, AarastSemanticTokens.textPrimary);
      expect(AppTheme.textSecondary, AarastSemanticTokens.textSecondary);
      expect(AppTheme.brand, AarastSemanticTokens.brand);
      expect(AppTheme.focus, AarastSemanticTokens.focus);
      expect(AppTheme.radiusControl, AarastDesignTokens.radiusControl);
      expect(AppTheme.radiusSurface, AarastDesignTokens.radiusSurface);
      expect(AppTheme.radiusOverlay, AarastDesignTokens.radiusOverlay);
    });

    test('keeps the wedding identity semantic instead of feature aliases', () {
      final themeSource = File(
        'lib/core/theme/app_theme.dart',
      ).readAsStringSync();
      for (final retiredName in [
        'static const ivory',
        'static const burgundy',
        'static const gold',
        'static const deepBurgundy',
        'static const warmGold',
      ]) {
        expect(themeSource, isNot(contains(retiredName)), reason: retiredName);
      }
    });

    test('defines one spacing, shape, and motion scale', () {
      expect([
        AarastDesignTokens.space4,
        AarastDesignTokens.space8,
        AarastDesignTokens.space12,
        AarastDesignTokens.space16,
        AarastDesignTokens.space20,
        AarastDesignTokens.space24,
        AarastDesignTokens.space32,
        AarastDesignTokens.space40,
        AarastDesignTokens.space48,
      ], orderedEquals([4, 8, 12, 16, 20, 24, 32, 40, 48]));
      expect(
        AarastDesignTokens.radiusControl,
        lessThan(AarastDesignTokens.radiusSurface),
      );
      expect(
        AarastDesignTokens.radiusSurface,
        lessThan(AarastDesignTokens.radiusOverlay),
      );
      expect(AarastDesignTokens.motionQuick, AarastV3Motion.quick);
      expect(AarastDesignTokens.motionStandard, AarastV3Motion.standard);
    });
  });
}
