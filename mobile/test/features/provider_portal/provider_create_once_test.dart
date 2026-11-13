import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-296 (batch 9): adding a service or a package carried no request
// key. When the server added it and the answer was lost, «جرّب مرة ثانية»
// added it a second time, in front of his customers. The press again now
// carries the same key, and the server answers it with the first one.
//
// RA-MO-298: a failed read of the joining service looked like «no service
// yet», so the save took the add road and the server refused it.
void main() {
  test('a press again after a lost answer is the same request', () async {
    final api = _Api(status: 'ACTIVE');
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    api.loseNextAnswer = true;
    expect(await _addService(dashboard), isFalse);
    expect(await _addService(dashboard), isTrue);

    expect(api.serviceKeys, hasLength(2));
    expect(api.serviceKeys[0], api.serviceKeys[1]);
    // The server added one service, and the next one is a new request.
    expect(await _addService(dashboard), isTrue);
    expect(api.serviceKeys[2], isNot(api.serviceKeys[0]));
  });

  test('a changed form after a lost answer is a new request', () async {
    final api = _Api(status: 'ACTIVE');
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    api.loseNextAnswer = true;
    expect(await _addPackage(dashboard, price: '500000'), isFalse);
    expect(await _addPackage(dashboard, price: '550000'), isTrue);

    expect(api.packageKeys, hasLength(2));
    expect(api.packageKeys[1], isNot(api.packageKeys[0]));
  });

  test('a refusal ends the attempt', () async {
    final api = _Api(status: 'ACTIVE');
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    api.refuseNext = true;
    expect(await _addService(dashboard), isFalse);
    expect(await _addService(dashboard), isTrue);

    expect(api.serviceKeys[1], isNot(api.serviceKeys[0]));
  });

  test(
    'joining service: an unread service is read again, never added',
    () async {
      final api = _Api(status: 'NEEDS_CHANGES')..failServiceReads = 1;
      final dashboard = ProviderDashboardProvider(api);
      await dashboard.loadDashboard();
      expect(dashboard.joiningService, isNull);

      final saved = await dashboard.saveJoiningService(
        title: 'تصوير كامل',
        price: '450000',
      );

      expect(saved, isTrue);
      expect(api.serviceKeys, isEmpty);
      expect(api.serviceEdits, ['service-1']);
    },
  );

  test('joining service: still unread, nothing is sent', () async {
    final api = _Api(status: 'NEEDS_CHANGES')..failServiceReads = 2;
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    final saved = await dashboard.saveJoiningService(
      title: 'تصوير كامل',
      price: '450000',
    );

    expect(saved, isFalse);
    expect(api.serviceKeys, isEmpty);
    expect(api.serviceEdits, isEmpty);
    expect(
      dashboard.errorMessage,
      'ما قدرنا نقرأ خدمتك الحين. جرّب مرة ثانية.',
    );
  });
}

Future<bool> _addService(ProviderDashboardProvider dashboard) {
  return dashboard.createService(
    title: 'زفة',
    categoryId: 'photo',
    basePrice: '300000',
    currency: 'YER',
  );
}

Future<bool> _addPackage(
  ProviderDashboardProvider dashboard, {
  required String price,
}) {
  return dashboard.createPackage(
    title: 'الباقة الفضية',
    price: price,
    currency: 'YER',
    items: const ['ألبوم'],
  );
}

class _Api extends ProviderDashboardApi {
  _Api({required this.status})
    : super(ApiClient(tokenProvider: () async => null));

  final String status;
  bool loseNextAnswer = false;
  bool refuseNext = false;
  int failServiceReads = 0;
  final serviceKeys = <String>[];
  final packageKeys = <String>[];
  final serviceEdits = <String>[];

  static const _service = MarketplaceService(
    id: 'service-1',
    providerId: 'provider-1',
    title: 'تصوير العرس',
    basePrice: '400000.00',
    currency: 'YER',
    isActive: true,
  );

  void _answerOrFail() {
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw const ApiException('timeout', isNetworkFailure: true);
    }
    if (refuseNext) {
      refuseNext = false;
      throw const ApiException('refused', statusCode: 400);
    }
  }

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'استديو الفن',
        status: status,
        ratingAverage: 0,
        ratingCount: 0,
        primaryCategoryId: 'photo',
      );

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary.empty();

  @override
  Future<List<MarketplaceService>> getServices() async {
    if (failServiceReads > 0) {
      failServiceReads--;
      throw const ApiException('offline', isNetworkFailure: true);
    }
    return const [_service];
  }

  @override
  Future<List<ProviderPackage>> getPackages() async => const [];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => const [];

  @override
  Future<List<ProviderReview>> getReviews() async => const [];

  @override
  Future<List<MarketplaceBooking>> getBookings() async => const [];

  @override
  Future<List<DateTime>> getBlockedDates() async => const [];

  @override
  Future<MarketplaceService> createService({
    required String title,
    required String categoryId,
    required String clientRequestId,
    String? description,
    String? basePrice,
    String? priceUnit,
    String? currency,
    String? cityId,
  }) async {
    serviceKeys.add(clientRequestId);
    _answerOrFail();
    return MarketplaceService(
      id: 'service-new-${serviceKeys.length}',
      providerId: 'provider-1',
      title: title,
      isActive: true,
    );
  }

  @override
  Future<ProviderPackage> createPackage({
    required String title,
    required String clientRequestId,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String> items = const [],
  }) async {
    packageKeys.add(clientRequestId);
    _answerOrFail();
    return ProviderPackage(
      id: 'package-new-${packageKeys.length}',
      providerId: 'provider-1',
      title: title,
      isActive: true,
    );
  }

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
    serviceEdits.add(serviceId);
    return _service;
  }
}
