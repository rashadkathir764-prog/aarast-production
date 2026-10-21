// Throwaway design prototype: renders the journey for the clickable
// prototype. Screens are drawn without the tab bar (the prototype keeps one
// fixed bar on top), the five tab bars are drawn on their own, and every
// tappable element's rectangle is written to out_live/hotspots.json.
//
//   flutter test test/prototype/c_journey/interactive_test.dart --update-goldens
@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../support/preview_fonts.dart';
import 'kit.dart';
import 'screens_home.dart';
import 'screens_money.dart';
import 'screens_sections.dart';
import 'screens_start.dart';

typedef Spot = (Object finder, String target);

const _back = LucideIcons.arrowRight;

final screens = <String, (Widget Function(), Sec?, List<Spot>)>{
  '01_splash': (splash, null, [('*', '02_who')]),
  '02_who': (
    whoAreYou,
    null,
    [('العريس', '03_name'), ('عندك حساب؟  ادخل برقمك', '08_otp')],
  ),
  '03_name': (qName, null, [('التالي', '04_date'), (_back, 'back')]),
  '04_date': (
    qDate,
    null,
    [
      ('التالي', '05_city'),
      ('ما حددنا الموعد بعد', '05_city'),
      (_back, 'back'),
    ],
  ),
  '05_city': (qCity, null, [('التالي', '06_budget'), (_back, 'back')]),
  '06_budget': (
    qBudget,
    null,
    [
      ('جهّز خطتي', '07_ready'),
      ('ما أدري، ساعدني أحسبها', '07_ready'),
      (_back, 'back'),
    ],
  ),
  '07_ready': (
    planReady,
    null,
    [
      ('احفظ خطتي برقم جوالي', '08_otp'),
      ('بعدين، خلني أشوف أول', '10_home_fresh'),
    ],
  ),
  '08_otp': (otp, null, [('*', '10_home_fresh'), (_back, 'back')]),
  '10_home_fresh': (
    homeFresh,
    Sec.home,
    [
      ('كمّل', '50_prov_requests'),
      ('ميزانيتك', '21_money_items'),
      ('قائمة الضيوف', '41_contacts'),
      ('م', '60_family'),
    ],
  ),
  '11_home_active': (
    homeActive,
    Sec.home,
    [
      ('سجّل الدفعة', '24_money_pay'),
      ('ذكّرني', 'toast:بنذكرك بكرة الصبح'),
      ('ناقصك', '20_money_summary'),
      ('1.3 مليون ر.ي', '20_money_summary'),
      ('من 20 مهمة', '30_tasks'),
      ('أكدوا من 124', '40_guests'),
      ('محجوز من 7', '50_prov_requests'),
      ('قارن', '53_prov_compare'),
      ('ذكّرهم', '40_guests'),
      ('ابحث', '51_prov_explore'),
      ('م', '60_family'),
    ],
  ),
  '12_home_week': (
    homeWeek,
    Sec.home,
    [
      ('أرسل التأكيد', 'toast:انرسل التأكيد لفرقة الأفراح على واتساب'),
      ('م', '60_family'),
    ],
  ),
  '13_home_day': (
    homeDay,
    Sec.home,
    [('سجّل رفد', '14_home_rafd'), ('م', '60_family')],
  ),
  '14_home_rafd': (
    () => homeDay(withSheet: true),
    null,
    [
      ('حفظ وسجّل التالي', 'toast:انحفظ رفد عبدالله الحمدي · 20,000'),
      ('*top', 'back'),
    ],
  ),
  '15_home_after': (
    homeAfter,
    Sec.home,
    [('سجّل السداد', '22_money_payments'), ('م', '60_family')],
  ),
  '20_money_summary': (
    moneySummary,
    Sec.money,
    [
      ('البنود', '21_money_items'),
      ('الدفعات', '22_money_payments'),
      ('من وين', '23_money_funding'),
      ('سجّل الدفعة', '24_money_pay'),
      ('ذكّرني', 'toast:بنذكرك بكرة الصبح'),
      ('خفّف بند', '21_money_items'),
      ('سجّل مساعدة موعودة', '23_money_funding'),
    ],
  ),
  '21_money_items': (
    moneyItems,
    Sec.money,
    [
      ('الملخص', '20_money_summary'),
      ('الدفعات', '22_money_payments'),
      ('من وين', '23_money_funding'),
    ],
  ),
  '22_money_payments': (
    moneyPayments,
    Sec.money,
    [
      ('الملخص', '20_money_summary'),
      ('البنود', '21_money_items'),
      ('من وين', '23_money_funding'),
      ('دفعتها', '24_money_pay'),
    ],
  ),
  '23_money_funding': (
    moneyFunding,
    Sec.money,
    [
      ('الملخص', '20_money_summary'),
      ('البنود', '21_money_items'),
      ('الدفعات', '22_money_payments'),
    ],
  ),
  '24_money_pay': (
    paySheet,
    null,
    [
      ('حفظ الدفعة', 'toast:انحفظت دفعة القاعة · 500,000 ر.ي'),
      ('*top', 'back'),
    ],
  ),
  '30_tasks': (
    tasks,
    Sec.tasks,
    [
      ('شوف الكوشات', '51_prov_explore'),
      ('قارن العروض', '53_prov_compare'),
      ('سجّل الدفعة', '24_money_pay'),
      ('افتح الضيوف', '40_guests'),
      ('ابحث عن فرقة', '51_prov_explore'),
      (LucideIcons.plus, '31_task_add'),
    ],
  ),
  '31_task_add': (
    addTaskSheet,
    null,
    [('حفظ المهمة', 'toast:انضافت المهمة لهذا الشهر'), ('*top', 'back')],
  ),
  '40_guests': (
    guests,
    Sec.guests,
    [
      ('ذكّرهم الآن', 'toast:انرسل التذكير لـ 20 ضيف على واتساب'),
      (LucideIcons.plus, '41_contacts'),
      ('المجموعات', '42_invite'),
    ],
  ),
  '41_contacts': (
    contactsPicker,
    null,
    [
      ('أضف 12 ضيف إلى أهل العريس', 'toast:انضاف 12 ضيف إلى أهل العريس'),
      (_back, 'back'),
    ],
  ),
  '42_invite': (
    inviteCard,
    null,
    [
      ('أرسلها على واتساب لـ 124 ضيف', 'toast:انرسلت الدعوة لـ 124 ضيف'),
      (_back, 'back'),
    ],
  ),
  '50_prov_requests': (
    providersRequests,
    Sec.providers,
    [
      ('استكشف', '51_prov_explore'),
      ('قارن واختر', '53_prov_compare'),
      ('قارن', '53_prov_compare'),
      ('ابحث', '51_prov_explore'),
    ],
  ),
  '51_prov_explore': (
    providersExplore,
    Sec.providers,
    [
      ('طلباتي', '50_prov_requests'),
      ('فرقة الأفراح', '52_prov_page'),
      ('الفنان أيمن القاضي', '52_prov_page'),
    ],
  ),
  '52_prov_page': (
    providerPage,
    null,
    [
      ('اطلب عرض سعر', 'toast:انرسل طلبك، والرد عادة خلال يوم'),
      (_back, 'back'),
    ],
  ),
  '53_prov_compare': (
    compareOffers,
    null,
    [('اختر هذا', 'toast:اخترت ضوء صنعاء، وصار بند في المال'), (_back, 'back')],
  ),
  '60_family': (family, null, [(_back, 'back')]),
};

const _tall = {
  '11_home_active': 1080.0,
  '12_home_week': 1180.0,
  '13_home_day': 1000.0,
  '15_home_after': 1040.0,
  '20_money_summary': 1190.0,
  '21_money_items': 1170.0,
  '22_money_payments': 1070.0,
  '23_money_funding': 900.0,
  '30_tasks': 1150.0,
  '40_guests': 1130.0,
  '50_prov_requests': 1080.0,
  '51_prov_explore': 1000.0,
  '52_prov_page': 1000.0,
  '60_family': 900.0,
};

Future<void> _pump(WidgetTester tester, Widget w, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: fTaj),
      home: Material(child: w),
    ),
  );
  await tester.pump();
}

/// The tappable area: the outermost box around [f] that still looks like one
/// control (a button, a row card, a tile), not a whole section.
Rect _grow(WidgetTester tester, Finder f) {
  final el = f.evaluate().first;
  var best = tester.getRect(f.first).inflate(10);
  var grew = false;
  el.visitAncestorElements((a) {
    if (a.widget is Container || a.widget is DecoratedBox) {
      final ro = a.renderObject;
      if (ro is RenderBox && ro.hasSize) {
        final r = ro.localToGlobal(Offset.zero) & ro.size;
        if (r.height > 170 || r.width > 380) return false;
        best = r;
        grew = true;
      }
    }
    return true;
  });
  return grew ? best.inflate(2) : best;
}

List<double> _r(Rect r) => [
  r.left,
  r.top,
  r.width,
  r.height,
].map((v) => double.parse(v.toStringAsFixed(1))).toList();

void main() {
  setUpAll(() async {
    await loadPreviewAppFonts();
    hideNav = true;
  });

  final out = <String, Object>{};

  for (final e in screens.entries) {
    testWidgets(e.key, (tester) async {
      final (build, nav, spots) = e.value;
      final h = _tall[e.key] ?? 844.0;
      await _pump(tester, build(), Size(390, h));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out_live/${e.key}.png'),
      );
      final list = <Map<String, Object>>[];
      for (final (f, target) in spots) {
        Rect? rect;
        if (f == '*') {
          rect = Rect.fromLTWH(0, 0, 390, h);
        } else if (f == '*top') {
          rect = const Rect.fromLTWH(0, 0, 390, 300);
        } else {
          final finder = f is IconData
              ? find.byIcon(f)
              : find.text(f as String, findRichText: true);
          if (finder.evaluate().isEmpty) {
            fail('${e.key}: no "$f" on screen');
          }
          rect = _grow(tester, finder);
        }
        list.add({'r': _r(rect), 'to': target});
      }
      out[e.key] = {'h': h, 'nav': nav?.name ?? '', 'spots': list};
    });
  }

  for (final s in Sec.values) {
    testWidgets('nav ${s.name}', (tester) async {
      await _pump(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            color: K.bg,
            alignment: Alignment.bottomCenter,
            child: NavBar(active: s),
          ),
        ),
        const Size(390, 92),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out_live/nav_${s.name}.png'),
      );
      final tabs = <Map<String, Object>>[];
      for (final t in Sec.values) {
        final r = tester.getRect(find.text(t.label));
        tabs.add({'r': _r(r.inflate(14)), 'to': t.name});
      }
      out['nav_${s.name}'] = {'h': 92, 'spots': tabs};
    });
  }

  tearDownAll(() {
    File('test/prototype/c_journey/out_live/hotspots.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  });
}
