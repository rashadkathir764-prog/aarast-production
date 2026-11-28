import 'dart:async';

import 'package:aarast_mobile/core/l10n/aarast_text.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_portfolio.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../../support/app_text_scale.dart';

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
      // RA-MO-254 (2026-11-13): reported on the provider's page; the shared
      // error showed on the quote form and the directory.
      expect(marketplace.detailSectionsErrorFor('provider-1'), isNotNull);
      expect(marketplace.errorMessage, isNull);

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

  test('B-16: a signed-in reader reads the portfolio; its failure is reported '
      'and keeps the photos read before; a guest never asks', () async {
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
    // RA-MO-254 (2026-11-13): reported on the provider's page, not as the
    // shared error the quote form and the directory showed.
    expect(
      marketplace.detailSectionsErrorFor('provider-1'),
      'ما قدرنا نحدّث الصور. جرّب مرة ثانية.',
    );
    expect(marketplace.errorMessage, isNull);
  });

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
      tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
        1.3,
      ).scale(1);
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

      expect(find.textContaining('قاعة الأمل'), findsWidgets);
      // f03 discloses the old copy (D13). Changed on purpose (2026-11-26):
      // a plain line in the page's MSA, with its retry.
      expect(
        find.byKey(const ValueKey('provider-details-stale')),
        findsOneWidget,
      );
      expect(find.text(aarastText.providersDetailsStale), findsOneWidget);
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
      ..providerError = const ApiException(
        'ما فيه نت',
        isNetworkFailure: true,
      );
    final marketplace = ProviderMarketplaceProvider(api);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
        value: marketplace,
        child: const MaterialApp(
          home: ProviderDetailsScreen(providerId: 'provider-1'),
        ),
      ),
    );
    // The read starts after the first frame: until it answers the page is
    // loading. It said «لم نجد هذا المزوّد» for that frame, on every open.
    expect(find.text(aarastText.providersDetailsMissingTitle), findsNothing);
    await tester.pumpAndSettle();

    // 2026-11-26: the page's own error state, in MSA.
    expect(
      find.byKey(const ValueKey('provider-details-error')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('provider-details-quote')), findsNothing);
    expect(api.viewedProviders, isEmpty);
    expect(tester.takeException(), isNull);
  });

  // A listing taken down: the server answers 404. The page read «لم تصل
  // صفحة المزوّد، تحقّق من الاتصال» with a retry that could never work.
  testWidgets('a provider the server does not have is said to be missing', (
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

    expect(find.text(aarastText.providersDetailsMissingTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('provider-details-error')), findsNothing);
    expect(find.byKey(const Key('provider-details-quote')), findsNothing);
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

    // w33. Changed on purpose (2026-11-26, REFINEMENT_SPEC 2.7): the footer
    // offers «اتصل» and «واتساب» with why, no quote request.
    expect(
      find.text(aarastText.providersUnclaimedFooter('male')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('provider-details-call')), findsOneWidget);
    expect(find.byKey(const Key('provider-details-quote')), findsNothing);
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
      'ما قدرنا نجيب المزودين الحين. جرّب مرة ثانية.',
    );
    expect(
      providerDirectoryErrorMessage(
        const ApiException('Provider not found', statusCode: 404),
      ),
      'ما قدرنا نجيب المزودين الحين. جرّب مرة ثانية.',
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
    DateTime? eventDate,
    ProviderSort? sort,
    bool hideBusy = false,
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
          ratingCount: 0,
        ),
      ),
    ];
  }

  @override
  Future<MarketplaceProvider> getProvider(
    String providerId, {
    DateTime? eventDate,
  }) async {
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
        title: 'خدمة القاعة',
        isActive: true,
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

  // Changed on purpose (2026-11-26): the provider's page reads its reviews a
  // page at a time with their summary; a failure is the same failure.
  @override
  Future<ProviderReviewsPage> getProviderReviewsPage(
    String providerId, {
    int page = 1,
    int limit = 10,
  }) async {
    final reviews = await getProviderReviews(providerId);
    return ProviderReviewsPage(
      items: reviews,
      currentPage: 1,
      total: reviews.length,
      totalPages: 1,
      summary: ProviderReviewSummary(
        count: reviews.length,
        average: 5,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: reviews.length},
      ),
    );
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
      items: [
        PublicPortfolioPhoto(id: 'photo-1', imageUrl: 'https://x.test/1.jpg'),
      ],
      socialLinks: {},
    );
  }
}

const _provider = MarketplaceProvider(
  id: 'provider-1',
  businessName: 'قاعة الأمل',
  ownerName: 'مالك القاعة',
  ratingAverage: 0,
  ratingCount: 0,
);
