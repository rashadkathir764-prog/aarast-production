import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/favorite_providers_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase B provider screens premium contract', () {
    test('provider user screens use Lucide and Arabic currency helpers', () {
      for (final path in _phaseBScreenPaths) {
        final source = _phaseBSource(path);

        expect(source, contains('LucideIcons.'), reason: path);
        expect(source, contains('currencyLabelAr'), reason: path);
        expect(_materialIconLines(source), isEmpty, reason: path);
        expect(source, isNot(contains('AarastComingSoonScreen')), reason: path);
        expect(source, isNot(contains('PLANNING')), reason: path);
        expect(source, isNot(contains("'YER'")), reason: path);
        expect(source, isNot(contains('currency ??')), reason: path);
      }
    });

    test('provider details and favorites expose premium heroes', () {
      final quoteSource = _readSource(
        'lib/features/marketplace/screens/quote_request_screen.dart',
      );
      final detailsSource = _readSource(
        'lib/features/marketplace/screens/provider_details_screen.dart',
      );
      final detailsViewSource = _readSource(
        'lib/features/marketplace/widgets/provider_details_view.dart',
      );
      final favoritesSource = _readSource(
        'lib/features/marketplace/screens/favorite_providers_screen.dart',
      );

      expect(quoteSource, contains('_QuoteRequestHero'));
      expect(detailsSource, contains('ProviderDetailsView'));
      expect(detailsViewSource, contains('class _ProviderHero'));
      expect(favoritesSource, contains('_FavoriteProvidersHero'));
    });

    test('plan providers route forwards a quote deep-link context', () {
      final routerSource = _readSource('lib/core/routing/app_router.dart');
      final routeStart = routerSource.indexOf(
        "path: '/wedding-plans/:id/providers'",
      );
      expect(routeStart, greaterThanOrEqualTo(0));
      final routeEnd = routerSource.indexOf('),', routeStart);
      final routeSource = routerSource.substring(routeStart, routeEnd);

      expect(
        routeSource,
        contains("initialQuoteId: state.uri.queryParameters['quoteId']"),
      );
    });
  });

  group('Phase B provider screens rendering', () {
    testWidgets('provider details show Arabic currency labels', (tester) async {
      _setTallView(tester);
      final marketplace = _FakeMarketplaceProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
          child: const MaterialApp(
            home: ProviderDetailsScreen(providerId: _providerId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قاعة السلام'), findsOneWidget);
      // Price now appears both in the headline price block and the service tile.
      expect(find.text('1,200 ر.س'), findsWidgets);
      expect(find.text('3,500 ر.ي'), findsOneWidget);
      expect(find.textContaining('YER'), findsNothing);
      expect(find.text('مرجع تخطيطي'), findsOneWidget);
      expect(
        find.byKey(const Key('provider-details-conversation')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('provider details stay safe at 320px RTL and 1.3 scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      final marketplace = _FakeMarketplaceProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const ProviderDetailsScreen(providerId: _providerId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('provider-media-fallback')), findsOneWidget);
      expect(find.text('طلب عرض سعر'), findsOneWidget);
      expect(find.textContaining('YER'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('provider details CTA follows the latest quote lifecycle', (
      tester,
    ) async {
      _setTallView(tester);
      final cases = <QuoteRequest?, String>{
        null: 'طلب عرض سعر',
        _quote(status: 'SENT'): 'متابعة الطلب الحالي',
        _quote(
          status: 'RESPONDED',
          offers: const [QuoteOffer(id: 'offer-live', status: 'PENDING')],
        ): 'مراجعة العرض',
        _quote(
          status: 'RESPONDED',
          offers: const [
            QuoteOffer(
              id: 'offer-expired',
              status: 'PENDING',
              serverIsExpired: true,
            ),
          ],
        ): 'طلب عرض جديد',
        _quote(status: 'ACCEPTED'): 'عرض المورد في الخطة',
        _quote(status: 'CANCELLED'): 'طلب عرض جديد',
      };

      for (final entry in cases.entries) {
        final marketplace = _FakeMarketplaceProvider(
          quotes: entry.key == null ? const [] : [entry.key!],
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
            value: marketplace,
            child: const MaterialApp(
              home: ProviderDetailsScreen(
                providerId: _providerId,
                weddingPlanId: 'plan-1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      }
    });

    testWidgets('provider details conversation action routes with quote id', (
      tester,
    ) async {
      _setTallView(tester);
      final quote = _quote(status: 'SENT');
      final marketplace = _FakeMarketplaceProvider(quotes: [quote]);
      final router = GoRouter(
        initialLocation: '/providers/$_providerId',
        routes: [
          GoRoute(
            path: '/providers/:id',
            builder: (_, _) => const ProviderDetailsScreen(
              providerId: _providerId,
              weddingPlanId: 'plan-1',
            ),
          ),
          GoRoute(
            path: '/quotes/:id/conversation',
            builder: (_, state) => Scaffold(
              body: Text('quote-chat-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: marketplace,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('provider-details-conversation')));
      await tester.pumpAndSettle();

      expect(find.text('quote-chat-${quote.id}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'provider details review action opens the offer in its plan context',
      (tester) async {
        _setTallView(tester);
        final quote = _quote(
          status: 'RESPONDED',
          offers: const [QuoteOffer(id: 'offer-live', status: 'PENDING')],
        );
        final marketplace = _FakeMarketplaceProvider(quotes: [quote]);
        final router = GoRouter(
          initialLocation: '/providers/$_providerId?weddingPlanId=plan-1',
          routes: [
            GoRoute(
              path: '/providers/:id',
              builder: (_, state) => ProviderDetailsScreen(
                providerId: _providerId,
                weddingPlanId: state.uri.queryParameters['weddingPlanId'],
              ),
            ),
            GoRoute(
              path: '/wedding-plans/:id/providers',
              builder: (_, state) => Scaffold(
                body: Text(
                  'offer-route:${state.pathParameters['id']}:'
                  '${state.uri.queryParameters['quoteId']}',
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
            value: marketplace,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('مراجعة العرض'));
        await tester.pumpAndSettle();

        expect(find.text('offer-route:plan-1:${quote.id}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('favorite providers keep comparison copy and currency labels', (
      tester,
    ) async {
      _setTallView(tester);
      final authStorage = await _authenticatedStorage();
      final marketplace = _FakeMarketplaceProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
              value: marketplace,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const FavoriteProvidersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 مورد محفوظ للمقارنة'), findsOneWidget);
      expect(find.text('1,200 ر.س'), findsOneWidget);
      expect(find.textContaining('YER'), findsNothing);
      expect(
        find.textContaining('عند قبول العرض تُنشأ التكلفة تلقائياً'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'favorite provider remove action is disabled while submitting',
      (tester) async {
        _setTallView(tester);
        final authStorage = await _authenticatedStorage();
        final marketplace = _FakeMarketplaceProvider(isSubmitting: true);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AuthStorage>.value(value: authStorage),
              ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
                value: marketplace,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const FavoriteProvidersScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('favorite-provider-remove-provider-1')),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(marketplace.toggleFavoriteCallCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

const _providerId = 'provider-1';
const _phaseBScreenPaths = [
  'lib/features/marketplace/screens/quote_request_screen.dart',
  'lib/features/marketplace/screens/provider_details_screen.dart',
  'lib/features/marketplace/screens/favorite_providers_screen.dart',
];

Future<AuthStorage> _authenticatedStorage() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  await storage.saveSession(
    accessToken: 'phase-b-token',
    user: const SafeUser(
      id: 'user-1',
      name: 'رشاد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );
  return storage;
}

MarketplaceProvider _provider() {
  return const MarketplaceProvider(
    id: _providerId,
    businessName: 'قاعة السلام',
    ownerName: 'مالك القاعة',
    ratingAverage: 4.7,
    ratingCount: 12,
    isFeatured: true,
    city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
    description: 'قاعة مناسبة للمناسبات العائلية.',
    services: [
      MarketplaceService(
        id: 'service-1',
        providerId: _providerId,
        title: 'تنسيق قاعة',
        isFeatured: false,
        isActive: true,
        basePrice: '1200',
        currency: 'SAR',
        category: ProviderCategory(id: 'cat-1', nameAr: 'القاعات'),
      ),
    ],
  );
}

ProviderPackage _package() {
  return const ProviderPackage(
    id: 'package-1',
    providerId: _providerId,
    title: 'باقة استقبال',
    isActive: true,
    price: '3500',
    currency: 'YER',
  );
}

QuoteRequest _quote({
  required String status,
  List<QuoteOffer> offers = const [],
}) => QuoteRequest(
  id: 'quote-$status-${offers.length}',
  providerId: _providerId,
  weddingPlanId: 'plan-1',
  status: status,
  lifecycleStatus: switch (status) {
    'SENT' || 'VIEWED' => 'PENDING_PROVIDER',
    'RESPONDED' => 'RECEIVED',
    _ => status,
  },
  offers: offers,
  createdAt: DateTime(2026, 7, 22),
);

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({
    bool isSubmitting = false,
    List<QuoteRequest> quotes = const [],
  }) : _quotes = quotes,
       _isSubmitting = isSubmitting,
       super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final bool _isSubmitting;
  final List<QuoteRequest> _quotes;
  int toggleFavoriteCallCount = 0;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get isSubmitting => _isSubmitting;

  @override
  Set<String> get favoriteProviderIds => const {_providerId};

  @override
  List<FavoriteProvider> get favoriteProviders => [
    FavoriteProvider(
      id: 'favorite-1',
      providerId: _providerId,
      provider: _provider(),
    ),
  ];

  @override
  MarketplaceProvider? providerDetails(String id) =>
      id == _providerId ? _provider() : null;

  @override
  List<MarketplaceService> servicesFor(String id) =>
      id == _providerId ? _provider().services : const [];

  @override
  List<ProviderPackage> packagesFor(String id) =>
      id == _providerId ? [_package()] : const [];

  @override
  List<ProviderReview> reviewsFor(String id) => const [];

  @override
  List<QuoteRequest> quotesForProvider(String providerId) => _quotes;

  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {}

  @override
  Future<void> loadFavoriteProviders() async {}

  @override
  Future<void> toggleFavorite(String providerId) async {
    toggleFavoriteCallCount += 1;
  }
}

List<String> _materialIconLines(String source) {
  return source
      .split('\n')
      .where(
        (line) => line.contains('Icons.') && !line.contains('LucideIcons.'),
      )
      .toList();
}

String _readSource(String relativePath) {
  return File('${_findMobileRoot()}$relativePath').readAsStringSync();
}

String _phaseBSource(String relativePath) {
  if (relativePath !=
      'lib/features/marketplace/screens/provider_details_screen.dart') {
    return _readSource(relativePath);
  }
  return [
    _readSource(relativePath),
    _readSource('lib/features/marketplace/widgets/provider_details_view.dart'),
    _readSource(
      'lib/features/marketplace/widgets/provider_details_sections.dart',
    ),
  ].join('\n');
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1800);
  addTearDown(tester.view.reset);
}

String _findMobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
