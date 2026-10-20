// Throwaway design prototype: the admin back office, desktop width.
//   flutter test test/prototype/admin/admin_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../c_journey/kit.dart';
import '../../support/preview_fonts.dart';
import 'admin_center.dart';
import 'admin_screens.dart';

Future<void> _shot(WidgetTester tester, String name, Widget screen) async {
  tester.view.physicalSize = const Size(1280 * 2, 1000 * 2);
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
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(loadPreviewAppFonts);
  final screens = <(String, Widget Function())>[
    ('n01_inbox', n01Inbox),
    ('n02_market', n02Market), ('n03_funnel', n03Funnel), ('n04_calendar', n04Calendar), ('a02_reports', a02Reports),
    ('a03_applications', a03Applications), ('a04_review', a04Review), ('a05_directory', a05Directory), ('a06_provider_suspend', a06ProviderSuspend), ('a07_listed', a07Listed),
    ('n05_lookup', n05Lookup), ('a13_user', a13User), ('n06_data_requests', n06DataRequests),
    ('a11_chat_reports', a11ChatReports), ('a10_reviews', a10Reviews), ('n07_photos', n07Photos), ('a12_bookings', a12Bookings), ('n08_fraud', n08Fraud),
    ('n09_health', n09Health), ('a16_rules', a16Rules), ('a08_categories', a08Categories), ('a09_catalogs', a09Catalogs), ('n10_flags', n10Flags),
    ('a14_team', a14Team), ('a15_audit', a15Audit),
  ];
  for (final s in screens) {
    testWidgets(s.$1, (t) => _shot(t, s.$1, s.$2()));
  }
}
