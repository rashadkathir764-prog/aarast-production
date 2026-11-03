// A new groom from the first screen, and this walk SAVES: a plan, an account,
// an agreement, a payment, a guest and a task, then checks each one reached
// the screens that should know about it. These are the tasks real people get
// in stage 4 (D67), so a step that stops here would stop them too.
// Run: see docs/qa/JOURNEY_WALKS.md («إعادة التشغيل»).
import 'package:aarast_mobile/core/utils/arabic_date_formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh groom: first screen to a plan with money, guests and tasks',
    (tester) async {
      final walk = JourneyWalk(tester, 'fresh_groom');
      final stamp = DateTime.now().millisecondsSinceEpoch % 10000000;
      final phone = '77${stamp.toString().padLeft(7, '0')}';
      await walk.boot();

      Future<void> fillNth(int index, String value) async {
        final fields = find.byType(EditableText);
        if (fields.evaluate().length <= index) {
          walk.fail('ما فيه حقل رقم ${index + 1}');
          return;
        }
        await tester.enterText(fields.at(index), value);
        await tester.pump(const Duration(milliseconds: 200));
      }

      await walk.step('a01_start', 'أول شاشة: أسوّي خطة عرسي', () async {
        await walk.tapKey('door-plan');
      });

      await walk.step('a02_whose', 'العريس', () async {
        await walk.tapKey('persona-groom');
      });

      // The screen shows this month and the five after it, so the walk
      // picks the month after next and the 15th in it, whatever today is.
      final now = DateTime.now();
      final weddingMonth = DateTime(now.year, now.month + 2);
      final weddingDay = DateTime(weddingMonth.year, weddingMonth.month, 15);

      await walk.step('a03_name_date', 'الاسم والشهر', () async {
        await fillNth(0, 'سامي');
        walk.expectSee('خطتك بتكون', why: 'الاسم يرسم عنوان الخطة');
        await walk.tapText(arabicMonthName(weddingMonth.month));
        // The month opens its calendar; a person picks the day. Each day
        // names itself for the screen reader, so the Hijri captions are
        // never mistaken for it.
        final day = find.bySemanticsLabel(
          RegExp(RegExp.escape(formatArabicWeekdayDayMonth(weddingDay))),
        );
        if (day.evaluate().isEmpty) {
          walk.fail('ما فيه يوم ${formatArabicDayMonth(weddingDay)} في التقويم');
          return;
        }
        await tester.tap(day.first, warnIfMissed: false);
        await walk.settle(seconds: 1.5);
        walk.expectSee(
          formatArabicDayMonth(weddingDay),
          why: 'اليوم المختار يظهر قبل «التالي»',
        );
        await walk.tapText('التالي');
        walk.expectSee('وين العرس', why: 'الاسم والموعد وصّلا للسؤال الثاني');
      });

      await walk.step('a05_place_budget', 'المدينة والميزانية', () async {
        await walk.tapText('صنعاء');
        await fillNth(0, '5000000');
        await walk.tapText('التالي');
        walk.expectSee('اتفقتوا على المهر', why: 'المدينة والميزانية وصّلتا للمهر');
      });

      await walk.step('a06_mahr', 'المهر', () async {
        walk.note(walk.visibleTexts().take(12).join(' · '));
        await fillNth(0, '2000000');
        await walk.tapText('التالي');
        walk.expectSee('خطتك جاهزة', why: 'المهر وصّل لشاشة «جاهزة»');
        walk.expectSee('5 مليون', why: 'الميزانية التي كُتبت تظهر');
        walk.expectSee('المهر مليونين', why: 'المهر الذي كُتب يظهر');
      });

      await walk.step('a08_ready', 'خطتك جاهزة', () async {
        walk.expectSee('احفظ خطتي برقم جوالي');
        await walk.tapText('احفظ خطتي برقم جوالي', wait: 3);
      });

      await walk.step('a08b_register', 'إنشاء الحساب', () async {
        // D75: the name comes from the plan; only the number is asked.
        final fields = find.byType(EditableText).evaluate().length;
        walk.note('حقول التسجيل: $fields');
        await fillNth(fields - 1, phone);
        await walk.tapKey('register-submit', wait: 5);
      });

      await walk.step('a09_code_burned', 'رمز غلط خمس مرات ثم الصحيح', () async {
        if (!walk.sees('ما وصلني الرمز')) {
          walk.fail('ما طلب رمز واتساب');
          return;
        }
        // Five wrong codes use the code up on the server; the right one
        // then fails too, and the screen must say so, not «غلط» (J1-03).
        for (var attempt = 0; attempt < 5; attempt++) {
          await tester.enterText(find.byType(EditableText).first, '00000$attempt');
          await walk.settle(seconds: 2.5);
        }
        await tester.enterText(find.byType(EditableText).first, devOtpCode);
        await walk.settle(seconds: 3);
        walk.note(walk.visibleTexts().take(12).join(' · '));
        walk.expectSee('انتهى', why: 'الرمز المستنفد يُقال إنه انتهى، لا إنه غلط فقط');
      });

      await walk.step('a09_resend', 'أرسله مرة ثانية بعد العدّاد', () async {
        final resend = find.text('أرسله مرة ثانية');
        if (!await walk.waitFor(resend, seconds: 75)) {
          walk.fail('زر «أرسله مرة ثانية» ما ظهر بعد انتهاء العدّاد');
          return;
        }
        await tester.tap(resend.first, warnIfMissed: false);
        await walk.settle(seconds: 4);
        walk.expectNotSee('انتهى', why: 'رمز جديد يمسح رسالة الرمز القديم');
      });

      await walk.step('a09_otp', 'رمز التحقق', () async {
        if (!walk.sees('ما وصلني الرمز')) {
          walk.fail('ما طلب رمز واتساب');
          return;
        }
        // Six digits sign in and save the plan on their own (D75). The
        // field was cleared by the resend, so it is focused first.
        final field = find.byKey(const Key('otp-code-field'));
        await tester.tap(field, warnIfMissed: false);
        await walk.settle(seconds: 1);
        await tester.enterText(field, devOtpCode);
        await walk.settle(seconds: 8);
      });

      await walk.step('b01_home', 'الرئيسية بعد الحفظ', () async {
        walk.expectSee('أهلًا');
        walk.expectSee('سامي');
      });

      await walk.step('c01_money', 'المال قبل أي شيء', () async {
        await walk.tab('المال');
        walk.expectSee('5 مليون', why: 'الميزانية وصلت الخادم (C2)');
        walk.expectSee('2 مليون', why: 'المهر وصل الخادم');
      });

      await walk.step('c10_add_cost', 'سجّل اتفاقًا: القاعة', () async {
        // The floating button, then the same words on the sheet it opens.
        await walk.tapText('إضافة اتفاق');
        await walk.tapText('إضافة اتفاق', last: true, wait: 3);
        walk.note(walk.visibleTexts().take(20).join(' · '));
      });

      await walk.step('c10_save_cost', 'احفظ الاتفاق', () async {
        final title = find.byKey(const ValueKey('cost-title'));
        if (title.evaluate().isEmpty) {
          walk.fail('ما فيه حقل اسم الاتفاق');
          return;
        }
        await walk.tapText('قاعة أو مخدرة الرجال', wait: 1);
        // «بكم اتفقت؟» comes first, then the name.
        await fillNth(0, '1000000');
        await tester.enterText(
          find.descendant(of: title, matching: find.byType(EditableText)).first,
          'قاعة التجربة',
        );
        await tester.pump(const Duration(milliseconds: 200));
        await walk.tapKey('cost-save', wait: 5);
        walk.note(walk.visibleTexts().take(20).join(' · '));
      });

      await walk.step('c02_items', 'الاتفاق ظهر في البنود', () async {
        await walk.tab('المال');
        await walk.tapText('البنود', required: false);
        // The row carries the item's name, and opens the agreement's own.
        walk.expectSee('قاعة أو مخدرة الرجال');
        walk.expectSee('1 مليون', why: 'الاتفاق الجديد ظهر بمبلغه، لا اسم البند فقط');
      });

      await walk.step('c07_item', 'افتح الاتفاق', () async {
        await walk.tapText('قاعة أو مخدرة الرجال', wait: 3);
        walk.expectSee('قاعة التجربة');
        walk.note(walk.visibleTexts().take(24).join(' · '));
      });

      await walk.step('c06_pay', 'سجّل دفعة', () async {
        await walk.tapText('سجّل دفعة', required: false, wait: 3) ||
            await walk.tapText('سجّل الدفعة', wait: 3);
        final amount = find.byType(EditableText);
        if (amount.evaluate().isNotEmpty) await fillNth(0, '250000');
        walk.note(walk.visibleTexts().take(20).join(' · '));
        await walk.tapText('حفظ الدفعة', wait: 5);
      });

      await walk.step('c07_after_pay', 'الباقي نزل في الاتفاق', () async {
        walk.expectSee('750,000');
      });

      await walk.step('c01_after_pay', 'الملخص يعرف الدفعة', () async {
        await walk.back();
        await walk.tab('المال');
        await walk.tapText('الملخص', required: false);
        walk.note(walk.visibleTexts().take(24).join(' · '));
        walk.expectSee('250,000', why: 'الدفعة بمبلغها الكامل في الملخص');
      });

      await walk.step('e06_add_guest', 'أضف ضيفًا', () async {
        await walk.tab('الضيوف');
        await walk.tapText('ضيف واحد', wait: 3);
        walk.note(walk.visibleTexts().take(16).join(' · '));
      });

      await walk.step('e06_save_guest', 'احفظ الضيف', () async {
        await fillNth(0, 'ضيف التجربة');
        await walk.tapKey('guest-form-save', wait: 4);
        walk.note(walk.visibleTexts().take(16).join(' · '));
      });

      await walk.step('e01_guest_seen', 'الضيف ظهر', () async {
        await walk.tab('الضيوف');
        walk.note(walk.visibleTexts().take(16).join(' · '));
      });

      await walk.step('d02_add_task', 'أضف مهمة', () async {
        await walk.tab('المهام');
        walk.note(walk.visibleTexts().take(16).join(' · '));
        await walk.tapText('أضف مهمة', required: false, wait: 3) ||
            await walk.tapText('إضافة مهمة', wait: 3);
        final title = find.byKey(const ValueKey('task-title'));
        if (title.evaluate().isEmpty) {
          walk.fail('ما فتحت شاشة إضافة المهمة');
          return;
        }
        await tester.enterText(
          find.descendant(of: title, matching: find.byType(EditableText)).first,
          'مهمة التجربة',
        );
        await tester.pump(const Duration(milliseconds: 200));
        await walk.tapText('حفظ', required: false, last: true, wait: 4) ||
            await walk.tapText('أضف', last: true, wait: 4);
      });

      await walk.step('d01_task_seen', 'المهمة ظهرت', () async {
        await walk.tab('المهام');
        walk.expectSee('مهمة التجربة');
      });

      await walk.step('b02_home_after', 'الرئيسية تعرف كل هذا', () async {
        await walk.tab('الرئيسية');
        walk.note(walk.visibleTexts().take(30).join(' · '));
        // V-01: the home's side column is compact with its unit; the space
        // before the unit is a non-breaking one, so the two are matched apart.
        walk.expectSee('دفعت 250', why: 'الرئيسية تعرف الدفعة (R1)');
        walk.expectSee('ألف', why: 'الرقم المختصر معه وحدته (V-01)');
        walk.expectSee('مع المهر', why: 'المجموع يقول إنه مع المهر (D79)');
        walk.expectNotSee('ابدأ قائمة الضيوف', why: 'أضفنا ضيفًا (R1)');
      });

      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
