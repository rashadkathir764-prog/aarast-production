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

  testWidgets('an offer notification opens its offers', (tester) async {
    final walk = JourneyWalk(tester, 'notification_open');
    await walk.boot();
    await walk.signIn('+967777000101', pickContext: 'عرس محمد');

    await walk.step('n01_list', 'التنبيهات قبل تبويب المزودين', () async {
      GoRouter.of(find.byType(Navigator).evaluate().first).go('/notifications');
      await walk.settle(seconds: 3);
    });
    await walk.step('n02_offer', 'افتح تنبيه العرض', () async {
      await walk.tapText('وصلك عرض', wait: 4);
      walk.expectNotSee('ما في طلبات لهذي الخدمة الآن.');
      walk.expectSee('عدسة سبأ');
    });
    await walk.finish();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
