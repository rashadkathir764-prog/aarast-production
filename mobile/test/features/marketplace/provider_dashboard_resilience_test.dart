import 'package:aarast_mobile/core/forms/latin_digits_formatter.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_requests_tab.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_listing_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'non-active provider keeps profile and skips active-only endpoints',
    () async {
      final api = _ProviderDashboardApiFake(status: 'NEEDS_CHANGES');
      final dashboard = ProviderDashboardProvider(api);

      await dashboard.loadDashboard();

      expect(dashboard.hasProviderProfile, isTrue);
      expect(dashboard.profile?.businessName, 'استديو اعّرست');
      expect(dashboard.profile?.reviewNote, 'أكمل صور الهوية.');
      expect(dashboard.canUseProviderOperations, isFalse);
      expect(api.operationalCalls, 0);
      // Waiting for approval he reads the service he joined with (B-10).
      expect(api.serviceReads, 1);
      expect(dashboard.joiningService?.title, 'تنسيق كامل');
      expect(dashboard.errorMessage, isNull);
    },
  );

  test(
    'one operational failure does not erase provider profile or sections',
    () async {
      final api = _ProviderDashboardApiFake(
        status: 'ACTIVE',
        failSummary: true,
      );
      final dashboard = ProviderDashboardProvider(api);

      await dashboard.loadDashboard();

      expect(dashboard.hasProviderProfile, isTrue);
      expect(dashboard.profile?.status, 'ACTIVE');
      expect(dashboard.services.single.title, 'تنسيق كامل');
      expect(dashboard.packages.single.title, 'باقة اليوم');
      expect(dashboard.reviews.single.rating, 5);
      expect(dashboard.errorMessage, contains('الملخص'));
    },
  );

  test(
    'authorization loss clears every previously loaded operational section',
    () async {
      final api = _ProviderDashboardApiFake(status: 'ACTIVE');
      final dashboard = ProviderDashboardProvider(api);
      await dashboard.loadDashboard();
      expect(dashboard.services, isNotEmpty);

      api.denyOperationalAccess = true;
      await dashboard.loadDashboard();

      expect(dashboard.hasProviderProfile, isTrue);
      expect(dashboard.canUseProviderOperations, isFalse);
      expect(dashboard.services, isEmpty);
      expect(dashboard.packages, isEmpty);
      expect(dashboard.reviews, isEmpty);
      expect(dashboard.quoteRequests, isEmpty);
      expect(dashboard.errorMessage, contains('صلاحيتك كمزود'));

      api.denyOperationalAccess = false;
      await dashboard.loadDashboard();
      expect(dashboard.canUseProviderOperations, isTrue);
      expect(dashboard.services, isNotEmpty);
    },
  );

  test('catalog activation mutations replace the matching live item', () async {
    final api = _ProviderDashboardApiFake(status: 'ACTIVE');
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadDashboard();

    expect(
      await dashboard.setServiceActive(serviceId: 'service-1', isActive: false),
      isTrue,
    );
    expect(dashboard.services.single.isActive, isFalse);

    expect(
      await dashboard.setPackageActive(packageId: 'package-1', isActive: false),
      isTrue,
    );
    expect(dashboard.packages.single.isActive, isFalse);
  });

  test('provider offer amount validation rejects unusable amounts', () {
    expect(validateProviderOfferAmount(''), isNotNull);
    expect(validateProviderOfferAmount('0'), isNotNull);
    expect(validateProviderOfferAmount('-10'), isNotNull);
    expect(validateProviderOfferAmount('100.123'), isNotNull);
    // D112 (Q-25), the owner's word: whole riyals everywhere, a provider's
    // offer included. The server refuses a fraction now, so the field says
    // it before sending («1250.50» used to pass here).
    expect(
      validateProviderOfferAmount('1250.50'),
      'السعر رقم صحيح، بدون كسور.',
    );
    expect(validateProviderOfferAmount('1250'), isNull);
    expect(validateProviderOfferAmount('1,250,000'), isNull);
  });

  test('Q-25: a listing price is whole, or empty', () {
    expect(providerListingPriceError(''), isNull);
    expect(providerListingPriceError('400,000'), isNull);
    expect(
      providerListingPriceError('400000.5'),
      'المبلغ رقم صحيح، بدون كسور.',
    );
    expect(providerListingPriceError('12,5x'), 'اكتب المبلغ أرقام بس.');
  });

  // RA-MO-301 (batch 9): a price typed on an Arabic keyboard was refused.
  test('a price in Arabic keyboard digits is the same amount', () {
    expect(providerListingPriceError('٤٠٠٠٠٠'), isNull);
    expect(providerListingPriceError('٤٠٠٬٠٠٠'), isNull);
    expect(typedAmount(' ٤٠٠٬٠٠٠ '), '400000');
    expect(typedAmount('400,000'), '400000');
    // A mistake is still named, not hidden.
    expect(providerListingPriceError('٤٠٠x'), 'اكتب المبلغ أرقام بس.');
  });
}

class _ProviderDashboardApiFake extends ProviderDashboardApi {
  _ProviderDashboardApiFake({required this.status, this.failSummary = false})
    : super(ApiClient(tokenProvider: () async => null));

  String status;
  final bool failSummary;
  bool denyOperationalAccess = false;
  int operationalCalls = 0;

  @override
  Future<ProviderDashboardProfile> getProfile() async {
    return ProviderDashboardProfile(
      id: 'provider-1',
      businessName: 'استديو اعّرست',
      status: status,
      ratingAverage: 5,
      ratingCount: 1,
      reviewNote: status == 'NEEDS_CHANGES' ? 'أكمل صور الهوية.' : null,
    );
  }

  @override
  Future<ProviderDashboardSummary> getSummary() async {
    operationalCalls++;
    if (denyOperationalAccess) {
      throw const ApiException(
        'Provider operations are unavailable',
        statusCode: 403,
      );
    }
    if (failSummary) throw const ApiException('summary unavailable');
    return const ProviderDashboardSummary(
      servicesCount: 1,
      activeServicesCount: 1,
      quoteRequestsCount: 0,
      newQuoteRequestsCount: 0,
      averageRating: 5,
      ratingCount: 1,
    );
  }

  /// Reads of his services: before approval only the one he joined with
  /// (B-10), which is not an operational read.
  int serviceReads = 0;

  @override
  Future<List<MarketplaceService>> getServices() async {
    serviceReads++;
    if (status == 'ACTIVE') operationalCalls++;
    return [_service()];
  }

  @override
  Future<List<ProviderPackage>> getPackages() async {
    operationalCalls++;
    return [_package()];
  }

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async {
    operationalCalls++;
    return const [];
  }

  @override
  Future<List<ProviderReview>> getReviews() async {
    operationalCalls++;
    return const [ProviderReview(id: 'review-1', rating: 5)];
  }

  @override
  Future<List<MarketplaceBooking>> getBookings() async {
    operationalCalls++;
    return const [];
  }

  @override
  Future<List<DateTime>> getBlockedDates() async {
    operationalCalls++;
    return const [];
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
    return _service(isActive: isActive ?? true);
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
    return _package(isActive: isActive ?? true);
  }

  MarketplaceService _service({bool isActive = true}) {
    return MarketplaceService(
      id: 'service-1',
      providerId: 'provider-1',
      title: 'تنسيق كامل',
      isActive: isActive,
    );
  }

  ProviderPackage _package({bool isActive = true}) {
    return ProviderPackage(
      id: 'package-1',
      providerId: 'provider-1',
      title: 'باقة اليوم',
      isActive: isActive,
    );
  }
}
