// R4: after offer_confirm_walk_test.dart, «اختر المصور» ended by itself.
// Run it right after that walk: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'groom: the booking finished the task that waited on it',
    (tester) async {
      final walk = JourneyWalk(tester, 'task_closed_by_booking');
      await walk.boot();
      await walk.signIn('777000101', pickContext: 'عرس محمد');

      await walk.step('t02_done', 'المهام: اللي خلصت', () async {
        await walk.tab('المهام');
        await walk.settle(seconds: 3);
        if (!await walk.tapText('اللي خلصت', wait: 3)) return;
        walk.expectSee('اختر المصور', why: 'المهمة انتهت مع الحجز');
      });

      await walk.step('t05_open', 'تفاصيل المهمة', () async {
        if (!await walk.tapText('اختر المصور', wait: 3)) return;
        walk.expectSee('انتهت لما انحجز البند', why: 'تقول سبب انتهائها');
      });

      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
