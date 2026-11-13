import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-288 (batch 9): the provider's edit forms sent every field as the
// phone had read it. A save from a copy a little old (his other phone, an
// edit by the team) undid the change made meanwhile. The server keeps what
// it is not sent, so an edit sends what it changed.
void main() {
  late _Api api;
  late ProviderDashboardProvider dashboard;

  setUp(() async {
    api = _Api();
    dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();
    expect(dashboard.services, hasLength(1));
    expect(dashboard.packages, hasLength(1));
  });

  test('a service: a new price sends the price alone', () async {
    final saved = await dashboard.updateService(
      serviceId: 'service-1',
      title: 'تصوير العرس',
      description: 'مصورين اثنين',
      basePrice: '450000',
      priceUnit: 'للحفلة',
      currency: 'YER',
    );

    expect(saved, isTrue);
    expect(api.serviceEdits.single, {'basePrice': '450000'});
  });

  test(
    'a service: «400000» for «400000.00» is no change, and asks nothing',
    () async {
      final saved = await dashboard.updateService(
        serviceId: 'service-1',
        title: 'تصوير العرس',
        description: 'مصورين اثنين',
        basePrice: '400000',
        priceUnit: 'للحفلة',
        currency: 'yer',
      );

      expect(saved, isTrue);
      expect(api.serviceEdits, isEmpty);
    },
  );

  test(
    'a package: a cleared description and new items go, the rest stays',
    () async {
      final saved = await dashboard.updatePackage(
        packageId: 'package-1',
        title: 'الباقة الذهبية',
        description: '',
        price: '600000',
        currency: 'YER',
        items: const ['ألبوم', 'فيلم', 'درون'],
      );

      expect(saved, isTrue);
      expect(api.packageEdits.single, {
        'description': '',
        'items': ['ألبوم', 'فيلم', 'درون'],
      });
    },
  );

  test('the profile: a corrected name sends the name alone', () async {
    final saved = await dashboard.updateProfile(
      businessName: 'استديو الفن الجديد',
      // The same number in its local spelling.
      phone: '771554220',
      cityId: 'sanaa',
      description: 'تصوير أعراس',
    );

    expect(saved, isTrue);
    expect(api.profileEdits.single, {'businessName': 'استديو الفن الجديد'});
  });

  test('the profile: a save that changed nothing asks nothing', () async {
    final saved = await dashboard.updateProfile(
      businessName: 'استديو الفن',
      phone: '+967771554220',
      cityId: 'sanaa',
      description: 'تصوير أعراس',
    );

    expect(saved, isTrue);
    expect(api.profileEdits, isEmpty);
  });
}

class _Api extends ProviderDashboardApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  final serviceEdits = <Map<String, Object?>>[];
  final packageEdits = <Map<String, Object?>>[];
  final profileEdits = <Map<String, Object?>>[];

  static const _profile = ProviderDashboardProfile(
    id: 'provider-1',
    businessName: 'استديو الفن',
    status: 'ACTIVE',
    ratingAverage: 0,
    ratingCount: 0,
    cityId: 'sanaa',
    phone: '+967771554220',
    description: 'تصوير أعراس',
  );

  static const _service = MarketplaceService(
    id: 'service-1',
    providerId: 'provider-1',
    title: 'تصوير العرس',
    description: 'مصورين اثنين',
    basePrice: '400000.00',
    priceUnit: 'للحفلة',
    currency: 'YER',
    isActive: true,
  );

  static const _package = ProviderPackage(
    id: 'package-1',
    providerId: 'provider-1',
    title: 'الباقة الذهبية',
    description: 'كل شي',
    price: '600000.00',
    currency: 'YER',
    items: 'ألبوم\nفيلم',
    isActive: true,
  );

  @override
  Future<ProviderDashboardProfile> getProfile() async => _profile;

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary.empty();

  @override
  Future<List<MarketplaceService>> getServices() async => const [_service];

  @override
  Future<List<ProviderPackage>> getPackages() async => const [_package];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => const [];

  @override
  Future<List<ProviderReview>> getReviews() async => const [];

  @override
  Future<List<MarketplaceBooking>> getBookings() async => const [];

  @override
  Future<List<DateTime>> getBlockedDates() async => const [];

  @override
  Future<MarketplaceService> updateService({
    required String serviceId,
    String? title,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    bool? isActive,
  }) async {
    serviceEdits.add({
      'title': ?title,
      'description': ?description,
      'basePrice': ?basePrice,
      'priceUnit': ?priceUnit,
      'currency': ?currency,
    });
    return _service;
  }

  @override
  Future<ProviderPackage> updatePackage({
    required String packageId,
    String? title,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String>? items,
    bool? isActive,
  }) async {
    packageEdits.add({
      'title': ?title,
      'description': ?description,
      'price': ?price,
      'currency': ?currency,
      'items': ?items,
    });
    return _package;
  }

  @override
  Future<ProviderDashboardProfile> updateProfile({
    String? businessName,
    String? phone,
    String? cityId,
    String? description,
    String? logoUrl,
    String? coverUrl,
  }) async {
    profileEdits.add({
      'businessName': ?businessName,
      'phone': ?phone,
      'cityId': ?cityId,
      'description': ?description,
    });
    return _profile;
  }
}
