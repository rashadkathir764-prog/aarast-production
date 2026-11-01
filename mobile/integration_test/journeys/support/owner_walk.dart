// The plan owner's walk (groom محمد, bride سلمى): home and its mahr card →
// money (the mahr beside the wedding, its section, who paid what) → items,
// payment, funding and the loan → tasks and the late one → guests →
// providers (explore, a provider's page, the quote request, compare offers,
// a booked service, chats) → account (plans, postpone, lock, help, notices)
// → logout. Numbers are the demo seed's (docs/qa/DEMO_DATA.md,
// backend/prisma/demo-seed/plan-data.ts).
//
// Nothing is submitted: sheets and forms are opened, photographed and left,
// so the seed stays as it was and the walk can be rerun.
import 'package:aarast_mobile/core/utils/arabic_date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

/// The seed puts the rest of the mahr three weeks after the day it ran.
String get mahrRestDay =>
    formatArabicDayMonth(DateTime.now().add(const Duration(days: 21)));

class OwnerPersona {
  const OwnerPersona({
    required this.journey,
    required this.phone,
    required this.firstName,
    required this.planName,
    required this.guestsTab,
    required this.hallItem,
    required this.hallProvider,
    required this.itemNames,
    required this.otherPlanName,
    required this.fundingNames,
    required this.loanSource,
    required this.lateTask,
    required this.guestFamily,
    required this.otherPlanRole,
    required this.agreed,
    required this.paid,
    required this.inHand,
    required this.promised,
    required this.fundingAmounts,
    required this.familyPayer,
    required this.mahr,
  });

  final String journey;
  final String phone;
  final String firstName;
  final String planName;

  /// «الضيوف» for him, «الضيفات» for her (JourneySection.guests).
  final String guestsTab;

  /// The hall's item and its provider in this plan's words.
  final String hallItem;
  final String hallProvider;

  /// The items as the design names them (c02): the item, not the provider.
  final List<String> itemNames;

  /// The other plan this account sees on «اختر المسار» and in «خططك», and
  /// the words that must describe this person's place in it.
  final String otherPlanName;
  final String otherPlanRole;

  final List<String> fundingNames;
  final String loanSource;
  final String lateTask;
  final String guestFamily;

  /// The money as the seed leaves it (DEMO_DATA.md): what was agreed and
  /// paid (his mahr agreement included), in hand and promised (her mahr
  /// received and its rest included), the sources' amounts, and the family
  /// payer of the hall and the lunch. [inHand] and [promised] are millions.
  final String agreed;
  final String paid;
  final String inHand;
  final String promised;
  final List<String> fundingAmounts;
  final String familyPayer;

  /// The mahr's words on each screen of his or her side (B5, D55).
  final MahrWalkWords mahr;

  /// Her plan speaks to her (D-profile words): picks his or her phrase.
  bool get bride => journey == 'bride';
  String say(String his, String hers) => bride ? hers : his;
}

/// The mahr as each side reads it: the groom hands it to the bride's
/// family, the bride receives it from the groom.
class MahrWalkWords {
  const MahrWalkWords({
    required this.homeCard,
    required this.homeLine,
    required this.moneyTitle,
    required this.moneyCard,
    required this.itemsSection,
  });

  /// b02's agreement card and its line.
  final String homeCard;
  final String homeLine;

  /// c01's title over the mahr and the wedding, and the mahr card.
  final String moneyTitle;
  final String moneyCard;

  /// c02's mahr section.
  final String itemsSection;
}

const groomPersona = OwnerPersona(
  journey: 'groom',
  phone: '777000101',
  firstName: 'محمد',
  planName: 'عرس محمد',
  guestsTab: 'الضيوف',
  hallItem: 'القاعة',
  hallProvider: 'قاعة سبأ',
  itemNames: [
    'القاعة',
    'الضيافة والعشاء',
    'القات',
    'الغداء',
    'التصوير',
    'الفنان والفرقة',
    'بدلة العريس',
  ],
  otherPlanName: 'عرس سلمى',
  // He is the groom in her plan (SharedMemberRole.GROOM), a man.
  otherPlanRole: 'تساعد فيها',
  fundingNames: ['مدخراتي', 'دعم الوالد', 'خالي أحمد', 'صاحبي عادل'],
  loanSource: 'خالي أحمد',
  lateTask: 'حدد موعد عقد القران',
  guestFamily: 'آل الحمدي',
  agreed: '7.9 مليون',
  // D59: of the 4.6 million paid, his father paid 1.3 (the hall and the
  // lunch): «دفعت منها 3.3»، and «معك» is 7.5 received less his 3.3.
  paid: '3.3 مليون',
  inHand: '4.2',
  promised: '1.2',
  fundingAmounts: ['4.5 مليون', '2.4 مليون', '600,000'],
  familyPayer: 'الوالد',
  mahr: MahrWalkWords(
    homeCard: 'الاتفاق مع أهل العروسة',
    homeLine: 'سلّمت 2 من 3 مليون · الباقي',
    moneyTitle: 'وين تروح الفلوس',
    moneyCard: 'الاتفاق مع أهل العروسة',
    itemsSection: 'الاتفاق مع أهل العروسة',
  ),
);

const bridePersona = OwnerPersona(
  journey: 'bride',
  phone: '777000102',
  firstName: 'سلمى',
  planName: 'عرس سلمى',
  guestsTab: 'الضيفات',
  hallItem: 'الصالة',
  hallProvider: 'صالة الياسمين',
  itemNames: [
    'الصالة',
    'الضيافة والعشاء',
    'البخور',
    'الغداء',
    'التصوير',
    'المزينة والنقاشة',
    'فستان الزفة',
  ],
  otherPlanName: 'عرس محمد',
  otherPlanRole: 'تساعدين فيها',
  fundingNames: ['مدخراتي', 'دعم الوالدة', 'خالي أحمد', 'صاحبتي عبلة'],
  loanSource: 'خالي أحمد',
  lateTask: 'حددي موعد عقد القران',
  guestFamily: 'آل السقاف',
  agreed: '4.9 مليون',
  // D59: her father paid 1.3 of the 2.6: «دفعتِ منها 1.3»، «معك» 4.5 − 1.3.
  paid: '1.3 مليون',
  inHand: '3.2',
  promised: '2.2',
  fundingAmounts: ['900,000', '600,000'],
  familyPayer: 'أبوي',
  mahr: MahrWalkWords(
    homeCard: 'الاتفاق مع العريس',
    homeLine: 'استلمتِ 2 من 3 مليون · الباقي',
    moneyTitle: 'المهر وعرسك',
    moneyCard: 'المهر يوصلك',
    itemsSection: 'المهر يوصلك من العريس',
  ),
);

Future<void> runOwnerWalk(WidgetTester tester, OwnerPersona p) async {
  final walk = JourneyWalk(tester, p.journey);
  await walk.boot();

  await walk.step('a02b_whose', 'اختر المسار: خطتين', () async {
    // Signs in and stops on the chooser to judge it before picking.
    await walk.signInOnly(p.phone);
    if (!await walk.waitFor(walk.text('اختر المسار'), seconds: 10)) {
      walk.fail('ما ظهرت شاشة «اختر المسار» والحساب له خطتين');
      return;
    }
    walk.expectSee(p.planName);
    walk.expectSee(p.otherPlanName);
    walk.expectSee(
      p.otherPlanRole,
      why: 'وصف مكانه في الخطة الثانية بجنسه الصحيح',
    );
  });
  await walk.step('auth-pick', 'يختار خطته', () async {
    await walk.tapText(p.planName, wait: 5);
  }, screenshot: false);

  // ------------------------------------------------------------- home
  var homeBooked = '';
  await walk.step('b02_home', 'الرئيسية: العدّاد والمال والأقسام', () async {
    if (!await walk.waitFor(walk.text('يوم على عرس'), seconds: 12)) {
      walk.fail('ما ظهر عدّاد الأيام على الرئيسية');
    }
    walk.expectSee('أهلًا ${p.firstName}');
    walk.expectSee(p.planName);
    walk.expectSee('21 يناير', why: 'موعد العرس في البيانات');
    walk.expectSee('معك ${p.inHand}', why: 'معك ${p.inHand} مليون');
    walk.expectSee('موعود ${p.promised}', why: 'موعود ${p.promised} مليون');
    walk.expectSee('من 20 مهمة');
    walk.expectSee(p.say('أكدوا من 124', 'أكدن من 124'));
    walk.expectSee('86');
    walk.expectSee(p.say('20 ما ردّوا', '20 ما ردّن'));
    // The providers' tile: its number, then «محجوز». An essential's line
    // above it also says «محجوز», after the essential's name.
    final texts = walk.visibleTexts();
    final tile = texts.indexOf('المزودين');
    if (tile >= 0 && tile + 2 < texts.length && texts[tile + 2] == 'محجوز') {
      homeBooked = texts[tile + 1];
    }
  });
  await walk.step('b02_home_mahr', 'الرئيسية: كرت المهر', () async {
    // B5: the mahr agreement stays on the home until it is complete.
    if (!walk.sees(p.mahr.homeCard)) await walk.scroll(pixels: 300);
    walk.expectSee(p.mahr.homeCard, why: 'كرت المهر في b02');
    walk.expectSee(
      '${p.mahr.homeLine} $mahrRestDay',
      why: 'سلّم 2 من 3 مليون والباقي يوم العقد',
    );
  });
  await walk.scroll(pixels: 600);
  await walk.step('b02_home_more', 'الرئيسية تحت: بعدها وفريق الخطة', () async {
    walk.expectSee('بعدها');
    walk.expectSee('فريق الخطة');
    walk.expectNotSee('2 عرض', why: 'العدد اثنين يُكتب «عرضين»');
  });

  await walk.step('b08_notifications', 'التنبيهات من الجرس', () async {
    await walk.scroll(pixels: -1200);
    if (!await walk.tapTooltip('التنبيهات', wait: 3)) return;
    walk.expectSee('التنبيهات');
    // B-38: a notice reads as the app speaks: no raw amount, no numeric or
    // ISO date, no English; an amount is the app's («500,000 ر.ي»).
    for (final line in walk.visibleTexts()) {
      if (RegExp(r'\d{4,}\b').hasMatch(line.replaceAll(',', '§')) ||
          RegExp(r'\d{1,2}/\d{1,2}/\d{4}').hasMatch(line) ||
          RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(line) ||
          RegExp(r'[A-Za-z]').hasMatch(line)) {
        walk.fail('تنبيه بنص خام: «$line»');
        break;
      }
    }
    for (final word in ['مورد', 'بوابة', 'لديك', 'المزوّد']) {
      walk.expectNotSee(word, why: 'كلمات التنبيهات كلمات التطبيق (B-38)');
    }
  });

  // B-19: every notice opens the screen it is about.
  await walk.step('b08_open_each', 'كل تنبيه يفتح شاشته', () async {
    final home = walk.currentLocation();
    if (home == null) {
      walk.fail('ما عرفنا مكان شاشة التنبيهات');
      return;
    }
    await walk.openEachNotice(keyPrefix: 'notification-', home: home);
  });
  await walk.leaveTo('/home');

  // ------------------------------------------------------------ money
  await walk.step('c01_money_summary', 'المال: الملخص', () async {
    await walk.tab('المال');
    walk.expectSee(p.say('اتفقت على ${p.agreed}', 'اتفقتِ على ${p.agreed}'));
    walk.expectSee(p.say('دفعت منها ${p.paid}', 'دفعتِ منها ${p.paid}'));
    // D59: what the family paid is theirs, not the owner's.
    walk.expectSee(
      'ودفع عنك ${p.familyPayer} 1.3 مليون',
      why: 'الدفع عن صاحب الخطة',
    );
    walk.expectSee('معك ${p.inHand} مليون');
    walk.expectSee('موعود لك ${p.promised} مليون');
  });

  await walk.step('c01_money_mahr', 'المال: المهر وعرسك', () async {
    // B5 (C1): the mahr beside the wedding, each from the server.
    if (!walk.sees(p.mahr.moneyTitle)) await walk.scroll(pixels: 400);
    walk.expectSee(p.mahr.moneyTitle, why: 'قسمين c01: المهر والعرس');
    walk.expectSee(p.mahr.moneyCard);
    walk.expectSee('عرسك');
    walk.expectSee(
      p.say('سلّمت 2 مليون', 'وصلك 2 مليون'),
      why: 'المسلّم أو الواصل من المهر',
    );
    // D59: of the 2.6 million paid on the wedding, the family paid 1.3.
    walk.expectSee(
      p.say('دفعت 1.3 مليون', 'دفعتِ 1.3 مليون'),
      why: 'المدفوع من بنود العرس بدون المهر',
    );
    walk.expectSee('دفع عنك 1.3 مليون', why: 'نصيب الأهل منفصل');
    // The budget card sits below the mahr: the mahr is outside it (C1).
    if (!walk.sees('من ميزانية 7 مليون')) await walk.scroll(pixels: 500);
    walk.expectSee('من ميزانية 7 مليون');
    walk.expectSee('2.1 مليون', why: 'المتاح من الميزانية بدون المهر');
    await walk.scroll(pixels: -1500);
  });

  await walk.step('c02_money_items', 'المال: البنود بأسمائها', () async {
    await walk.tapText('البنود', wait: 2.5);
    // B5: the mahr is its own section above «عرسك».
    walk.expectSee(p.mahr.itemsSection, why: 'قسم المهر في c02');
    walk.expectSee('المهر');
    walk.expectSee('الباقي $mahrRestDay', why: 'موعد باقي المهر');
    for (final name in p.itemNames) {
      if (!walk.sees(name)) await walk.scroll(pixels: 300);
      walk.expectSee(name, why: 'اسم البند كما في التصميم c02');
    }
    await walk.scroll(pixels: -1500);
  });

  await walk.step('c07_item_detail', 'تفاصيل بند ${p.hallItem}', () async {
    if (!await walk.tapText(p.hallItem, required: false, wait: 3)) {
      walk.fail('البند ما اسمه «${p.hallItem}» في قائمة البنود');
      if (!await walk.tapText(p.hallProvider, wait: 3)) return;
    }
    walk.expectSee(p.hallProvider);
    walk.expectSee('500,000', why: 'المدفوع للقاعة 500 ألف');
    walk.expectSee('جدول الدفعات');
  });
  await walk.back();

  await walk.step('c03_money_payments', 'المال: الدفعات', () async {
    await walk.tapText('الدفعات', wait: 2.5);
    walk.expectSee('500,000');
  });

  await walk.step('w20_payers', 'مين دفع ايش', () async {
    // G14: each payer's agreements and payments, from the server.
    if (!await walk.tapText('مين دفع ايش', wait: 3)) return;
    walk.expectSee('الكل');
    walk.expectSee('أنا', why: 'صاحب الخطة يقرأ نفسه «أنا»');
    walk.expectSee(p.familyPayer);
    // The chip, not a payment's line that names the same payer.
    if (!await walk.tapKey('payer-FAMILY|${p.familyPayer}', wait: 2)) return;
    walk.expectSee('${p.familyPayer} دفع');
    walk.expectSee('1.3 مليون', why: 'دفع الأهل للصالة والغداء');
  });
  await walk.back();

  await walk.step('c06_pay_sheet', 'فتح «سجّل الدفعة» (بدون حفظ)', () async {
    await walk.tab('المال');
    await walk.tapText('الملخص', wait: 2);
    if (!await walk.tapText(p.say('سجّل الدفعة', 'سجّلي الدفعة'), wait: 3)) {
      return;
    }
    walk.expectSee('500,000');
    walk.expectSee('حفظ الدفعة');
  });
  await walk.back();

  await walk.step('c05_money_funding', 'المال: من وين (المصادر)', () async {
    await walk.tab('المال');
    await walk.tapText('من وين', wait: 2.5);
    // c05 as drawn (D59): «صرفت» is what the owner's own money paid.
    walk.expectSee(
      '${p.say('صرفت', 'صرفتِ')} ${p.paid} ر.ي · معك ${p.inHand} مليون',
      why: 'وصلك = صرفت + معك',
    );
    for (final name in p.fundingNames) {
      walk.expectSee(name);
    }
    for (final amount in p.fundingAmounts) {
      walk.expectSee(amount);
    }
    if (p.bride) {
      // B5 (c05): her mahr is money coming in, the rest on its day.
      if (!walk.sees('باقي المهر')) await walk.scroll(pixels: 400);
      walk.expectSee('المهر من العريس');
      walk.expectSee('باقي المهر');
      walk.expectSee('يوصلك $mahrRestDay', why: 'موعد باقي المهر');
      await walk.scroll(pixels: -1200);
    } else {
      walk.expectNotSee('المهر من العريس', why: 'مهر العريس اتفاق، مو مصدر');
    }
  });

  await walk.step('c13_loan', 'السلفة: الأقساط', () async {
    if (!await walk.tapText(p.loanSource, wait: 3)) return;
    // The summary's row opens «من وين» (the sources list); the loan is one
    // more tap from there.
    if (walk.sees('بتجيب')) {
      await walk.tapText(p.loanSource, last: true, wait: 3);
    }
    if (!walk.expectSee('سلفة ${p.loanSource}', why: 'شاشة السلفة c13')) return;
    walk.expectSee('150,000', why: 'قسط السداد 150 ألف');
    walk.expectSee('1 فبراير', why: 'السداد يبدأ فبراير');
    walk.expectSee('مايو', why: 'أربع أقساط تخلص في مايو');
  });
  await walk.back();
  if (walk.sees('بتجيب')) await walk.back();

  // ------------------------------------------------------------ tasks
  await walk.step('d01_tasks', 'المهام: القائمة', () async {
    await walk.tab('المهام');
    walk.expectSee('12 من 20');
    walk.expectSee('متأخرة');
    walk.expectSee(p.lateTask);
  });

  await walk.step('w26_overdue_task', 'فتح المهمة المتأخرة', () async {
    if (!await walk.tapText(p.lateTask, wait: 3)) return;
    walk.expectSee(p.lateTask);
    walk.expectSee('متأخرة 7 أيام', why: 'موعدها قبل أسبوع في البيانات');
    walk.expectSee('1 من 3');
  });
  await walk.back();

  await walk.step('w24_timeline', 'المهام: عرض «الوقت»', () async {
    await walk.tapText('الوقت', wait: 2.5);
    walk.expectSee('أكتوبر');
  });

  // ----------------------------------------------------------- guests
  await walk.step('e01_guests', '${p.guestsTab}: القائمة والأرقام', () async {
    await walk.tab(p.guestsTab);
    walk.expectSee('124');
    walk.expectSee('86');
    walk.expectSee(p.say('20 ما ردّوا', '20 ما ردّن'));
    walk.expectSee(p.guestFamily);
  });

  await walk.step('e01_guests_all', 'كل ${p.guestsTab}', () async {
    if (!await walk.tapText('كل ${p.guestsTab}', required: false, wait: 3)) {
      await walk.tapText('كل الضيوف', wait: 3);
    }
    walk.expectSee('الكل 124');
    walk.expectSee(p.say('أكدوا 86', 'أكدن 86'));
    walk.expectSee(p.say('اعتذروا 18', 'اعتذرن 18'));
  });
  await walk.back();

  // -------------------------------------------------------- providers
  await walk.step('f01_prov_requests', 'المزودين: طلباتي', () async {
    await walk.tab('المزودين');
    walk.expectSee(p.hallProvider);
    walk.expectSee('ضيافة الأصالة');
    walk.expectSee('التصوير');
    final header = walk.visibleTexts().firstWhere(
      (t) => t.startsWith('محجوز '),
      orElse: () => '',
    );
    final tabBooked = RegExp(r'محجوز (\d+)').firstMatch(header)?.group(1);
    if (homeBooked.isNotEmpty && tabBooked != null && tabBooked != homeBooked) {
      walk.fail(
        'الرئيسية تقول $homeBooked محجوز، وصفحة المزودين تقول $tabBooked',
      );
    }
    if (p.bride) {
      walk.expectSee(
        'صالة الياسمين · أكّد',
        why: 'البيانات: الصالة محجوزة',
      );
      walk.expectNotSee('اطلب الحجز', why: 'كلام مذكّر للعروسة');
      walk.expectNotSee('اخترت ضيافة', why: 'البيانات: الضيافة محجوزة لها');
      // G40: her items are services too (the server lists their kinds).
      walk.expectSee('البخور', why: 'بند البخور له مزودين عطور');
      walk.expectSee('المزينة والنقاشة', why: 'بند النقاشة له مزودين نقش');
    }
  });

  if (!p.bride) {
    // Only his plan holds two photography offers (DEMO_DATA.md).
    await walk.step('f04_compare', 'قارن عرضين للتصوير', () async {
      walk.expectSee('عرضين وصلوا');
      if (!await walk.tapText('قارن', wait: 3.5)) return;
      walk.expectSee('ضوء صنعاء');
      walk.expectSee('550,000');
      walk.expectSee('480,000', why: 'عرض عدسة سبأ 480 ألف');
    });
    await walk.back();
  }

  await walk.step('f05_booked', 'خدمة محجوزة: ${p.hallProvider}', () async {
    await walk.tab('المزودين');
    if (!await walk.tapText(p.hallProvider, wait: 3.5)) return;
    walk.expectSee('محجوز');
    walk.expectSee('21 يناير');
  });
  await walk.back();

  await walk.step('f02_prov_explore', 'المزودين: استكشف', () async {
    await walk.tab('المزودين');
    await walk.tapText('استكشف', wait: 3.5);
    walk.expectSee('استوديو ضوء صنعاء');
    if (!walk.sees('قاعة سبأ')) await walk.scroll(pixels: 700);
    walk.expectSee('قاعة سبأ', why: 'مزود نشط وموثّق في البيانات');
    if (walk.sees(p.hallProvider) && walk.sees('غير مفعّل') && p.bride) {
      walk.fail('الصالة المحجوزة لها تظهر في الدليل «غير مفعّل»');
    }
  });

  await walk.step('f03_prov_page', 'صفحة مزود: استوديو ضوء صنعاء', () async {
    if (!await walk.tapText('استوديو ضوء صنعاء', wait: 4)) return;
    walk.expectSee('الباقات');
    walk.expectSee('550,000');
  });

  await walk.step('f03_prov_page_action', 'زر صفحة المزود يكمل الطلب القائم', () async {
    // Both plans already asked this studio, so its page leads to that request
    // («شوف العرض» for him, «تابعي طلبك» for her), not to a new one.
    final follow = p.say('شوف العرض', 'تابعي طلبك');
    if (!await walk.tapText(follow, wait: 3.5)) return;
    if (walk.sees('الباقات')) walk.fail('الزر «$follow» ما فتح شي');
  });
  await walk.back();
  await walk.back();

  // The demo's provider of that kind with an account (f02 draws them).
  final itemProvider = p.say('فرقة الأفراح', 'المزينة أم فهد');
  await walk.step('f02_item_search', 'ابحث من بند لم يبدأ', () async {
    await walk.tab('المزودين');
    await walk.tapText('طلباتي', wait: 2.5);
    // «الفنان والفرقة · ما بدأت · ابحث» (hers «المزينة والنقاشة»): the way
    // to a provider not asked yet. G40: it searches every kind the server
    // lists for the item, and the item's chip comes first.
    final searched = p.say('الفنان والفرقة', 'المزينة والنقاشة');
    if (!await walk.tapText(p.say('ابحث', 'ابحثي'), last: true, wait: 3.5)) {
      return;
    }
    if (walk.sees('ما لقينا مزودين')) {
      walk.fail('البحث عن «$searched» فاضي');
      return;
    }
    walk.expectSee(searched, why: 'شريحة البند المختار أول الشرائح');
    walk.expectSee(itemProvider, why: 'البحث من البند يلقى مزودينه');
  });

  await walk.step('f07_quote', 'طلب عرض سعر من مزود جديد (بدون إرسال)', () async {
    if (!await walk.tapText(itemProvider, wait: 3.5)) return;
    final asks = p.say('اطلب عرض سعر', 'اطلبي عرض سعر');
    if (!await walk.tapText(asks, wait: 3)) return;
    walk.expectSee(p.say('أرسل الطلب', 'أرسلي الطلب'));
    // Leave f07 unsent; the back below leaves the provider's page.
    await walk.back();
  });
  await walk.back();

  await walk.step('f08_chats', 'المزودين: المحادثات', () async {
    await walk.tab('المزودين');
    await walk.tapText('المحادثات', wait: 3);
    walk.expectSee(p.hallProvider);
  });

  // ---------------------------------------------------------- account
  await walk.step('g02_account', 'حسابي', () async {
    await walk.tab('الرئيسية');
    await walk.scroll(pixels: -1500);
    if (!await walk.tapSemantics('حسابي', wait: 3)) return;
    walk.expectSee('حسابي');
    walk.expectSee('موعد العرس');
    walk.expectSee('تأجيل العرس');
    walk.expectSee('قفل التطبيق');
    walk.expectSee('خططك');
    walk.expectSee('الخروج');
  });

  Future<void> accountRow(
    String id,
    String title,
    String key,
    List<String> mustSee,
  ) async {
    await walk.step(id, title, () async {
      if (!await walk.tapKey(key, wait: 3)) return;
      for (final value in mustSee) {
        walk.expectSee(value);
      }
    });
    await walk.back();
  }

  await accountRow('q10_account_plans', 'خططك', 'account-plans', [
    p.planName,
    p.otherPlanName,
    p.say('أنت مشارك', 'أنتِ مشاركة'),
  ]);
  await accountRow('g03_postpone', 'تأجيل العرس', 'account-postpone', [
    p.say('أجّل العرس', 'أجّلي العرس'),
  ]);
  await walk.step('g08_lock', 'قفل التطبيق', () async {
    if (!await walk.tapKey('account-app-lock', wait: 3)) return;
    walk.expectSee('رمز من 4 أرقام');
    walk.expectSee(p.say('لا تستخدم تاريخ', 'لا تستخدمي تاريخ'));
  });
  await walk.back();
  await accountRow(
    'g07_notif',
    'التنبيهات (الإعدادات)',
    'account-notifications',
    ['الدفعات'],
  );
  await accountRow('g10_support', 'المساعدة', 'account-help', [
    'أسئلة كثير يسألونها',
  ]);

  await walk.step('g11_logout', 'الخروج', () async {
    if (!await walk.tapKey('account-logout', wait: 2.5)) return;
    if (!await walk.tapText(
      p.say('اخرج من هذا الجوال', 'اخرجي من هذا الجوال'),
      required: false,
      wait: 5,
    )) {
      walk.fail(
        'زر الخروج في النافذة ما هو بكلامها (${p.say('اخرج', 'اخرجي')})',
      );
      if (!await walk.tapKey('account-logout-confirm', wait: 5)) return;
    }
    await walk.waitSignedOut();
  });

  await walk.finish();
}
