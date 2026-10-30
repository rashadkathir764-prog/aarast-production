// The groom picks an offer and asks for the booking, and this walk SAVES: the
// offer becomes an item in the money, and the provider receives the request.
// offer_confirm_walk_test.dart then confirms it from the provider's side.
// It changes the demo data: run `npm run seed` in backend/ after it.
// Run: see docs/qa/JOURNEY_WALKS.md («إعادة التشغيل»).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'groom: compare, choose an offer, ask for the booking',
    (tester) async {
      final walk = JourneyWalk(tester, 'offer_to_booking');
      await walk.boot();
      await walk.signIn('777000101', pickContext: 'عرس محمد');

      await walk.step('f01_board', 'المزودين: طلباتي', () async {
        await walk.tab('المزودين');
        walk.expectSee('عرضين وصلوا');
      });

      await walk.step('f04_compare', 'قارن العرضين', () async {
        await walk.tapText('قارن', wait: 3.5);
        walk.note(walk.visibleTexts().take(24).join(' · '));
      });

      await walk.step('f05_choose', 'اختر هذا', () async {
        // The studio has an account to confirm from; «عدسة سبأ» is unclaimed.
        await walk.tapText('اختر هذا', last: true, wait: 4);
        walk.note(walk.visibleTexts().take(24).join(' · '));
      });

      await walk.step('f05_book', 'اطلب الحجز', () async {
        await walk.tapText('اطلب الحجز', last: true, wait: 5);
        walk.note(walk.visibleTexts().take(24).join(' · '));
      });

      await walk.step('f05_cost', 'البند ظهر في المال', () async {
        await walk.tapText('شوف البند في المال', wait: 3.5);
        walk.note(walk.visibleTexts().take(20).join(' · '));
      });

      await walk.step('f05_back', 'ارجع من البند', () async {
        await walk.back();
        walk.note(walk.visibleTexts().take(14).join(' · '));
        if (walk.visibleTexts().isEmpty) walk.fail('شاشة بلا نص بعد الرجوع');
      });

      await walk.step('c02_items', 'المال يعرف العرض', () async {
        await walk.leaveTo('/home');
        await walk.tab('المال');
        await walk.tapText('البنود', required: false);
        walk.note(walk.visibleTexts().take(30).join(' · '));
      });

      await walk.step('b02_home', 'الرئيسية تعرف الاختيار', () async {
        await walk.tab('الرئيسية');
        walk.note(walk.visibleTexts().take(30).join(' · '));
      });

      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
