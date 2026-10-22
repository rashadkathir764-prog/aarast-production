// Full-screen visual previews of the journey start, exactly as a first-time
// visitor sees it: «أهلًا فيك» (a02), «خطة مين؟» (a02b), and the name and
// date question (a03).
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

Future<void> _pumpGateway(WidgetTester tester) async {
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
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: SmartWelcomeScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('journey start — أهلًا فيك (390)', (tester) async {
    await _pumpGateway(tester);

    await expectLater(
      find.byType(SmartWelcomeScreen),
      matchesGoldenFile('goldens/welcome_gateway_start.png'),
    );
  });

  testWidgets('journey start — خطة مين؟ (390)', (tester) async {
    await _pumpGateway(tester);

    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();
    // The groom's photo decodes off the test clock; wait for it.
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/journey/groom.jpg'),
        tester.element(find.byType(SmartWelcomeScreen)),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SmartWelcomeScreen),
      matchesGoldenFile('goldens/welcome_gateway_whose.png'),
    );
  });

  testWidgets('journey start — name and date (390)', (tester) async {
    await _pumpGateway(tester);

    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SmartWelcomeScreen),
      matchesGoldenFile('goldens/welcome_gateway_name_date.png'),
    );
  });
}
