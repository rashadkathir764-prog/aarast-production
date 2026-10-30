// The owner's video of 2026-10-31: from the providers tab to a service's
// requests, then «شوف البند في المال». The screen went black for 2.4 seconds.
// The requests page sits above the plan's shell, so the money page must not
// push the shell a second time (R2).
// Run: see docs/qa/JOURNEY_WALKS.md («إعادة التشغيل»).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'providers tab inside the shell, requests, then the item in the money',
    (tester) async {
      final walk = JourneyWalk(tester, 'view_cost_from_requests');
      await walk.boot();
      await walk.signIn('777000101', pickContext: 'عرس محمد');

      await walk.step('shell_tab', 'تبويب المزودين داخل الهيكل', () async {
        // The home's next step reaches it with context.go, like this.
        await walk.leaveTo('/wedding-plans/demo_plan_groom/providers');
        walk.expectSee('طلباتي');
      });

      await walk.step('requests', 'طلبات القاعة', () async {
        await walk.tapText('القاعة', wait: 4);
        walk.expectSee('شوف البند في المال');
      });

      await walk.step('view_cost', 'شوف البند في المال', () async {
        final seen = <Object>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) => seen.add(details.exception);
        await walk.tapText('شوف البند في المال', wait: 5);
        FlutterError.onError = previous;
        if (seen.isNotEmpty) {
          walk.fail(
            'خطأ في التنقل: ${seen.first.toString().split('\n').first}',
          );
        }
        if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
          walk.fail('خطأ بناء في الشاشة');
        }
        walk.expectSee('الاتفاق');
        walk.note(walk.visibleTexts().take(14).join(' · '));
      });

      await walk.step('back', 'ارجع', () async {
        await walk.back();
        if (walk.visibleTexts().isEmpty) walk.fail('شاشة فارغة بعد الرجوع');
        walk.note(walk.visibleTexts().take(10).join(' · '));
      });

      // The owner: after it, any other screen came up black too.
      await walk.step('after_tabs', 'الشاشات بعدها', () async {
        for (final tab in [
          'الرئيسية',
          'المال',
          'المهام',
          'الضيوف',
          'المزودين',
        ]) {
          await walk.tab(tab, wait: 2);
          if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
            walk.fail('خطأ بناء بعد الرجوع في تبويب $tab');
          }
          if (walk.visibleTexts().length < 4) {
            walk.fail('تبويب $tab فارغ بعد الرجوع');
          }
        }
      });

      await walk.step('again', 'نفس الطريق مرة ثانية', () async {
        await walk.tapText('القاعة', wait: 4);
        await walk.tapText('شوف البند في المال', wait: 5);
        walk.expectSee('الاتفاق');
        await walk.back();
        if (walk.visibleTexts().isEmpty)
          walk.fail('شاشة فارغة في المرة الثانية');
      });

      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
