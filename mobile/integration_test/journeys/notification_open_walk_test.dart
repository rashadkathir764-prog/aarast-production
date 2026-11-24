// An offer's notification opened before the providers tab was ever visited:
// the page must read its own requests (R15).
// Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'every plan notice opens after returning from the previous one',
    (tester) async {
      final walk = JourneyWalk(tester, 'notification_return');
      await walk.boot();
      await walk.signIn('+967777000101', pickContext: 'عرس محمد');
      await walk.step('notices', 'فتح التنبيهات والرجوع بينها', () async {
        await walk.tapTooltip('التنبيهات', wait: 3);
        final home = walk.currentLocation();
        if (home == null) throw StateError('No notifications route');
        await walk.openEachNotice(keyPrefix: 'notification-', home: home);
      });
      final landings = walk.steps.last.notes;
      expect(landings.any((note) => note.contains('/money/costs/')), isTrue);
      expect(landings.any((note) => note.contains('/tasks/')), isTrue);
      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  testWidgets(
    'an offer notification opens its offers',
    (tester) async {
      final walk = JourneyWalk(tester, 'notification_open');
      await walk.boot();
      await walk.signIn('+967777000101', pickContext: 'عرس محمد');

      await walk.step('n01_list', 'التنبيهات قبل تبويب المزودين', () async {
        GoRouter.of(
          find.byType(Navigator).evaluate().first,
        ).go('/notifications');
        await walk.settle(seconds: 3);
      });
      await walk.step('n02_offer', 'افتح تنبيه العرض', () async {
        await walk.tapText('وصلك عرض', wait: 4);
        walk.expectNotSee('ما في طلبات لهذي الخدمة الحين.');
        walk.expectSee('عدسة سبأ');
      });
      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
