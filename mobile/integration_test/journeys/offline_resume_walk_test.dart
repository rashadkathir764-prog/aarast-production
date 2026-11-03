// D85: after the offline walk, the server answers again: what was kept on
// the phone is sent, the banner goes, and the guest added without the
// server is on the server's list.
// Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the server answers again and the phone sends what waited', (
    tester,
  ) async {
    final walk = JourneyWalk(tester, 'offline_resume');
    await walk.boot(keepLocalData: true);

    await walk.step('r01_home', 'الرئيسية والخادم رجع', () async {
      await walk.waitFor(walk.text('الرئيسية'), seconds: 20);
      await walk.settle(seconds: 6);
      walk.expectSee('عرس محمد');
      walk.expectNotSee(
        'ما نقدر نوصل للخادم الحين',
        why: 'أول رد من الخادم ينهي الحالة',
      );
    });

    await walk.step('r02_guest_synced', 'الضيف وصل للخادم', () async {
      await walk.tab('الضيوف');
      await walk.settle(seconds: 3);
      await walk.tapText('كل الضيوف', wait: 3);
      walk.expectSee('ضيف بدون نت', why: 'الضيف المحفوظ بدون خادم صار عند الخادم');
      if (find.byKey(const ValueKey('aarast-sync-status')).evaluate().isNotEmpty &&
          walk.sees('تنحفظ في جوالك')) {
        walk.fail('ما زال التطبيق يقول إن التغيير ينتظر بعد رجوع الخادم');
      }
    });
    await walk.finish();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
