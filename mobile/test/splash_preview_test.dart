@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  for (final view in [
    (name: '390', size: const Size(390, 860), scale: 1.0),
    (name: '320_large', size: const Size(320, 700), scale: 1.3),
    (name: '420', size: const Size(420, 900), scale: 1.0),
  ]) {
    testWidgets('splash — ${view.name}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = AuthStorage(await SharedPreferences.getInstance());
      // Leave the real controller checking: the screen can be inspected
      // without changing its production timing or navigation behavior.
      final auth = AuthController(
        AuthRepository(
          ApiClient(tokenProvider: storage.readAccessToken),
          storage,
        ),
      );
      addTearDown(auth.dispose);
      tester.view.physicalSize = view.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(view.scale)),
              child: child!,
            ),
            home: const SplashScreen(),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/journey/celebration.png'),
          tester.element(find.byType(SplashScreen)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await expectLater(
        find.byType(SplashScreen),
        matchesGoldenFile('goldens/splash_${view.name}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 180));
    });
  }
}
