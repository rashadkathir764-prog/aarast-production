// Mobile truth-cleanup invariants.
//
// These tests lock in the canonical screen content cleanup that prevents
// regressions of the issues listed in
// docs/mobile-ux/AARAST_FULL_SCREEN_TRUTH_AUDIT.md.
//
// Scope: production-reachable Arabic copy inside lib/features/** and
// lib/core/widgets/**. Test code (test/**) is excluded on purpose so it
// can keep asserting the exact copy it depends on.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Resolve the mobile/lib root once; tests below scan only that subtree.
  final mobileRoot = _findMobileRoot();

  group('mobile truth cleanup', () {
    test('no legacy auth onboarding screen is reachable', () {
      final legacy = File(
        '${mobileRoot}lib/features/auth/screens/onboarding_screen.dart',
      );
      expect(
        legacy.existsSync(),
        isFalse,
        reason:
            'legacy auth/screens/onboarding_screen.dart must stay deleted '
            '(zero callers confirmed during cleanup). The canonical '
            'onboarding lives at lib/features/onboarding/screens/.',
      );
    });

    test(
      'production screens do not use اختياري as the displayed saved value',
      () {
        final libRoot = Directory('${mobileRoot}lib');
        final offenders = <String>[];
        for (final entity in libRoot.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart')) continue;
          if (entity.path.contains('${Platform.pathSeparator}test${Platform.pathSeparator}')) {
            continue;
          }
          // _SelectorField uses value: x == null ? 'اختياري' : ... as the
          // displayed empty value. After cleanup those should read
          // 'لم يحدد بعد' instead. Any other UI surface that displays the
          // bare word 'اختياري' as a saved value is also a violation.
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (!line.contains('اختياري')) continue;
            if (line.trim().startsWith('//')) continue;
            // Allow labels that explicitly mark a hint/optional field input.
            if (line.contains('labelText:') ||
                line.contains('label:') ||
                line.contains('hintText:')) {
              continue;
            }
            offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'اختياري must not appear as a displayed saved value in '
              'production-reachable widgets. Use لم يحدد بعد or hide the row.',
        );
      },
    );

    test(
      'production copy does not leak feminine-only CTAs in non-bride '
      'persona-neutral surfaces',
      () {
        final libRoot = Directory('${mobileRoot}lib');
        final feminineWords = <String>[
          'تابعي',
          'اختاري',
          'أضيفي',
          'حددي',
          'تستطيعين',
          'تواصلي',
          'ابدئي',
          'ابحثي',
          'ارسلي',
          'افتحي',
          'راجعي',
        ];
        final offenders = <String>[];
        for (final entity in libRoot.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart')) continue;
          // Only audit production-reachable screens and shared widgets.
          final isScreen =
              entity.path.contains('${Platform.pathSeparator}screens${Platform.pathSeparator}');
          final isSharedWidget = entity.path.contains(
            '${Platform.pathSeparator}shared${Platform.pathSeparator}widgets${Platform.pathSeparator}',
          );
          if (!isScreen && !isSharedWidget) continue;
          // The persona_copy registry legitimately keeps bride-form copy
          // because it is selected by user persona. Skip it so the
          // gender-aware branch stays intentional.
          if (entity.path.endsWith('persona_copy.dart')) continue;
          // The legacy onboarding_screen.dart has been deleted; this guard
          // keeps the test green if the file ever returns.
          if (entity.path.endsWith('auth/screens/onboarding_screen.dart')) {
            continue;
          }

          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.trim().startsWith('//')) continue;
            for (final word in feminineWords) {
              if (!line.contains(word)) continue;
              offenders.add(
                '${entity.path}:${i + 1} [$word]: ${line.trim()}',
              );
            }
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'Production-reachable screens should use neutral Arabic CTAs. '
              'Bride-form copy is only valid inside persona_copy.dart.',
        );
      },
    );
  });
}

String _findMobileRoot() {
  // tests run from mobile/ ; ensure we look at the same tree.
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  // Fallback: assume cwd is the repo root.
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
