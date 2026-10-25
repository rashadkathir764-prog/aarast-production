// A participant's walk in «عرس محمد»: what they may see, and above all what
// they must not (the owner's private money). Seed rights
// (backend/prisma/demo-seed/plan-data.ts): صالح is a HELPER (tasks, guests,
// providers; no money), الوالد a VIEWER (no section rights).
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

class ParticipantPersona {
  const ParticipantPersona({
    required this.journey,
    required this.phone,
    required this.name,
    required this.roleLine,
    required this.managesTasks,
    required this.managesGuests,
    required this.managesProviders,
  });

  final String journey;
  final String phone;
  final String name;

  /// How the home names their place in the plan, in correct Arabic.
  final String roleLine;
  final bool managesTasks;
  final bool managesGuests;
  final bool managesProviders;
}

const helperSaleh = ParticipantPersona(
  journey: 'participant_saleh',
  phone: '777000103',
  name: 'صالح',
  roleLine: 'أنت مساعد',
  managesTasks: true,
  managesGuests: true,
  managesProviders: true,
);

const viewerFather = ParticipantPersona(
  journey: 'participant_father',
  phone: '777000104',
  name: 'الوالد',
  roleLine: 'أنت تشوف بس',
  managesTasks: false,
  managesGuests: false,
  managesProviders: false,
);

/// The owner's money as the owner sees it; none of it may reach a
/// participant without the money right.
const _privateMoney = [
  '4.9 مليون',
  '2.6 مليون',
  '7 مليون',
  'باقي تدفع',
  'معك 4.9',
  'موعود 1.2',
  'مدخراتي',
  'خالي أحمد',
  '500,000',
];

Future<void> runParticipantWalk(
  WidgetTester tester,
  ParticipantPersona p,
) async {
  final walk = JourneyWalk(tester, p.journey);
  await walk.boot();
  await walk.signIn(p.phone);

  void noPrivateMoney() {
    for (final value in _privateMoney) {
      walk.expectNotSee(value, why: 'مال العريس الخاص');
    }
  }

  await walk.step('x06_participant_home', 'رئيسية المشارك', () async {
    if (!await walk.waitFor(walk.text('يوم على العرس'), seconds: 12)) {
      walk.fail('ما ظهر عدّاد الأيام');
    }
    walk.expectSee('أهلًا ${p.name}');
    walk.expectSee('عرس محمد');
    walk.expectSee(p.roleLine, why: 'وصف دوره بعربي صحيح');
    walk.expectSee('21 يناير');
    walk.expectSee('المال مخفي عنك');
    noPrivateMoney();
    if (p.managesTasks) walk.expectSee('رتّب الغداء', why: 'مهمته المتأخرة');
  });

  await walk.step('q07_money_locked', 'المال: مقفول', () async {
    await walk.tab('المال');
    walk.expectSee('ما عندك صلاحية تشوف المال');
    noPrivateMoney();
  });

  await walk.step('q05_tasks', 'المهام', () async {
    await walk.tab('المهام');
    if (p.managesTasks) {
      walk.expectSee('رتّب الغداء');
      walk.expectSee('معك');
      walk.expectNotSee(
        'حدد موعد عقد القران',
        why: 'مهمة العريس مو عليه',
      );
    } else {
      walk.expectNotSee(
        'ما عندك صلاحية على المهام',
        why: 'الدور اسمه «يشوف بس» ومع ذلك المهام مقفولة كلها '
            '(V1_DELIVERY_CHECKLIST: يشوف نفس شاشات الخطة بحسب صلاحياته)',
      );
    }
  });

  await walk.step('participant_guests', 'الضيوف', () async {
    await walk.tab('الضيوف');
    if (p.managesGuests) {
      walk.expectNotSee('124', why: 'يشوف بس الضيوف اللي أضافهم');
      walk.expectNotSee(' 4 مقعد', why: 'العدد 3–10 جمعه «مقاعد»');
    } else {
      walk.expectSee('ما عندك صلاحية');
    }
  });

  await walk.step('q16_providers', 'المزودين', () async {
    await walk.tab('المزودين');
    if (p.managesProviders) {
      walk.expectNotSee(
        'ما طلبت من أحد بعد',
        why: 'الخطة فيها قاعة وضيافة محجوزة، والمساعد له حق المزودين',
      );
      walk.expectNotSee(
        'نبدأ بالقاعة',
        why: 'القاعة محجوزة من قبل، الجملة غير صحيحة',
      );
    } else {
      walk.expectSee('الطلبات والعروض خاصة');
    }
    noPrivateMoney();
  });

  await walk.step('q10_participant_account', 'حسابي (مشارك)', () async {
    await walk.tab('الرئيسية');
    if (!await walk.tapSemantics('حسابي', wait: 3)) return;
    walk.expectSee('عرس محمد');
    walk.expectNotSee('تأجيل العرس', why: 'تأجيل العرس لصاحب الخطة');
    noPrivateMoney();
  });

  await walk.step('q10_logout', 'الخروج', () async {
    if (!await walk.tapKey('account-logout', wait: 2.5)) return;
    if (!await walk.tapKey('account-logout-confirm', wait: 5)) return;
    await walk.waitSignedOut();
  });

  await walk.finish();
}
