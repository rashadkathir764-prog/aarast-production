// Opens every route of the groom's plan with real ids against the local API
// and marks a route that lands on the error page, shows a build error, or
// paints nothing to read. A blank route is the first thing a person sees as a
// «شاشة سوداء». The ids come from the demo seed:
//   --dart-define=AARAST_SWEEP_IDS=planId=...,costId=...,...
// Run: see docs/qa/JOURNEY_WALKS.md («إعادة التشغيل»).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

const _sweepIds = String.fromEnvironment('AARAST_SWEEP_IDS');

/// Every route a signed-in groom can reach. The sign-in, the provider portal
/// and the participant's own pages are walked in their own journeys, and
/// `/dev/*` is not a person's route.
const _routes = [
  '/home',
  '/more',
  '/notifications',
  '/invites',
  '/conversations',
  '/conversations/:conversationId',
  '/settings',
  '/settings/lock',
  '/settings/privacy',
  '/settings/connection',
  '/settings/delete-account',
  '/support',
  '/providers',
  '/providers/favorites',
  '/providers/:providerId',
  '/providers/:providerId/quote',
  '/quotes/:quoteId/conversation',
  '/wedding-plans',
  '/wedding-plans/create',
  '/wedding-plans/:planId/dashboard',
  '/wedding-plans/:planId/assistant',
  '/wedding-plans/:planId/contributions',
  '/wedding-plans/:planId/events',
  '/wedding-plans/:planId/guests',
  '/wedding-plans/:planId/guests/add',
  '/wedding-plans/:planId/guests/attendance',
  '/wedding-plans/:planId/guests/import',
  '/wedding-plans/:planId/guests/invite',
  '/wedding-plans/:planId/guests/view/:guestId',
  '/wedding-plans/:planId/moments/week',
  '/wedding-plans/:planId/moments/day',
  '/wedding-plans/:planId/money',
  '/wedding-plans/:planId/money/budget',
  '/wedding-plans/:planId/money/categories/:categoryId',
  '/wedding-plans/:planId/money/categories/:categoryId/edit',
  '/wedding-plans/:planId/money/categories/create',
  '/wedding-plans/:planId/money/costs/:costId',
  '/wedding-plans/:planId/money/costs/:costId/edit',
  '/wedding-plans/:planId/money/costs/:costId/payments/create',
  '/wedding-plans/:planId/money/costs/:costId/schedules/:scheduleId',
  '/wedding-plans/:planId/money/costs/:costId/schedules/:scheduleId/pay',
  '/wedding-plans/:planId/money/costs/create',
  '/wedding-plans/:planId/money/funding',
  '/wedding-plans/:planId/money/mahr',
  '/wedding-plans/:planId/money/mahr/moment',
  '/wedding-plans/:planId/money/payers',
  '/wedding-plans/:planId/money/payments/:paymentId',
  '/wedding-plans/:planId/money/receipts',
  '/wedding-plans/:planId/notifications',
  '/wedding-plans/:planId/plan-center',
  '/wedding-plans/:planId/providers',
  '/wedding-plans/:planId/providers/booked/:bookedQuoteId',
  '/wedding-plans/:planId/providers/bookings',
  '/wedding-plans/:planId/providers/requests',
  '/wedding-plans/:planId/providers/reviews',
  '/wedding-plans/:planId/sharing',
  '/wedding-plans/:planId/sharing/:memberId/edit',
  '/wedding-plans/:planId/sharing/add',
  '/wedding-plans/:planId/tasks',
  '/wedding-plans/:planId/tasks/:taskId',
  '/wedding-plans/:planId/tasks/:taskId/edit',
  '/wedding-plans/:planId/tasks/create',
  '/wedding-plans/:planId/timeline',
];

Map<String, String> _ids() => {
  for (final pair in _sweepIds.split(','))
    if (pair.contains('='))
      pair.substring(0, pair.indexOf('=')): pair.substring(
        pair.indexOf('=') + 1,
      ),
};

String _fill(String route, Map<String, String> ids) => route.replaceAllMapped(
  RegExp(r':(\w+)'),
  (match) => ids[match[1]] ?? (throw StateError('No id for ${match[1]}')),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'every route of the groom opens with something to read',
    (tester) async {
      final ids = _ids();
      final walk = JourneyWalk(tester, 'route_sweep');
      await walk.boot();
      await walk.signIn('+967777000101', pickContext: 'عرس محمد');

      for (final route in _routes) {
        await walk.step(route, 'يفتح $route', () async {
          final location = _fill(route, ids);
          GoRouter.of(find.byType(Navigator).evaluate().first).go(location);
          await walk.settle(seconds: 3);

          final errorPage = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == 'RouterErrorScreen',
          );
          if (errorPage.evaluate().isNotEmpty) walk.fail('صفحة الخطأ');
          if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
            walk.fail('خطأ بناء في الشاشة');
          }
          final readable = walk.visibleTexts();
          if (readable.isEmpty) walk.fail('شاشة بلا أي نص');
          if (readable.length < 3) {
            walk.note('نص قليل: ${readable.join(' · ')}');
          }
        });
      }
      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
