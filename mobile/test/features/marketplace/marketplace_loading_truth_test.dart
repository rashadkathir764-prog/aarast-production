import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_portfolio.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'a failed marketplace favorites refresh keeps previously loaded favorites',
    () async {
      final api = _MarketplaceLoadingTruthApi();
      final marketplace = ProviderMarketplaceProvider(api);

      await marketplace.loadMarketplace(includeAccountData: true);
      expect(marketplace.favoriteProviderIds, {'provider-1'});

      api.favoritesError = const ApiException('تعذر الاتصال بالخادم.');
      await marketplace.loadMarketplace(includeAccountData: true);

      expect(marketplace.favoriteProviderIds, {'provider-1'});
      expect(marketplace.favoriteProviders, hasLength(1));
    },
  );

  test(
    'failed provider sections keep previous data and report the refresh failure',
    () async {
      final api = _MarketplaceLoadingTruthApi();
      final marketplace = ProviderMarketplaceProvider(api);

      await marketplace.loadProviderDetails('provider-1');
      expect(marketplace.servicesFor('provider-1'), hasLength(1));
      expect(marketplace.packagesFor('provider-1'), hasLength(1));
      expect(marketplace.reviewsFor('provider-1'), hasLength(1));

      api
        ..servicesError = const ApiException('تعذر تحميل الخدمات.')
        ..packagesError = const ApiException('تعذر تحميل الباقات.')
        ..reviewsError = const ApiException('تعذر تحميل التقييمات.');
      await marketplace.loadProviderDetails('provider-1');

      expect(marketplace.servicesFor('provider-1'), hasLength(1));
      expect(marketplace.packagesFor('provider-1'), hasLength(1));
      expect(marketplace.reviewsFor('provider-1'), hasLength(1));
      expect(marketplace.servicesErrorFor('provider-1'), 'تعذر تحميل الخدمات.');
      expect(marketplace.packagesErrorFor('provider-1'), 'تعذر تحميل الباقات.');
      expect(
        marketplace.reviewsErrorFor('provider-1'),
        'تعذر تحميل التقييمات.',
      );
      expect(marketplace.errorMessage, isNotNull);

      api
        ..servicesError = null
        ..packagesError = null
        ..reviewsError = null;
      await marketplace.loadProviderDetails('provider-1');

      expect(marketplace.servicesErrorFor('provider-1'), isNull);
      expect(marketplace.packagesErrorFor('provider-1'), isNull);
      expect(marketplace.reviewsErrorFor('provider-1'), isNull);
      expect(marketplace.errorMessage, isNull);
    },
  );

  test(
    'B-16: a signed-in reader reads the portfolio; its failure is reported '
    'and keeps the photos read before; a guest never asks',
    () async {
      final api = _MarketplaceLoadingTruthApi();
      final guest = ProviderMarketplaceProvider(api);
      await guest.loadProviderDetails('provider-1');
      expect(api.portfolioCalls, 0);
      expect(guest.portfolioFor('provider-1'), isNull);
      expect(guest.errorMessage, isNull);

      final marketplace = ProviderMarketplaceProvider(api);
      await marketplace.loadMarketplace(includeAccountData: true);
      await marketplace.loadProviderDetails('provider-1');
      expect(api.portfolioCalls, 1);
      expect(marketplace.portfolioFor('provider-1')?.items, hasLength(1));

      api.portfolioError = const ApiException('تعذر تحميل الصور.');
      await marketplace.loadProviderDetails('provider-1');
      expect(marketplace.portfolioFor('provider-1')?.items, hasLength(1));
      expect(marketplace.errorMessage, 'تعذر تحديث الصور. أعد المحاولة.');
    },
  );

  test(
    'concurrent provider detail refreshes share one in-flight request',
    () async {
      final api = _MarketplaceLoadingTruthApi();
      final marketplace = ProviderMarketplaceProvider(api);
      final providerGate = Completer<MarketplaceProvider>();
      api.providerGate = providerGate;

      final first = marketplace.loadProviderDetails('provider-1');
      final second = marketplace.loadProviderDetails('provider-1');
      await Future<void>.delayed(Duration.zero);

      expect(api.providerCalls, 1);
      expect(marketplace.isProviderQuoteContextLoading('provider-1'), isTrue);

      providerGate.complete(_provider);
      await Future.wait([first, second]);

      expect(api.providerCalls, 1);
      expect(marketplace.isProviderQuoteContextLoading('provider-1'), isFalse);
    },
  );

  testWidgets(
    'a failed provider refresh keeps stale details with an explicit disclosure',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final api = _MarketplaceLoadingTruthApi();
      final marketplace = ProviderMarketplaceProvider(api);
      await marketplace.loadProviderDetails('provider-1');
      api.providerError = const ApiException(
        'Internal server error',
        statusCode: 500,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
          child: const MaterialApp(
            home: ProviderDetailsScreen(providerId: 'provider-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قاعة الأمل'), findsOneWidget);
      // f03 discloses the old copy with the journey notice (D13).
      expect(
        find.byKey(const ValueKey('journey-list-notice-error')),
        findsOneWidget,
      );
      expect(find.textContaining('وهذي آخر نسخة'), findsOneWidget);
      expect(find.textContaining('Internal server error'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // F03: a provider that cannot be opened (unknown, or not public yet) must
  // not offer a quote request it cannot accept.
  testWidgets('a provider that fails to load offers no quote action', (
    tester,
  ) async {
    final api = _MarketplaceLoadingTruthApi()
      ..providerError = const ApiException('Not found', statusCode: 404);
    final marketplace = ProviderMarketplaceProvider(api);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
        value: marketplace,
        child: const MaterialApp(
          home: ProviderDetailsScreen(providerId: 'provider-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('journey-list-error')), findsOneWidget);
    expect(find.text('اطلب عرض سعر'), findsNothing);
    expect(api.viewedProviders, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // V1 checklist 4.18: an admin listing nobody claimed takes no quote
  // request; the page says how to reach the provider instead.
  testWidgets('an unclaimed listing offers contact instead of a quote', (
    tester,
  ) async {
    final api = _MarketplaceLoadingTruthApi()
      ..provider = MarketplaceProvider.fromJson({
        'id': 'provider-1',
        'businessName': 'قاعة الأمل',
        'isClaimed': false,
      });
    final marketplace = ProviderMarketplaceProvider(api);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
        value: marketplace,
        child: const MaterialApp(
          home: ProviderDetailsScreen(providerId: 'provider-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // w33's wording, the same as on the f02 card.
    expect(find.text('ما يستقبل طلبات لين يستلم صاحبه ملفه'), findsOneWidget);
    expect(find.text('اطلب عرض سعر'), findsNothing);
    expect(MarketplaceProvider.fromJson({'id': 'p'}).isClaimed, isTrue);
    expect(tester.takeException(), isNull);
  });

  // V1 checklist 4.19: opening a provider's page counts one view.
  testWidgets('opening a provider page counts one view for their stats', (
    tester,
  ) async {
    final api = _MarketplaceLoadingTruthApi();
    final marketplace = ProviderMarketplaceProvider(api);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
        value: marketplace,
        child: const MaterialApp(
          home: ProviderDetailsScreen(providerId: 'provider-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.viewedProviders, ['provider-1']);
    expect(tester.takeException(), isNull);
  });

  test('provider directory errors never expose backend English', () {
    expect(
      providerDirectoryErrorMessage(
        const ApiException('Internal server error', statusCode: 500),
      ),
      'تعذر تحميل بيانات دليل المزودين. حاول مرة أخرى.',
    );
    expect(
      providerDirectoryErrorMessage(
        const ApiException('Provider not found', statusCode: 404),
      ),
      'تعذر تحميل بيانات دليل المزودين. حاول مرة أخرى.',
    );
    expect(
      providerDirectoryErrorMessage(
        const ApiException('تعذر تحميل الخدمات.', statusCode: 503),
      ),
      'تعذر تحميل الخدمات.',
    );
  });

  test(
    'provider directory entry points never expose backend English',
    () async {
      final api = _MarketplaceLoadingTruthApi();
      final marketplace = ProviderMarketplaceProvider(api);
      api.providerPageError = const ApiException(
        'Database query timed out',
        statusCode: 500,
      );

      await marketplace.loadMarketplace(includeAccountData: false);

      expect(marketplace.errorMessage, providerDirectoryGenericErrorMessage);

      api
        ..providerPageError = null
        ..providerPageTotalPages = 2;
      await marketplace.loadMarketplace(includeAccountData: false);
      api.providerPageError = const ApiException(
        'Database query timed out',
        statusCode: 500,
      );

      await marketplace.loadMoreProviders();

      expect(
        marketplace.loadMoreErrorMessage,
        providerDirectoryGenericErrorMessage,
      );

      api.favoritesError = const ApiException(
        'Favorite provider lookup failed',
        statusCode: 500,
      );

      await marketplace.loadFavoriteProviders();

      expect(
        marketplace.favoriteProvidersErrorMessage,
        providerDirectoryGenericErrorMessage,
      );
    },
  );
}

class _MarketplaceLoadingTruthApi extends MarketplaceApi {
  _MarketplaceLoadingTruthApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  Object? favoritesError;
  Object? providerPageError;
  Object? providerError;
  Object? servicesError;
  Object? packagesError;
  Object? reviewsError;
  Object? portfolioError;
  int portfolioCalls = 0;
  Completer<MarketplaceProvider>? providerGate;
  int providerPageTotalPages = 1;
  int providerCalls = 0;
  final viewedProviders = <String>[];
  MarketplaceProvider provider = _provider;

  @override
  Future<void> recordProviderView(String providerId) async {
    viewedProviders.add(providerId);
  }

  @override
  Future<List<MarketplaceCity>> getCities() async => const [
    MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
  ];

  @override
  Future<List<ProviderCategory>> getCategories() async => const [
    ProviderCategory(id: 'category-1', nameAr: 'قاعات'),
  ];

  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    int page = 1,
    int limit = 30,
  }) async {
    final error = providerPageError;
    if (error != null) throw error;
    return MarketplaceProviderPage(
      items: const [],
      currentPage: page,
      total: 0,
      totalPages: providerPageTotalPages,
      hasMore: page < providerPageTotalPages,
    );
  }

  @override
  Future<List<FavoriteProvider>> getFavoriteProviders() async {
    final error = favoritesError;
    if (error != null) throw error;
    return const [
      FavoriteProvider(
        id: 'favorite-1',
        providerId: 'provider-1',
        provider: MarketplaceProvider(
          id: 'provider-1',
          businessName: 'قاعة الأمل',
          ownerName: 'مالك القاعة',
          ratingAverage: 0,
          ratingCount: 0,        ),
      ),
    ];
  }

  @override
  Future<MarketplaceProvider> getProvider(String providerId) async {
    providerCalls += 1;
    final error = providerError;
    if (error != null) throw error;
    final gate = providerGate;
    if (gate != null) return gate.future;
    return provider;
  }

  @override
  Future<List<MarketplaceService>> getProviderServices(
    String providerId,
  ) async {
    final error = servicesError;
    if (error != null) throw error;
    return const [
      MarketplaceService(
        id: 'service-1',
        providerId: 'provider-1',
        title: 'خدمة القاعة',        isActive: true,
      ),
    ];
  }

  @override
  Future<List<ProviderPackage>> getProviderPackages(String providerId) async {
    final error = packagesError;
    if (error != null) throw error;
    return const [
      ProviderPackage(
        id: 'package-1',
        providerId: 'provider-1',
        title: 'باقة القاعة',
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<ProviderReview>> getProviderReviews(String providerId) async {
    final error = reviewsError;
    if (error != null) throw error;
    return const [ProviderReview(id: 'review-1', rating: 5)];
  }

  @override
  Future<PublicPortfolio> getProviderPortfolio(String providerId) async {
    portfolioCalls += 1;
    final error = portfolioError;
    if (error != null) throw error;
    return const PublicPortfolio(
      items: [PublicPortfolioPhoto(id: 'photo-1', imageUrl: 'https://x.test/1.jpg')],
      socialLinks: {},
    );
  }
}

const _provider = MarketplaceProvider(
  id: 'provider-1',
  businessName: 'قاعة الأمل',
  ownerName: 'مالك القاعة',
  ratingAverage: 0,
  ratingCount: 0,);
