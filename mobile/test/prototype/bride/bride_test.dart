// Throwaway design prototype: the bride's own journey (Sanaa women's week).
//   flutter test test/prototype/bride/bride_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../c_journey/kit.dart';
import '../../support/preview_fonts.dart';
import '../v3/hard.dart' show vHomeNoDate;
import '../v3/lights.dart' show vWhose;
import '../v3/money.dart' show vMoneyItems;
import '../v3/sections.dart' show vProvRequests;
import '../v3/smart.dart' show vImpactChain;
import 'sections.dart';
import 'start_home.dart';

Future<void> _shot(WidgetTester tester, String name, Widget screen, double h) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: fTaj),
      home: Material(child: screen),
    ),
  );
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(loadPreviewAppFonts);
  final screens = <(String, Widget Function(), double)>[
    ('w01_name', bName, 844), ('w02_week', bWeek, 900), ('w03_mahr', bMahr, 844), ('w04_budget', bBudget, 900), ('w05_ready', bReady, 844),
    ('w06_home_fresh', bHomeFresh, 900), ('w07_home_active', bHomeActive, 1000), ('w08_moment_week', bMomentWeek, 900),
    ('w09_home_week', bHomeWeek, 1180), ('w10_home_day', bHomeDay, 1000), ('w11_home_after', bHomeAfter, 960),
    ('w12_money', bMoney, 1000), ('w13_gold', bGold, 960), ('w14_add_gold', bAddGold, 960), ('w15_jahaz', bJahaz, 1000),
    ('w16_dresses', outfits, 1000), ('w17_gifts', bGifts, 960),
    ('w18_tasks', bTasks, 900), ('w19_appointments', bAppointments, 1000),
    ('w20_guests', bGuests, 900), ('w21_invite', bInvite, 1000),
    ('w22_providers', bProviders, 960), ('w23_photographer', bPhotographer, 1060),
    ('w24_people', bPeople, 900), ('w25_privacy', bPrivacy, 900),
    // The same groom screens rendered with the bride's profile, and one
    // bride feature rendered for the groom.
    ('p01_whose_bride', () => vWhose(bride: true), 844),
    ('p02_items_bride', () => vMoneyItems(bride: true), 1000),
    ('p03_requests_bride', () => vProvRequests(bride: true), 900),
    ('p04_no_date_bride', () => vHomeNoDate(bride: true), 900),
    ('p05_impact_bride', () => vImpactChain(bride: true), 900),
    ('p06_outfits_groom', () => outfits(bride: false), 844),
  ];
  for (final s in screens) {
    testWidgets(s.$1, (t) => _shot(t, s.$1, s.$2(), s.$3));
  }
}
