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
  tester.view.physicalSize = const Size(1280 * 2, 800 * 2);
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
    ('a01_today', a01Today), ('a02_joins', a02Joins), ('a03_review', a03Review), ('a04_verify', a04Verify),
    ('a05_reports', a05Reports), ('a06_deposits', a06Deposits), ('a07_listings', a07Listings),
    ('a08_categories', a08Categories), ('a09_support', a09Support), ('a10_settings', a10Settings), ('a11_log', a11Log),
  ];
  for (final s in screens) {
    testWidgets(s.$1, (t) => _shot(t, s.$1, s.$2()));
  }
}
