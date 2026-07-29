import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/onboarding/data/yemen_administrative_api.dart';
import 'package:aarast_mobile/features/onboarding/models/yemen_administrative_area.dart';
import 'package:aarast_mobile/features/onboarding/providers/yemen_administrative_provider.dart';
import 'package:flutter_test/flutter_test.dart';

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
        ['YE1301'],
      );
      expect(provider.districtsForGovernorateName('صنعاء'), isEmpty);
      expect(api.districtRequests, ['governorate-capital']);
    },
  );

  test('keeps a failed governorate load retryable', () async {
    final api = _FailOnceYemenAdministrativeApi();
    final provider = YemenAdministrativeProvider(api);

    await provider.loadGovernorates();
    expect(provider.governorates, isEmpty);
    expect(provider.errorMessage, isNotNull);

    await provider.loadGovernorates();
    expect(provider.governorates.map((item) => item.code), ['YE13']);
    expect(provider.errorMessage, isNull);
    expect(api.requests, 2);
  });
}

class _FakeYemenAdministrativeApi extends YemenAdministrativeApi {
  _FakeYemenAdministrativeApi()
    : super(ApiClient(tokenProvider: () async => null));

  final List<String> districtRequests = [];

  @override
  Future<List<YemenGovernorate>> getGovernorates() async => const [
    YemenGovernorate(
      id: 'governorate-capital',
      code: 'YE13',
      nameAr: 'أمانة العاصمة',
      nameEn: "Sana'a City",
      districtsCount: 12,
    ),
    YemenGovernorate(
      id: 'governorate-sanaa',
      code: 'YE23',
      nameAr: 'صنعاء',
      nameEn: "Sana'a",
      districtsCount: 16,
    ),
  ];

  @override
  Future<List<YemenDistrict>> getDistricts(String governorateId) async {
    districtRequests.add(governorateId);
    return [
      YemenDistrict(
        id: 'district-old-city',
        governorateId: governorateId,
        code: 'YE1301',
        nameAr: 'صنعاء القديمة',
        nameEn: 'Old City',
      ),
    ];
  }
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
