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

    test('removed route aliases and dead UI variants cannot return', () {
      final router = File(
        '${mobileRoot}lib/core/routing/app_router.dart',
      ).readAsStringSync();
      expect(router, isNot(contains('legacyProviderDashboard')));
      expect(router, isNot(contains("'/provider-dashboard'")));

      for (final removedPath in <String>[
        'lib/core/widgets/primary_action_button.dart',
        'lib/features/finance/widgets/budget_category_card.dart',
        'test/goldens/premium_debts_on_track.png',
        'test/goldens/premium_debts_overdue.png',
      ]) {
        expect(
          File('$mobileRoot$removedPath').existsSync(),
          isFalse,
          reason:
              '$removedPath is a deleted legacy artifact and must stay deleted.',
        );
      }
    });

    test('old dashboard widget variants stay deleted or unreachable', () {
      final legacyDashboardVariant = File(
        '${mobileRoot}lib/features/wedding_plans/widgets/new_dashboard_widgets.dart',
      );
      expect(
        legacyDashboardVariant.existsSync(),
        isFalse,
        reason:
            'new_dashboard_widgets.dart was an unused dashboard variant. '
            'The canonical production dashboard lives in '
            'PremiumDashboardView (premium/) and royal_home_chrome.dart.',
      );

      final legacyDashboardBundle = File(
        '${mobileRoot}lib/features/wedding_plans/widgets/'
        'aarast_dashboard_widgets.dart',
      );
      expect(
        legacyDashboardBundle.existsSync(),
        isFalse,
        reason:
            'The 3,611-line legacy dashboard bundle must stay deleted. '
            'My Plans imports the extracted account_sheet.dart directly.',
      );

      final legacyProviderDashboard = File(
        '${mobileRoot}lib/features/marketplace/screens/'
        'provider_dashboard_screen.dart',
      );
      expect(
        legacyProviderDashboard.existsSync(),
        isFalse,
        reason:
            'ProviderPortalScreen is the only routed provider dashboard. '
            'The unreachable legacy implementation must stay deleted.',
      );

      final planCenter = File(
        '${mobileRoot}lib/features/wedding_plans/screens/plan_center_screen.dart',
      ).readAsStringSync();
      expect(
        planCenter,
        isNot(contains('AppRouter.createWeddingPlan')),
        reason:
            'Plan Center must not expose create-plan as a quick operational '
            'action. Plan creation belongs to onboarding or More -> My Plans.',
      );
    });

    test('more screen does not expose operational quick actions', () {
      final moreScreen = File(
        '${mobileRoot}lib/features/more/screens/more_screen.dart',
      ).readAsStringSync();
      final forbiddenRoutes = <String>[
        'AppRouter.createExpense',
        'AppRouter.createDebt',
        'AppRouter.createTask',
        'AppRouter.guestList',
        'AppRouter.providerQuote',
        'AppRouter.providerQuoteRequest',
      ];

      for (final route in forbiddenRoutes) {
        expect(
          moreScreen,
          isNot(contains(route)),
          reason:
              'More must stay account/settings/support/legal/provider-entry '
              'only, not an operational dashboard shortcut surface.',
        );
      }
    });

    test(
      'wedding-user marketplace does not expose provider dashboard actions',
      () {
        final marketplace = File(
          '${mobileRoot}lib/features/marketplace/screens/provider_marketplace_screen.dart',
        ).readAsStringSync();
        final forbiddenProviderOps = <String>[
          'ProviderDashboardScreen',
          'ProviderApplyScreen',
          'ProviderApplyStatusScreen',
          'AddProviderServiceScreen',
          'AddProviderPackageScreen',
          'AppRouter.providerApply',
          'AppRouter.providerApplyStatus',
          'AppRouter.providerDashboard',
          'AppRouter.providerServiceNew',
          'AppRouter.providerPackageNew',
          'طلب الانضمام كمزود',
          'إنشاء حساب كمزود',
        ];

        for (final operation in forbiddenProviderOps) {
          expect(
            marketplace,
            isNot(contains(operation)),
            reason:
                'The wedding-user marketplace must browse providers and request '
                'quotes, not expose provider business-dashboard operations.',
          );
        }
      },
    );

    test(
      'production screens do not use اختياري as the displayed saved value',
      () {
        final libRoot = Directory('${mobileRoot}lib');
        final offenders = <String>[];
        for (final entity in libRoot.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart')) continue;
          if (entity.path.contains(
            '${Platform.pathSeparator}test${Platform.pathSeparator}',
          )) {
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

    test('production copy does not leak local or permission debug labels', () {
      final libRoot = Directory('${mobileRoot}lib');
      final forbiddenPhrases = <String>['تجربة محلية', 'صلاحيات محلية'];
      final offenders = <String>[];

      for (final entity in libRoot.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trim().startsWith('//')) continue;
          for (final phrase in forbiddenPhrases) {
            if (!line.contains(phrase)) continue;
            offenders.add('${entity.path}:${i + 1} [$phrase]: ${line.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Production mobile copy must use product language for guest and '
            'permission states, not local/debug labels.',
      );
    });

    test('production copy does not leak feminine-only CTAs in non-bride '
        'persona-neutral surfaces', () {
      final libRoot = Directory('${mobileRoot}lib');
      final feminineWords = <String>[
        'أنشئي',
        'سجلي',
        'تابعي',
        'اختاري',
        'اكتشفي',
        'تأكدي',
        'تحتاجين',
        'تحتاجينه',
        'أضيفي',
        'تضيفي',
        'حددي',
        'تستطيعين',
        'ستتمكنين',
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
        final isScreen = entity.path.contains(
          '${Platform.pathSeparator}screens${Platform.pathSeparator}',
        );
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
            offenders.add('${entity.path}:${i + 1} [$word]: ${line.trim()}');
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
    });
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
