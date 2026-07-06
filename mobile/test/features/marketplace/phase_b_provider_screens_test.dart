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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase B provider screens premium contract', () {
    test('provider user screens use Lucide and Arabic currency helpers', () {
      for (final path in _phaseBScreenPaths) {
        final source = _readSource(path);

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
      final favoritesSource = _readSource(
        'lib/features/marketplace/screens/favorite_providers_screen.dart',
      );

      expect(quoteSource, contains('_QuoteRequestHero'));
      expect(detailsSource, contains('_ProviderHeroPill'));
      expect(favoritesSource, contains('_FavoriteProvidersHero'));
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
      expect(find.text('1,200 ر.س'), findsOneWidget);
      expect(find.text('3,500 ر.ي'), findsOneWidget);
      expect(find.textContaining('YER'), findsNothing);
      expect(find.text('مرجع تخطيطي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

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
        find.textContaining('لا يتم إنشاء حجز أو مصروف تلقائياً'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
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

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider()
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get isSubmitting => false;

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
  List<QuoteRequest> quotesForProvider(String providerId) => const [];

  @override
  Future<void> loadProviderDetails(String providerId) async {}

  @override
  Future<void> loadFavoriteProviders() async {}

  @override
  Future<void> toggleFavorite(String providerId) async {}
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
