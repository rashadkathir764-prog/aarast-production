// Throwaway design prototype: the admin back office, desktop width.
//   flutter test test/prototype/admin/admin_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../c_journey/kit.dart';
import '../../support/preview_fonts.dart';
import 'admin_screens.dart';

Future<void> _shot(WidgetTester tester, String name, Widget screen) async {
  tester.view.physicalSize = const Size(1280 * 2, 900 * 2);
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
    ('a01_dashboard', a01Dashboard), ('a02_reports', a02Reports), ('a03_applications', a03Applications), ('a04_review', a04Review),
    ('a05_directory', a05Directory), ('a06_provider_suspend', a06ProviderSuspend), ('a07_listed', a07Listed),
    ('a08_categories', a08Categories), ('a09_catalogs', a09Catalogs), ('a10_reviews', a10Reviews), ('a11_chat_reports', a11ChatReports),
    ('a12_bookings', a12Bookings), ('a13_user', a13User), ('a14_team', a14Team), ('a15_audit', a15Audit), ('a16_rules', a16Rules),
  ];
  for (final s in screens) {
    testWidgets(s.$1, (t) => _shot(t, s.$1, s.$2()));
  }
}
