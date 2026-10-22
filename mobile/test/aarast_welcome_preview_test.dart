// Visual preview for the harmonized welcome gateway components: the unified
// AarastPathCard (navigation + choice modes) and the V3 setup fields.
//
// Regenerate with:
//   flutter test test/aarast_welcome_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_api.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_administrative_area.dart';
import 'package:aarast_mobile/features/onboarding/providers/yemen_administrative_provider.dart';
import 'package:aarast_mobile/features/welcome_gateway/widgets/aarast_path_card.dart';
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

  testWidgets('welcome — path + role cards (420)', (tester) async {
    await _pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastPathCard(
            title: 'إنشاء خطتك',
            subtitle: 'ابدأ خطة جديدة ثم خصصها حسب دورك.',
            icon: LucideIcons.clipboardList,
            tone: AarastPathTone.hero,
            onTap: () {},
          ),
          const SizedBox(height: 14),
          AarastPathCard(
            title: 'وصلتني دعوة لخطة',
            subtitle: 'الدخول إلى خطة تمت دعوتك إليها برقم هاتفك.',
            icon: LucideIcons.mailCheck,
            tone: AarastPathTone.accent,
            onTap: () {},
          ),
          const SizedBox(height: 14),
          AarastPathCard(
            title: 'أنا مزود خدمة',
            subtitle: 'إدارة حساب المزود أو طلب الانضمام.',
            icon: LucideIcons.store,
            tone: AarastPathTone.quiet,
            onTap: () {},
          ),
          const SizedBox(height: 22),
          AarastPathCard(
            title: 'العريس',
            subtitle: 'أتابع الخطة والميزانية',
            icon: LucideIcons.user,
            tone: AarastPathTone.hero,
            selected: true,
            onTap: () {},
          ),
          const SizedBox(height: 14),
          AarastPathCard(
            title: 'العروسة',
            subtitle: 'أرتب التفاصيل والاختيارات',
            icon: LucideIcons.flower2,
            tone: AarastPathTone.accent,
            selected: false,
            onTap: () {},
          ),
        ],
      ),
      size: const Size(420, 900),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/aarast_welcome_cards.png'),
    );
  });

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
