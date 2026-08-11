import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_api.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_fallback.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_administrative_area.dart';
import 'package:aarast_mobile/features/onboarding/providers/yemen_administrative_provider.dart';
import 'package:aarast_mobile/features/onboarding/widgets/location_picker_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'loads districts only from the selected governorate reference',
    () async {
      final api = _FakeYemenAdministrativeApi();
      final provider = YemenAdministrativeProvider(api);

      await provider.loadGovernorates();
      await provider.loadDistrictsForGovernorateName('أمانة العاصمة');

      expect(provider.governorates.map((item) => item.code), ['YE13', 'YE23']);
      expect(
        provider
            .districtsForGovernorateName('أمانة العاصمة')
            .map((item) => item.code),
        ['YE1302', 'YE1301', 'YE1303'],
      );
      expect(provider.districtsForGovernorateName('صنعاء'), isEmpty);
      expect(api.districtRequests, ['governorate-capital']);
    },
  );

  test(
    'keeps the complete local Yemen catalog when the API is unavailable',
    () async {
      final api = _FailOnceYemenAdministrativeApi();
      final provider = YemenAdministrativeProvider(api);

      await provider.loadGovernorates();
      expect(provider.governorates, hasLength(22));
      expect(
        provider.governorates.fold<int>(
          0,
          (total, item) => total + item.districtsCount,
        ),
        335,
      );
      expect(provider.errorMessage, isNull);
      expect(api.requests, 1);
    },
  );

  test('bundled Yemen catalog contains every approved district', () {
    expect(yemenFallbackGovernorates, hasLength(22));
    expect(
      yemenFallbackDistrictsByGovernorateId.values.expand((items) => items),
      hasLength(335),
    );
    expect(
      yemenFallbackGovernorates.map((item) => item.nameAr),
      containsAll(<String>['أمانة العاصمة', 'صنعاء', 'سقطرى', 'تعز']),
    );
  });

  testWidgets('selects governorate then district from searchable catalog', (
    tester,
  ) async {
    final provider = YemenAdministrativeProvider(_FakeYemenAdministrativeApi());
    await provider.loadGovernorates();
    final controllers = List.generate(6, (_) => TextEditingController());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<YemenAdministrativeProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: LocationPickerSection(
              governorateController: controllers[0],
              cityOrDistrictController: controllers[1],
              areaOrNeighborhoodController: controllers[2],
              neighborhoodController: controllers[3],
              streetController: controllers[4],
              detailedAddressController: controllers[5],
              showOptionalDetails: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('اختر المحافظة'));
    await tester.pumpAndSettle();
    expect(find.text('اختر المحافظة'), findsWidgets);
    await tester.tap(find.text('أمانة العاصمة'));
    await tester.pumpAndSettle();

    expect(controllers[0].text, 'أمانة العاصمة');
    await tester.tap(find.text('اختر المديرية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('صنعاء القديمة'));
    await tester.pumpAndSettle();

    expect(controllers[1].text, 'صنعاء القديمة');
    expect(find.text('المنطقة أو العزلة'), findsOneWidget);
    expect(find.text('الحي'), findsOneWidget);
    await tester.tap(find.text('اختر أو اكتب').last);
    await tester.pumpAndSettle();
    expect(find.text('باب اليمن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeYemenAdministrativeApi extends YemenAdministrativeApi {
  _FakeYemenAdministrativeApi()
    : super(ApiClient(tokenProvider: () async => null));

  final List<String> districtRequests = [];

  @override
  Future<List<YemenGovernorate>> getGovernorates() async => const [
    YemenGovernorate(
      id: 'governorate-sanaa',
      code: 'YE23',
      nameAr: 'صنعاء',
      nameEn: "Sana'a",
      districtsCount: 16,
    ),
    YemenGovernorate(
      id: 'governorate-capital',
      code: 'YE13',
      nameAr: 'أمانة العاصمة',
      nameEn: "Sana'a City",
      districtsCount: 12,
    ),
  ];

  @override
  Future<List<YemenDistrict>> getDistricts(String governorateId) async {
    districtRequests.add(governorateId);
    return [
      YemenDistrict(
        id: 'district-unity',
        governorateId: governorateId,
        code: 'YE1303',
        nameAr: 'الوحدة',
        nameEn: 'Al Wahdah',
      ),
      YemenDistrict(
        id: 'district-old-city',
        governorateId: governorateId,
        code: 'YE1301',
        nameAr: 'صنعاء القديمة',
        nameEn: 'Old City',
      ),
      YemenDistrict(
        id: 'district-sabeen',
        governorateId: governorateId,
        code: 'YE1302',
        nameAr: 'السبعين',
        nameEn: "As Sab'in",
      ),
    ];
  }

  @override
  Future<List<YemenLocality>> getLocalities(String districtId) async => [
    YemenLocality(
      id: 'locality-old-city',
      districtId: districtId,
      code: 'YE1301-N-01',
      type: YemenLocalityType.neighborhood,
      nameAr: 'باب اليمن',
      sortOrder: 10,
    ),
  ];
}

class _FailOnceYemenAdministrativeApi extends YemenAdministrativeApi {
  _FailOnceYemenAdministrativeApi()
    : super(ApiClient(tokenProvider: () async => null));

  int requests = 0;

  @override
  Future<List<YemenGovernorate>> getGovernorates() async {
    requests++;
    if (requests == 1) throw StateError('temporary test failure');
    return const [
      YemenGovernorate(
        id: 'governorate-capital',
        code: 'YE13',
        nameAr: 'أمانة العاصمة',
        nameEn: "Sana'a City",
        districtsCount: 12,
      ),
    ];
  }
}
