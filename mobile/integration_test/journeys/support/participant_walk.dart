// A participant's walk in «عرس محمد»: what they may see, and above all what
// they must not (the owner's private money, the guests' phones). Seed rights
// (backend/prisma/demo-seed/plan-data.ts): صالح is a HELPER (tasks, guests,
// providers; no money), الوالد a VIEWER (no edit right). Reading is separate
// from editing (D52): الوالد reads the plan's tasks, guests and bookings.
// D80: صالح reads every guest and the numbers of only the ones he added.
import 'package:flutter/widgets.dart' show ValueKey;
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
  roleLine: 'أنت تتابع بس',
  managesTasks: false,
  managesGuests: false,
  managesProviders: false,
);

/// The owner's money as the owner sees it (the seed's figures, D103 to
/// D105); none of it may reach a participant without the money right.
const _privateMoney = [
  '4.9 مليون',
  '2.6 مليون',
  '7 مليون',
  '1.6 مليون',
  '3.3 مليون',
  'عليك من العرس',
  'معك 4.2',
  'موعود 1.2',
  'مدخراتي',
  'خالي أحمد',
  '500,000',
];

/// The seeded guests' phones start +96777; a participant who does not work
/// on guests sees none of them, in any spelling.
const _guestPhones = ['+967', '967 7', '77 0'];

/// A provider's price range as the directory writes it (public).
final _publicPriceRange = RegExp(r'^[\d,]+ - [\d,]+ ر\.ي');

/// D80 (demo-seed/plan.ts): صالح added the first four of «الأصحاب»;
/// ياسر الأهدل is his, at position 84 (+967 777 010 084). عبدالله الحمدي,
/// the first guest of «آل الحمدي», is the groom's (+967 777 010 000).
const _helperGuestName = 'ياسر الأهدل';
const _helperGuestPhone = '777 010 084';
const _groomGuestId = 'demo_guest_groom-hamdi-1';
const _groomGuestName = 'عبدالله الحمدي';
const _groomGuestPhone = '777 010 000';

Future<void> runParticipantWalk(
  WidgetTester tester,
  ParticipantPersona p,
) async {
  final walk = JourneyWalk(tester, p.journey);
  await walk.boot();
  await walk.signIn(p.phone);

  void noPrivateMoney() {
    for (final value in _privateMoney) {
      // A provider's public price range in the directory («500,000 -
      // 700,000 ر.ي») is not the groom's money; a taller screen shows more
      // of the directory, so the walk must not depend on the window.
      final leaks = walk.visibleTexts().where(
        (text) => text.contains(value) && !_publicPriceRange.hasMatch(text),
      );
      if (leaks.isNotEmpty) {
        walk.fail('يظهر «$value» وما لازم (مال العريس الخاص)');
      }
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
    if (p.managesTasks) {
      walk.expectSee('رتّب الغداء', why: 'مهمته المتأخرة');
    } else {
      // D52: x06 without its controls, from the plan's own tasks.
      walk.expectSee('الخطوة الجاية', why: 'خطوة الخطة الجاية');
      walk.expectSee('حدد موعد عقد القران', why: 'أقرب مهمة مفتوحة في الخطة');
      walk.expectSee('مهام الخطة');
      walk.expectSee('خلصت 12 من 20', why: 'تقدّم الخطة الحقيقي');
      walk.expectNotSee('أنت يشوف بس', why: 'عربي مكسور');
    }
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
        why: 'الدور اسمه «يشوف بس» ومع ذلك المهام مقفولة كلها (D52)',
      );
      // D52: all the plan's tasks, read only.
      walk.expectSee('خلصت 12 من 20', why: 'المهام 12 من 20');
      walk.expectSee('حدد موعد عقد القران');
      walk.expectSee('متأخرة', why: 'مهمة متأخرة وحدة');
      walk.expectSee('التعديل عند العريس', why: 'يقال له إنه يتابع بس');
      walk.expectNotSee('أضف مهمة', why: 'ما يضيف');
      walk.expectNotSee('500,000', why: 'وصف المهمة فيه مبلغ');
    }
    noPrivateMoney();
  });

  await walk.step('participant_guests', 'الضيوف', () async {
    await walk.tab('الضيوف');
    if (p.managesGuests) {
      // D80: the helper reads every guest of the plan; he edits, and reads
      // the number of, only the guests he added.
      walk.expectSee('124 مدعو', why: 'عدد ضيوف الخطة كلها (D80)');
      walk.expectSee('أكدوا من 124');
      walk.expectSee('أرقام البقية عند العريس', why: 'يقال له لمن الأرقام');
      walk.expectNotSee(' 4 مقعد', why: 'العدد 3–10 جمعه «مقاعد»');
      if (find.byKey(const ValueKey('guests-add')).evaluate().isEmpty) {
        walk.fail('ما فيه زر إضافة ضيف، والمساعد له حق الضيوف');
      }
      await walk.tapKey('guest-group-all');
      // RA-MO-16: the list is built as it scrolls; a person finds a name
      // among a hundred with «دوّر», as the owner's walk does.
      if (await walk.searchGuest(_groomGuestName)) {
        walk.expectNotSee(_groomGuestPhone, why: 'رقم ضيف العريس للعريس');
        // The groom's guest is a plain row: no way into his details.
        await walk.tapKey('guest-row-$_groomGuestId');
        walk.expectNotSee(_groomGuestPhone, why: 'رقم ضيف العريس للعريس');
        walk.expectNotSee('اتصل', why: 'ما يتصل بضيف العريس');
        // The next name is a new search, as a person does it: close this
        // one (it clears what was typed) and «دوّر» again.
        await walk.tapKey('guests-search', wait: 1);
      } else {
        walk.fail('ما يظهر «$_groomGuestName» (ضيف العريس بالاسم (D80))');
      }
      if (await walk.openGuest(_helperGuestName)) {
        walk.expectSee(_helperGuestPhone, why: 'رقم ضيف أضافه هو');
        await walk.back();
      }
    } else {
      // D52: the plan's guests by name and reply, never their phones.
      walk.expectNotSee('ما عندك صلاحية');
      walk.expectSee('124 مدعو', why: 'عدد الضيوف كله');
      walk.expectSee('أكدوا من 124');
      walk.expectSee('كل الضيوف');
      walk.expectSee('أرقام الجوالات والإضافة والتعديل عند العريس');
      for (final phone in _guestPhones) {
        walk.expectNotSee(phone, why: 'رقم جوال ضيف');
      }
      walk.expectNotSee('ذكّر', why: 'ما يرسل تذكير');
    }
    noPrivateMoney();
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
      // D52: the plan's bookings whoever made them.
      walk.expectSee('قاعة سبأ', why: 'القاعة المحجوزة في الخطة');
      walk.expectSee('محجوز');
    } else {
      // q16: the plan's bookings by day and status, no price.
      walk.expectNotSee('الطلبات والعروض خاصة');
      walk.expectSee('تشوف بس');
      walk.expectSee('الأسعار والعروض عند العريس');
      walk.expectSee('قاعة سبأ', why: 'القاعة المحجوزة');
      walk.expectSee('محجوز');
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
