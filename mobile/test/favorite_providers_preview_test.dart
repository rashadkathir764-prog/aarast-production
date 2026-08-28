// Visual preview for the saved-providers (المفضلة) screen after adopting the
// shared image-forward ProviderResultCard — so the favorites tab matches the
// vendors tab exactly. The heart here removes from favorites; the button opens
// details. Cover images fall back to placeholders in the golden harness.
//
// Regenerate with:
//   flutter test test/favorite_providers_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/favorite_providers_screen.dart';

import 'support/preview_fonts.dart';

MarketplaceProvider _venue() {
  return const MarketplaceProvider(
    id: 'fav-1',
    businessName: 'قصر الماسة للاحتفالات',
    ownerName: 'إدارة القصر',
    ratingAverage: 4.8,
    ratingCount: 125,
    isFeatured: true,
    city: MarketplaceCity(id: 'city-jed', nameAr: 'جدة'),
    services: [
      MarketplaceService(
        id: 's1',
        providerId: 'fav-1',
        title: 'قاعة كبرى',
        isFeatured: true,
        isActive: true,
        category: ProviderCategory(id: 'c1', nameAr: 'صالات'),
        basePrice: '15000',
        currency: 'SAR',
      ),
      MarketplaceService(
        id: 's2',
        providerId: 'fav-1',
        title: 'قاعة كبار',
        isFeatured: false,
        isActive: true,
        category: ProviderCategory(id: 'c1', nameAr: 'صالات'),
        basePrice: '35000',
        currency: 'SAR',
      ),
    ],
  );
}

MarketplaceProvider _photographer() {
  return const MarketplaceProvider(
    id: 'fav-2',
    businessName: 'عدسة الريم للتصوير',
    ownerName: 'ريم',
    ratingAverage: 4.7,
    ratingCount: 76,
    isFeatured: false,
    city: MarketplaceCity(id: 'city-ryd', nameAr: 'الرياض'),
    services: [
      MarketplaceService(
        id: 's3',
        providerId: 'fav-2',
        title: 'باقة تصوير كاملة',
        isFeatured: false,
        isActive: true,
        category: ProviderCategory(id: 'c2', nameAr: 'تصوير'),
        basePrice: '6000',
        currency: 'SAR',
      ),
    ],
  );
}

List<FavoriteProvider> _favorites(List<MarketplaceProvider> providers) =>
    List<FavoriteProvider>.generate(
      providers.length,
      (index) => FavoriteProvider(
        id: 'favorite-${index + 1}',
        providerId: providers[index].id,
        provider: providers[index],
      ),
    );

class _PreviewMarketplaceProvider extends ProviderMarketplaceProvider {
  _PreviewMarketplaceProvider({required this.favoriteProvidersData})
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  final List<FavoriteProvider> favoriteProvidersData;

  @override
  bool get isLoading => false;

  @override
  bool get isSubmitting => false;

  @override
  String? get errorMessage => null;

  @override
  Set<String> get favoriteProviderIds =>
      favoriteProvidersData.map((favorite) => favorite.providerId).toSet();

  @override
  List<FavoriteProvider> get favoriteProviders => favoriteProvidersData;

  @override
  Future<void> loadFavoriteProviders() async {}

  @override
  Future<void> toggleFavorite(String providerId) async {}
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('favorites — shared vendor cards (430)', (tester) async {
    await _pumpFavorites(
      tester,
      size: const Size(430, 1040),
      favorites: _favorites([_venue(), _photographer()]),
    );

    await expectLater(
      find.byType(FavoriteProvidersScreen),
      matchesGoldenFile('goldens/favorite_providers.png'),
    );
  });

  testWidgets('favorites empty state stays RTL-safe at 320 and 1.3 text', (
    tester,
  ) async {
    await _pumpFavorites(
      tester,
      size: const Size(320, 760),
      textScale: 1.3,
      favorites: const [],
    );

    expect(find.text('لا توجد مفضلة بعد'), findsOneWidget);
    expect(find.text('تصفح الموردين'), findsOneWidget);
    _expectRtlAndInsideView(tester, find.text('تصفح الموردين'), width: 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one favorite keeps its name and actions visible at 320', (
    tester,
  ) async {
    await _pumpFavorites(
      tester,
      size: const Size(320, 900),
      textScale: 1.3,
      favorites: _favorites([_venue()]),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('favorite-provider-remove-fav-1')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('قصر الماسة للاحتفالات'), findsOneWidget);
    expect(find.text('عرض التفاصيل'), findsOneWidget);
    _expectRtlAndInsideView(
      tester,
      find.byKey(const Key('favorite-provider-remove-fav-1')),
      width: 320,
    );
    _expectInsideView(tester, find.text('عرض التفاصيل'), width: 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple favorites remain usable at 320 and 1.3 text', (
    tester,
  ) async {
    await _pumpFavorites(
      tester,
      size: const Size(320, 900),
      textScale: 1.3,
      favorites: _favorites([_venue(), _photographer()]),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('favorite-provider-remove-fav-2')),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('قصر الماسة للاحتفالات'), findsOneWidget);
    expect(find.text('عدسة الريم للتصوير'), findsOneWidget);
    expect(find.text('عرض التفاصيل'), findsNWidgets(2));
    _expectRtlAndInsideView(
      tester,
      find.byKey(const Key('favorite-provider-remove-fav-2')),
      width: 320,
    );
    _expectInsideView(tester, find.text('عرض التفاصيل').last, width: 320);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFavorites(
  WidgetTester tester, {
  required Size size,
  required List<FavoriteProvider> favorites,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(prefs);
  await authStorage.saveSession(
    accessToken: 'preview-token',
    user: const SafeUser(
      id: 'user-1',
      name: 'رشاد',
      role: 'CUSTOMER',
      status: 'ACTIVE',
    ),
  );

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: _PreviewMarketplaceProvider(favoriteProvidersData: favorites),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const FavoriteProvidersScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

void _expectRtlAndInsideView(
  WidgetTester tester,
  Finder finder, {
  required double width,
}) {
  expect(
    Directionality.of(tester.element(find.byType(ListView).first)),
    TextDirection.rtl,
  );
  expect(
    MediaQuery.textScalerOf(
      tester.element(find.byType(ListView).first),
    ).scale(10),
    13,
  );
  _expectInsideView(tester, finder, width: width);
}

void _expectInsideView(
  WidgetTester tester,
  Finder finder, {
  required double width,
}) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(width));
  expect(rect.width, greaterThan(0));
  expect(rect.height, greaterThan(0));
}
