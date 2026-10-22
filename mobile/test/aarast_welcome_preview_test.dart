// Visual preview for the shared V3 plan setup fields (the welcome cards
// moved to the journey kit with the redesigned start).
//
// Regenerate with:
//   flutter test test/aarast_welcome_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_api.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_administrative_area.dart';
import 'package:aarast_mobile/features/onboarding/providers/yemen_administrative_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/wedding_plan_creation_form.dart';

import 'support/preview_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.canvas,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('welcome — shared plan creation form (420)', (tester) async {
    final name = TextEditingController(text: 'عرسنا');
    final governorate = TextEditingController(text: 'أمانة العاصمة');
    final district = TextEditingController(text: 'بني الحارث');
    final area = TextEditingController();
    final neighborhood = TextEditingController();
    final street = TextEditingController();
    final address = TextEditingController();
    final budget = TextEditingController(text: '3000000');
    addTearDown(name.dispose);
    addTearDown(governorate.dispose);
    addTearDown(district.dispose);
    addTearDown(area.dispose);
    addTearDown(neighborhood.dispose);
    addTearDown(street.dispose);
    addTearDown(address.dispose);
    addTearDown(budget.dispose);
    final yemen = YemenAdministrativeProvider(_PreviewYemenApi());
    await yemen.loadGovernorates();
    await yemen.loadDistrictsForGovernorateName('أمانة العاصمة');

    await _pump(
      tester,
      ChangeNotifierProvider<YemenAdministrativeProvider>.value(
        value: yemen,
        child: WeddingPlanCreationFields(
          titleController: name,
          governorateController: governorate,
          cityOrDistrictController: district,
          areaOrNeighborhoodController: area,
          neighborhoodController: neighborhood,
          streetController: street,
          detailedAddressController: address,
          budgetController: budget,
          currency: 'YER',
          weddingDate: DateTime(2026, 8, 31),
          showOptionalAddress: false,
          onSelectDate: () {},
          onCurrencyChanged: (_) {},
          onToggleOptionalAddress: () {},
          onChanged: () {},
        ),
      ),
      size: const Size(420, 700),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/aarast_welcome_fields.png'),
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
  Future<List<YemenDistrict>> getDistricts(String governorateId) async {
    if (governorateId == 'capital') {
      return const [
        YemenDistrict(
          id: 'bani-al-harith',
          governorateId: 'capital',
          code: '1301',
          nameAr: 'بني الحارث',
          nameEn: 'Bani Al Harith',
        ),
        YemenDistrict(
          id: 'old-city',
          governorateId: 'capital',
          code: '1302',
          nameAr: 'صنعاء القديمة',
          nameEn: 'Old City',
        ),
      ];
    }
    return const [
      YemenDistrict(
        id: 'hamdan',
        governorateId: 'sanaa',
        code: '2301',
        nameAr: 'همدان',
        nameEn: 'Hamdan',
      ),
    ];
  }

  @override
  Future<List<YemenLocality>> getLocalities(String districtId) async => [
    YemenLocality(
      id: 'area-rawdha',
      districtId: districtId,
      code: 'YE13-A-01',
      type: YemenLocalityType.area,
      nameAr: 'الروضة',
      sortOrder: 10,
    ),
    YemenLocality(
      id: 'neighborhood-airport',
      districtId: districtId,
      code: 'YE13-N-01',
      type: YemenLocalityType.neighborhood,
      nameAr: 'حي المطار',
      sortOrder: 20,
    ),
  ];
}
