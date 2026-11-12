// D85: the app works without the server. Run right after the groom walk on
// the same machine (its local copy stays), with AARAST_API_BASE_URL pointing
// at a closed port: the plan opens from the phone, every tab shows its copy,
// a guest is added and kept, and nothing asks to retry.
// Run: see docs/qa/JOURNEY_WALKS.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/journey_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the groom works on his plan with the server out of reach',
    (tester) async {
      final walk = JourneyWalk(tester, 'offline_groom');
      await walk.boot(keepLocalData: true);

      await walk.step('o01_home', 'الرئيسية من نسخة الجوال', () async {
        await walk.waitFor(walk.text('الرئيسية'), seconds: 20);
        walk.expectSee('عرس محمد', why: 'الخطة من نسخة الجوال بلا خادم');
        walk.expectSee(
          'ما نقدر نوصل للخادم الحين',
          why: 'اللافتة تقول السبب المقيس لا «بدون نت»',
        );
        walk.expectNotSee(
          'بدون نت.',
          why: 'الجوال متصل؛ الخادم هو اللي ما يرد',
        );
        walk.expectNotSee('أعد المحاولة');
        walk.expectNotSee('جرّب مرة ثانية');
      });

      await walk.step('o02_money', 'المال من نسخة الجوال', () async {
        await walk.tab('المال');
        // The summary's first figure, read from the phone's copy.
        walk.expectSee('عليك من العرس', why: 'الملخص من نسخة الجوال');
        walk.expectSee('1.6 مليون', why: 'رقم الملخص نفسه بلا خادم');
        walk.expectNotSee('أعد المحاولة');
        walk.expectNotSee('جرّب مرة ثانية');
      });

      await walk.step('o03_tasks', 'المهام من نسخة الجوال', () async {
        await walk.tab('المهام');
        walk.expectSee(
          'ادفع دفعة القاعة',
          why: 'مهام البيانات التجريبية من نسخة الجوال',
        );
        walk.expectNotSee('أعد المحاولة');
        walk.expectNotSee('جرّب مرة ثانية');
      });

      await walk.step('o04_guests', 'الضيوف: القائمة والزر موجودان', () async {
        await walk.tab('الضيوف');
        walk.expectSee('آل الحمدي', why: 'العائلات من نسخة الجوال');
        if (!walk.seesAddGuest) walk.fail('زر إضافة الضيف اختفى بدون خادم');
      });

      await walk.step('o05_add_guest', 'إضافة ضيف بدون خادم', () async {
        await walk.tapAddGuest();
        await walk.enterField('الاسم', 'ضيف بدون نت');
        // The receipt (4.2s, shown once the save and the way back are done)
        // sits over the header's search until it goes.
        await walk.tapKey('guest-form-save', wait: 7);
        walk.expectNotSee('ما قدرنا نحفظ', why: 'الحفظ على الجوال لا يفشل');
        // Found the way a person finds one name among a hundred: «دوّر».
        if (!await walk.searchGuest('ضيف بدون نت')) {
          walk.fail('ما يظهر «ضيف بدون نت» (الضيف محفوظ على الجوال وظاهر)');
        }
      });
      await walk.back();

      await walk.step('o06_providers', 'المزودين من نسخة الجوال', () async {
        await walk.tab('المزودين');
        walk.expectSee('قاعة سبأ', why: 'طلبات الخطة من نسخة الجوال');
        walk.expectNotSee('أعد المحاولة');
        walk.expectNotSee('جرّب مرة ثانية');
      });

      await walk.step('o07_pending', 'التغيير ينتظر الخادم', () async {
        await walk.tab('الرئيسية');
        walk.expectSee('تنحفظ في جوالك', why: 'اللافتة تقول إن التغيير محفوظ');
      });
      await walk.finish();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
