// Full-screen visual preview for the welcome gateway path-selection step —
// the royal burgundy hero + the three color-coded premium path cards + the
// login prompt, exactly as a first-time visitor sees it.
//
// Regenerate with:
//   flutter test test/welcome_gateway_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';

import 'support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('welcome gateway — path selection (390)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>(create: (_) => AuthStorage(prefs)),
          Provider<GuestOnboardingStorage>(
            create: (_) => GuestOnboardingStorage(prefs),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const SmartWelcomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(SmartWelcomeScreen),
      matchesGoldenFile('goldens/welcome_gateway_pathselection.png'),
    );
  });
}
