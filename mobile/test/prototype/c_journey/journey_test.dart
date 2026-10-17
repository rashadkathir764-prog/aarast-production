// Throwaway design prototype: the groom's full journey in direction C.
// Regenerate with:
//   flutter test test/prototype/c_journey/journey_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/preview_fonts.dart';
import 'kit.dart';
import 'screens_home.dart';
import 'screens_money.dart';
import 'screens_sections.dart';
import 'screens_start.dart';

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget screen, [
  double height = 844,
]) async {
  tester.view.physicalSize = Size(390 * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: fTaj),
      home: Material(child: screen),
    ),
  );
  await tester.pump();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  final screens = <(String, Widget Function(), double)>[
    ('01_splash', splash, 844),
    ('02_who', whoAreYou, 844),
    ('03_name', qName, 844),
    ('04_date', qDate, 844),
    ('05_city', qCity, 844),
    ('06_budget', qBudget, 844),
    ('07_ready', planReady, 844),
    ('08_otp', otp, 844),
    ('10_home_fresh', homeFresh, 844),
    ('11_home_active', homeActive, 1080),
    ('12_home_week', homeWeek, 1180),
    ('13_home_day', homeDay, 1000),
    ('14_home_rafd', () => homeDay(withSheet: true), 844),
    ('15_home_after', homeAfter, 1040),
    ('20_money_summary', moneySummary, 1190),
    ('21_money_items', moneyItems, 1170),
    ('22_money_payments', moneyPayments, 1070),
    ('23_money_funding', moneyFunding, 900),
    ('24_money_pay', paySheet, 844),
    ('30_tasks', tasks, 1150),
    ('31_task_add', addTaskSheet, 844),
    ('40_guests', guests, 1130),
    ('41_contacts', contactsPicker, 844),
    ('42_invite', inviteCard, 900),
    ('50_prov_requests', providersRequests, 1080),
    ('51_prov_explore', providersExplore, 1000),
    ('52_prov_page', providerPage, 1000),
    ('53_prov_compare', compareOffers, 844),
    ('60_family', family, 900),
  ];

  for (final s in screens) {
    testWidgets(s.$1, (t) => _shot(t, s.$1, s.$2(), s.$3));
  }
}
