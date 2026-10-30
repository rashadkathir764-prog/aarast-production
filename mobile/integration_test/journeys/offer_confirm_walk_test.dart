// The studio confirms the booking offer_to_booking_walk_test.dart asked for.
// It changes the demo data: run `npm run seed` in backend/ after it.
// Run: see docs/qa/JOURNEY_WALKS.md («إعادة التشغيل»).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'studio: confirm the booking the groom asked for',
    (tester) async {
      final walk = JourneyWalk(tester, 'offer_confirm');
      await walk.boot();
      await walk.signIn('777000201');

      await walk.step('p08_home', 'الرئيسية: طلب حجز ينتظر', () async {
        walk.note(walk.visibleTexts().take(20).join(' · '));
      });

      await walk.step('p15_requests', 'الطلبات', () async {
        await walk.tab('الطلبات');
        walk.note(walk.visibleTexts().take(24).join(' · '));
      });

      await walk.step('p16_open', 'افتح طلب محمد', () async {
        await walk.tapText('طلب حجز', required: false, wait: 2.5);
        await walk.tapText('محمد', wait: 3);
        walk.note(walk.visibleTexts().take(24).join(' · '));
      });

      await walk.step('p22_confirm', 'أكّد الحجز', () async {
        // The request opens with this sheet up.
        final confirm = find.byWidgetPredicate((widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith('provider-booking-confirm-');
        });
        if (confirm.evaluate().isEmpty) {
          walk.fail('ما فتحت نافذة التأكيد');
          return;
        }
        await tester.tap(confirm.first, warnIfMissed: false);
        await walk.settle(seconds: 5);
        walk.note(walk.visibleTexts().take(24).join(' · '));
        walk.expectNotSee(
          'نتأكد إن اليوم فاضي',
          why: 'النافذة لازم تقفل بعد التأكيد',
        );
      });

      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
