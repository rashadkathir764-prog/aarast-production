// Full-screen visual previews for the welcome gateway, exactly as a first-time
// visitor sees it: the text-only hero that owns every heading, and the unified
// V3 path cards serving both the path step and the role step.
//
// Regenerate with:
//   flutter test test/welcome_gateway_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_api.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_administrative_area.dart';
import 'package:aarast_mobile/features/onboarding/providers/yemen_administrative_provider.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';

import 'support/preview_fonts.dart';

Future<void> _pumpGateway(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final yemen = YemenAdministrativeProvider(_PreviewYemenApi());
  await yemen.loadGovernorates();

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
        ChangeNotifierProvider<YemenAdministrativeProvider>.value(value: yemen),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SmartWelcomeScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('welcome gateway — path selection (390)', (tester) async {
    await _pumpGateway(tester);

    await expectLater(
      find.byType(SmartWelcomeScreen),
      matchesGoldenFile('goldens/welcome_gateway_pathselection.png'),
    );
  });

  testWidgets('welcome gateway — role selection (390)', (tester) async {
    await _pumpGateway(tester);

    await tester.tap(find.text('إنشاء خطتك'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العريس'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SmartWelcomeScreen),
      matchesGoldenFile('goldens/welcome_gateway_roleselection.png'),
    );
  });

  testWidgets('welcome gateway — shared plan setup (390)', (tester) async {
    await _pumpGateway(tester);

    await tester.tap(find.text('إنشاء خطتك'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العريس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SmartWelcomeScreen),
      matchesGoldenFile('goldens/welcome_gateway_plan_setup.png'),
    );
  });
}

class _PreviewYemenApi extends YemenAdministrativeApi {
  _PreviewYemenApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<YemenGovernorate>> getGovernorates() async => const [
    YemenGovernorate(
      id: 'capital',
      code: 'YE13',
      nameAr: 'أمانة العاصمة',
      nameEn: "Sana'a City",
      districtsCount: 2,
    ),
    YemenGovernorate(
      id: 'sanaa',
      code: 'YE23',
      nameAr: 'صنعاء',
      nameEn: "Sana'a",
      districtsCount: 1,
    ),
  ];

  @override
  Future<List<YemenDistrict>> getDistricts(String governorateId) async =>
      const [
        YemenDistrict(
          id: 'district-1',
          governorateId: 'capital',
          code: '1301',
          nameAr: 'بني الحارث',
          nameEn: 'Bani Al Harith',
        ),
      ];
}
