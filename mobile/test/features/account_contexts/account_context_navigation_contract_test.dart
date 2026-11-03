import 'dart:io';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/library_source.dart';

void main() {
  test(
    'session and account-context gates own post-auth dashboard resolution',
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
      final app = File('lib/app.dart').readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();
      final selection = File(
        'lib/features/account_contexts/screens/'
        'account_context_selection_screen.dart',
      ).readAsStringSync();
      final entryGate = File(
        'lib/features/account_contexts/widgets/account_context_entry_gate.dart',
      ).readAsStringSync();

      expect(dashboard, isNot(contains('isProviderAccount')));
      expect(dashboard, isNot(contains('ProviderPortalScreen')));
      expect(login, isNot(contains('isProviderAccount')));
      expect(otp, isNot(contains('isProviderAccount')));
      expect(dashboard, contains('AccountContextEntryGate'));
      expect(main, contains('AarastSessionBoundary('));
      expect(app, contains('class AarastAuthFlowRedirector'));
      expect(
        selection,
        isNot(contains('context.go(')),
        reason:
            'AccountContextSelectionScreen must only publish the selected '
            'context.',
      );
      expect(entryGate, contains('AppRouter.providerDashboard'));
      expect(entryGate, contains('MainShell('));
      expect(
        File(
          'lib/features/shell/widgets/plan_shell_chrome.dart',
        ).readAsStringSync(),
        isNot(contains('AccountContextSwitcher')),
      );
      expect(
        File(
          'lib/features/provider_portal/screens/provider_portal_screen.dart',
        ).readAsStringSync(),
        isNot(contains('AccountContextSwitcher')),
      );
    },
  );

  test(
    'LoginScreen publishes auth success without navigating its old router',
    () {
      final login = File(
        'lib/features/auth/screens/login_screen.dart',
      ).readAsStringSync();
      final app = File('lib/app.dart').readAsStringSync();
      final loginSubmit = _sourceBetween(
        login,
        'Future<void> _submit()',
        'Future<void> _requestLoginOtp(',
      );

      expect(app, contains('class AarastAuthFlowRedirector'));
      _expectNoDirectNavigation(loginSubmit, owner: 'LoginScreen._submit');
    },
  );

  test(
    'OtpScreen publishes auth success without navigating its old router',
    () {
      final otp = File(
        'lib/features/auth/screens/otp_screen.dart',
      ).readAsStringSync();
      final app = File('lib/app.dart').readAsStringSync();
      final otpVerification = _sourceBetween(
        otp,
        'Future<void> _verifyOtp()',
        'void _goBack()',
      );

      expect(app, contains('class AarastAuthFlowRedirector'));
      _expectNoDirectNavigation(otpVerification, owner: 'OtpScreen._verifyOtp');
    },
  );

  final logoutCases =
      <({String name, String path, String startMarker, String endMarker})>[
        (
          name: 'ProviderSettingsScreen._logout',
          path:
              'lib/features/provider_portal/screens/provider_settings_screen.dart',
          startMarker: 'Future<String?> _logout()',
          // D63: deleting opens w05; _logout is the class's last method.
          endMarker: 'bool _devicePushAvailable(BuildContext context)',
        ),
        (
          name: 'MoreScreen._logout',
          path: 'lib/features/more/screens/more_screen.dart',
          startMarker: 'static Future<void> _logout(BuildContext context)',
          endMarker: 'Future<void> _changeAvatar(BuildContext context)',
        ),
      ];

  for (final logoutCase in logoutCases) {
    test('${logoutCase.name} delegates navigation to AuthFlowRedirector', () {
      final app = File('lib/app.dart').readAsStringSync();
      expect(app, contains('class AarastAuthFlowRedirector'));
      expect(app, contains('claimLoginAfterLogout()'));
      expect(app, contains('router.go(AppRouter.login)'));

      // A logout flow may live in a part of its screen library (spec M6).
      final source = readLibrarySource(logoutCase.path);
      final action = _sourceBetween(
        source,
        logoutCase.startMarker,
        logoutCase.endMarker,
      );
      _expectNoDirectNavigation(action, owner: logoutCase.name);
    });
  }

  test(
    'provider application refreshes user then contexts before the portal',
    () {
      for (final path in [
        'lib/features/provider_portal/screens/provider_apply_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final refreshUser = source.indexOf('await auth.refreshCurrentUser()');
        final refreshContexts = source.indexOf(
          'await accountContexts.refresh(',
          refreshUser < 0 ? 0 : refreshUser,
        );
        final statusNavigation = source.indexOf(
          'context.go(AppRouter.providerDashboard)',
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
    // The router's route trees live in per-area part files of the router
    // library (spec M6); the contract reads the whole library.
    final router = readLibrarySource('lib/core/routing/app_router.dart');
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
      '/wedding-plans/:id/events',
      '/wedding-plans/:id/moments/:moment',
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

  test('provider portal trusts the resolved account-context gate', () {
    final source = File(
      'lib/features/provider_portal/screens/provider_portal_screen.dart',
    ).readAsStringSync();
    final initializePortal = _sourceBetween(
      source,
      'Future<void> _initializePortal()',
      'void _openTab(',
    );

    expect(
      initializePortal,
      isNot(contains('AccountContextController')),
      reason:
          'The portal is reachable only after AccountContextEntryGate has '
          'resolved the provider context.',
    );
    expect(initializePortal, isNot(contains('.refresh()')));
  });

  test('plan route access classification is explicit and fail-closed', () {
    final cases = <String, WeddingPlanRouteAccess>{
      '/wedding-plans/plan-1/dashboard': WeddingPlanRouteAccess.ownerDashboard,
      '/wedding-plans/plan-1/plan-center': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/events': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/moments/day': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/timeline': WeddingPlanRouteAccess.manageTasks,
      '/wedding-plans/plan-1/notifications': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/contributions': WeddingPlanRouteAccess.viewPlan,
      // D52: every member reads the tasks, the guests and the bookings, so a
      // tab's root and a task's page need the plan only; writing needs the
      // section's right. One mapping, the same for the gate and for a resume.
      '/wedding-plans/plan-1/tasks': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/tasks/task-1': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/tasks/create': WeddingPlanRouteAccess.manageTasks,
      '/wedding-plans/plan-1/tasks/task-1/edit':
          WeddingPlanRouteAccess.manageTasks,
      '/wedding-plans/plan-1/guests': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/guests/add': WeddingPlanRouteAccess.manageGuests,
      '/wedding-plans/plan-1/guests/view/guest-1':
          WeddingPlanRouteAccess.manageGuests,
      '/wedding-plans/plan-1/providers': WeddingPlanRouteAccess.viewPlan,
      '/wedding-plans/plan-1/providers/requests':
          WeddingPlanRouteAccess.manageProviders,
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

String _sourceBetween(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start + startMarker.length);
  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: 'Missing marker: $startMarker',
  );
  expect(end, greaterThan(start), reason: 'Missing marker: $endMarker');
  return source.substring(start, end);
}

void _expectNoDirectNavigation(String source, {required String owner}) {
  expect(
    source,
    isNot(contains('context.go(')),
    reason:
        '$owner must publish state only; the surviving central router owns '
        'navigation.',
  );
  expect(
    source,
    isNot(contains('router.go(')),
    reason: '$owner must not use a router captured from a disposed subtree.',
  );
  expect(
    source,
    isNot(contains('pushReplacement')),
    reason: '$owner must not replace routes on the outgoing router.',
  );
}
