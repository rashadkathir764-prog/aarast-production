import 'dart:io';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'post-auth entry never treats the legacy SafeUser provider role as exclusive authority',
    () {
      final dashboard = File(
        'lib/features/home/screens/dashboard_entry_screen.dart',
      ).readAsStringSync();
      final login = File(
        'lib/features/auth/screens/login_screen.dart',
      ).readAsStringSync();
      final otp = File(
        'lib/features/auth/screens/otp_screen.dart',
      ).readAsStringSync();

      expect(dashboard, isNot(contains('isProviderAccount')));
      expect(dashboard, isNot(contains('ProviderPortalScreen')));
      expect(login, isNot(contains('isProviderAccount')));
      expect(otp, isNot(contains('isProviderAccount')));
      expect(login, contains('AppRouter.authenticatedEntry('));
      expect(
        otp,
        contains('AppRouter.authenticatedEntry(widget.successLocation)'),
      );
      expect(dashboard, contains('AccountContextEntryGate'));
      expect(
        File(
          'lib/features/shell/widgets/plan_shell_chrome.dart',
        ).readAsStringSync(),
        isNot(contains('AccountContextSwitcher')),
      );
      expect(
        File(
          'lib/features/marketplace/screens/provider_portal_screen.dart',
        ).readAsStringSync(),
        isNot(contains('AccountContextSwitcher')),
      );
    },
  );

  test(
    'provider application refreshes user then contexts before status navigation',
    () {
      for (final path in [
        'lib/features/marketplace/screens/provider_apply_screen.dart',
        'lib/features/auth/screens/otp_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final refreshUser = source.indexOf('await auth.refreshCurrentUser()');
        final refreshContexts = source.indexOf(
          'await accountContexts.refresh(',
          refreshUser < 0 ? 0 : refreshUser,
        );
        final statusNavigation = source.indexOf(
          'context.go(AppRouter.providerApplyStatus)',
          refreshContexts < 0 ? 0 : refreshContexts,
        );

        expect(refreshUser, greaterThanOrEqualTo(0), reason: path);
        expect(refreshContexts, greaterThan(refreshUser), reason: path);
        expect(statusNavigation, greaterThan(refreshContexts), reason: path);
        expect(
          source,
          isNot(contains('activeWeddingPlanId:')),
          reason: '$path must not derive context from legacy active-plan data',
        );
      }
    },
  );

  test('all plan routes validate selectedContext before building', () {
    final router = File('lib/core/routing/app_router.dart').readAsStringSync();
    final gate = File(
      'lib/features/account_contexts/widgets/wedding_plan_context_gate.dart',
    ).readAsStringSync();
    final shell = File('lib/features/shell/main_shell.dart').readAsStringSync();

    expect(gate, isNot(contains('controller.select(')));
    expect(gate, isNot(contains('openReadOnlyContext(')));
    expect(shell, contains('AccountContextController'));
    expect(shell, isNot(contains('activePlan?.id')));

    for (final path in [
      '/wedding-plans/:id/plan-center',
      '/wedding-plans/:id/tasks/create',
      '/wedding-plans/:id/tasks/:taskId/edit',
      '/wedding-plans/:id/timeline',
      '/wedding-plans/:id/sharing',
      '/wedding-plans/:id/notifications',
      '/wedding-plans/:id/sharing/add',
      '/wedding-plans/:id/sharing/:memberId/edit',
    ]) {
      final start = router.indexOf("path: '$path'");
      expect(start, greaterThanOrEqualTo(0), reason: path);
      final nextRoute = router.indexOf('GoRoute(', start + 8);
      final routeBlock = router.substring(
        start,
        nextRoute < 0 ? router.length : nextRoute,
      );
      expect(routeBlock, contains('WeddingPlanContextGate('), reason: path);
    }

    final quoteStart = router.indexOf("path: '/providers/:id/quote'");
    final quoteEnd = router.indexOf('GoRoute(', quoteStart + 8);
    expect(
      router.substring(quoteStart, quoteEnd),
      contains('SelectedWeddingPlanContextGate('),
    );
  });

  test('plan route access classification is explicit and fail-closed', () {
    final cases = <String, WeddingPlanRouteAccess>{
      '/wedding-plans/plan-1/dashboard': WeddingPlanRouteAccess.ownerDashboard,
      '/wedding-plans/plan-1/plan-center': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/timeline': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/notifications': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/tasks': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/tasks/create': WeddingPlanRouteAccess.manageTasks,
      '/wedding-plans/plan-1/tasks/task-1/edit':
          WeddingPlanRouteAccess.manageTasks,
      '/wedding-plans/plan-1/guests': WeddingPlanRouteAccess.manageGuests,
      '/wedding-plans/plan-1/guests/add': WeddingPlanRouteAccess.manageGuests,
      '/wedding-plans/plan-1/providers': WeddingPlanRouteAccess.manageProviders,
      '/wedding-plans/plan-1/sharing': WeddingPlanRouteAccess.inviteMembers,
      '/wedding-plans/plan-1/sharing/add': WeddingPlanRouteAccess.inviteMembers,
      '/wedding-plans/plan-1/money': WeddingPlanRouteAccess.viewMoney,
      '/wedding-plans/plan-1/money/costs/cost-1':
          WeddingPlanRouteAccess.viewMoney,
      '/wedding-plans/plan-1/money/costs/create':
          WeddingPlanRouteAccess.manageMoney,
      '/wedding-plans/plan-1/money/costs/cost-1/edit':
          WeddingPlanRouteAccess.manageMoney,
      '/wedding-plans/plan-1/money/costs/cost-1/payments/pay':
          WeddingPlanRouteAccess.manageMoney,
      '/wedding-plans/plan-1/unknown': WeddingPlanRouteAccess.unknown,
    };

    for (final entry in cases.entries) {
      expect(
        weddingPlanRouteAccessForPath(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });
}
