// The provider side: «استوديو ضوء صنعاء» (active, verified) through its
// home, every request state, one request, the offer and decline sheets (left
// unsent), the calendar, a booking, messages, profile, services, settings and
// logout; then the three accounts under review (PENDING, NEEDS_CHANGES,
// REJECTED) one after the other in the same app, signing out between them.
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

Future<void> runStudioWalk(WidgetTester tester) async {
  final walk = JourneyWalk(tester, 'provider_studio');
  await walk.boot();
  await walk.signIn('777000201');

  await walk.step('p13_home', 'رئيسية المزود', () async {
    if (!await walk.waitFor(walk.text('استوديو ضوء صنعاء'), seconds: 12)) {
      walk.fail('ما ظهرت رئيسية الاستوديو');
      return;
    }
    walk.expectSee('ينتظرونك');
    walk.expectSee('ردّ الآن');
  });

  // p42 (B-19, B-38, B-09): his notices in the app's words, each opening its
  // own screen; «تقييم جديد» opens p27 with his one reply.
  await walk.step('p42_notifications', 'التنبيهات', () async {
    if (!await walk.tapKey('provider-home-notifications', wait: 3)) return;
    walk.expectSee('كل واحد يفتح طلبه');
    walk.expectSee('طلب جديد من سلمى');
    walk.expectSee('تقييم جديد');
    walk.expectSee('4 نجوم من خالد');
    for (final line in walk.visibleTexts()) {
      if (RegExp(r'\d{4,}\b').hasMatch(line.replaceAll(',', '§')) ||
          RegExp(r'\d{1,2}/\d{1,2}/\d{4}').hasMatch(line) ||
          RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(line) ||
          RegExp(r'[A-Za-z]').hasMatch(line)) {
        walk.fail('تنبيه بنص خام: «$line»');
        break;
      }
    }
    for (final word in ['مورد', 'بوابة', 'المزوّد']) {
      walk.expectNotSee(word, why: 'كلمات التنبيهات كلمات التطبيق (B-38)');
    }
  });

  await walk.step('p42_open_each', 'كل تنبيه يفتح شاشته', () async {
    final home = walk.currentLocation();
    if (home == null) {
      walk.fail('ما عرفنا مكان شاشة التنبيهات');
      return;
    }
    await walk.openEachNotice(keyPrefix: 'provider-notice-', home: home);
  });

  await walk.step('p27_review', 'تقييم خالد ورد الاستوديو', () async {
    if (!await walk.tapText('تقييم جديد', wait: 3)) return;
    walk.expectSee('خالد');
    walk.expectSee('الفيلم وصل بعد أسبوعين بالضبط');
    walk.expectSee('ردك · يشوفه الكل تحت التقييم');
    walk.expectSee('شكرًا يا خالد');
  });
  await walk.leaveTo('/provider/dashboard');

  await walk.step('p15_requests_new', 'الطلبات: جديد', () async {
    await walk.tab('الطلبات');
    walk.expectSee('ينتظرون ردك');
    walk.expectSee('سلمى السقاف', why: 'طلب سلمى الجديد');
  });

  Future<void> requestState(String id, String chip, String customer) async {
    await walk.step(id, 'الطلبات: $chip', () async {
      await walk.tapText(chip, wait: 2.5);
      walk.expectSee(customer);
    });
  }

  await requestState('p19_requests_replied', 'ردّيت', 'محمد الحمدي');
  await requestState('p22_requests_booked', 'محجوز', 'فهد العمري');
  await requestState('p20_requests_ended', 'انتهى', 'عادل الريمي');

  await walk.step('p16_request', 'طلب سلمى', () async {
    await walk.tapText('جديد', wait: 2.5);
    // Her wedding-night request (the seed also holds a henna-night one).
    if (!await walk.tapText('الخميس 21 يناير', wait: 3.5)) return;
    walk.expectSee('سلمى السقاف');
    walk.expectSee('صور وفيديو');
    walk.expectSee('21 يناير');
    walk.expectSee('أرسل عرض');
    walk.expectSee('اعتذر');
  });

  await walk.step('p17_offer', 'شاشة العرض (بدون إرسال)', () async {
    if (!await walk.tapKey('provider-request-offer', wait: 3.5)) return;
    walk.expectSee('سلمى');
  });
  await walk.back();

  await walk.step('p18_decline', 'نافذة الاعتذار (بدون تأكيد)', () async {
    if (!await walk.tapText('اعتذر', last: true, wait: 3)) return;
    walk.expectSee('اعتذر');
  });
  await walk.back();
  await walk.back();

  await walk.step('p22_booking', 'حجز فهد', () async {
    await walk.tab('الطلبات');
    await walk.tapText('محجوز', wait: 2.5);
    if (!await walk.tapText('فهد العمري', wait: 3.5)) return;
    walk.expectSee('4 فبراير');
  });
  await walk.back();

  await walk.step('p28_month', 'التقويم', () async {
    await walk.tab('التقويم');
    walk.expectSee('محجوز');
    walk.expectSee('مقفول');
  });

  await walk.step('p33_chats', 'الرسائل', () async {
    await walk.tab('الرسائل');
    walk.expectSee('فهد العمري');
    walk.expectSee('خالد القاضي');
    walk.expectSee('سلمى السقاف');
  });

  await walk.step('p35_me', 'ملفي', () async {
    await walk.tab('ملفي');
    walk.expectSee('موثّق');
    walk.expectSee('4.0');
    walk.expectSee('خدمتين');
  });

  await walk.step('p36_services', 'خدماتي وباقاتي', () async {
    if (!await walk.tapText('خدماتك وباقاتك', wait: 3)) return;
    walk.expectSee('صور وفيديو');
    walk.expectSee('صور فقط');
    walk.expectSee('550,000');
  });
  await walk.back();

  await walk.step('p39_performance', 'أداؤك', () async {
    await walk.tab('ملفي');
    if (!await walk.tapText('أداؤك', wait: 3)) return;
    walk.expectSee('مشاهدة لملفك');
    final views = walk.visibleTexts().map(int.tryParse).whereType<int>();
    if (!views.any((v) => v >= 412)) {
      walk.fail('عدد المشاهدات أقل من 412 المزروعة في البيانات');
    }
  });
  await walk.back();

  await walk.step('p40_settings', 'الإعدادات', () async {
    await walk.tab('ملفي');
    if (!await walk.tapText('الإعدادات', wait: 3)) return;
    walk.expectSee('تسجيل الخروج');
  });

  await walk.step('p40_logout', 'الخروج', () async {
    if (!await walk.tapKey('provider-logout-action', wait: 2.5)) return;
    if (!await walk.tapKey('provider-logout-confirm', wait: 5)) return;
    if (!await walk.waitSignedOut()) return;
    walk.expectNotSee(
      'خطتك بانتظارك',
      why: 'المزود ما عنده خطة عرس، الجملة غير صحيحة له',
    );
  });

  await walk.finish();
}

Future<void> runReviewStatesWalk(WidgetTester tester) async {
  final walk = JourneyWalk(tester, 'provider_review_states');
  await walk.boot();

  Future<void> signOutFromReview(String id) async {
    await walk.step(id, 'الخروج من شاشة المراجعة', () async {
      if (!await walk.tapTooltip('حسابي', wait: 3)) {
        walk.fail('ما فيه طريق لحسابي من شاشة المراجعة (ما يقدر يطلع)');
        return;
      }
      if (!await walk.tapKey('account-logout', wait: 2.5)) return;
      if (!await walk.tapKey('account-logout-confirm', wait: 5)) return;
      await walk.waitSignedOut();
    });
  }

  await walk.signIn('777000203');
  await walk.step('p08_pending', 'بانتظار المراجعة: فرقة الأمجاد', () async {
    if (!await walk.waitFor(walk.text('قيد المراجعة'), seconds: 12)) {
      walk.fail('ما ظهرت حالة «قيد المراجعة»');
    }
    walk.expectSee('فرقة الأمجاد للبرع');
    walk.expectSee('عدّل طلبك');
    walk.expectNotSee('ردّ الآن', why: 'المزود غير المعتمد ما يستقبل طلبات');
  });
  await signOutFromReview('p08_logout');

  await walk.signIn('777000204');
  await walk.step('p09_needs_changes', 'يحتاج تعديل: محلات الأناقة', () async {
    if (!await walk.waitFor(walk.text('يحتاج تعديل'), seconds: 12)) {
      walk.fail('ما ظهرت حالة «يحتاج تعديل»');
    }
    walk.expectSee('محلات الأناقة');
    walk.expectSee('صلّح', why: 'ملاحظات المراجعة ظاهرة له');
    walk.expectSee('45,000', why: 'خدمة «ثوب أبيض» بسعرها');
    if (!walk.expectSee('أرسل التعديل', why: 'زر إعادة الإرسال (B1)') &&
        walk.sees('أرسلت التعديل')) {
      walk.note('الزر مكتوب «أرسلت التعديل» بصيغة الماضي، كأنه خبر مو زر');
    }
  });
  await signOutFromReview('p09_logout');

  await walk.signIn('777000205');
  await walk.step('p11_rejected', 'مرفوض: كوافيرة أم ريان', () async {
    if (!await walk.waitFor(walk.text('السبب'), seconds: 12)) {
      walk.fail('ما ظهر سبب الرفض');
    }
    walk.expectSee('كوافيرة أم ريان');
    walk.expectSee('وضّحتي', why: 'سبب الرفض المحفوظ لها');
    // The reason speaks to her; the buttons beside it must too.
    walk.expectSee('صلّحي وقدّمي من جديد', why: 'زر إعادة الفتح بكلامها');
    walk.expectNotSee('تكلّم مع الدعم', why: 'السبب مؤنث والزر مذكّر');
  });
  await signOutFromReview('p11_logout');

  await walk.finish();
}
