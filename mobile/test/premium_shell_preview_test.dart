// Visual preview for the harmonized app shell (phase/mobile-premium-screens-v1):
// RoyalDashboardBottomNav (Lucide icons + champagne active indicator) and
// RoyalSmartFloatingActionButton (calmed gold breath).
//
// Regenerate with:
//   flutter test test/premium_shell_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/royal_home_chrome.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load('Tajawal', [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]);
  await load('IBMPlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
  await load('packages/lucide_icons/Lucide',
      ['packages/lucide_icons/assets/lucide.ttf']);
}

Future<void> _pump(WidgetTester tester, {required int activeIndex}) async {
  tester.view.physicalSize = const Size(420, 320);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
          extendBody: true,
          floatingActionButton: RoyalSmartFloatingActionButton(
            icon: null,
            onPressed: () {},
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: RoyalDashboardBottomNav(
            activeIndex: activeIndex,
            onHome: () {},
            onMoney: () {},
            onTasks: () {},
            onGuests: () {},
            onProviders: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('shell — dock active on home (420)', (tester) async {
    await _pump(tester, activeIndex: 0);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_shell_home.png'),
    );
  });

  testWidgets('shell — dock active on guests (420)', (tester) async {
    await _pump(tester, activeIndex: 3);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/premium_shell_guests.png'),
    );
  });
}
