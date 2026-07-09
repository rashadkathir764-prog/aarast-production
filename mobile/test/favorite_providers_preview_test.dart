// Visual preview for the saved-providers (المفضلة) screen after adopting the
// shared image-forward PremiumVendorCard — so the favorites tab matches the
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
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
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

class _PreviewMarketplaceProvider extends ProviderMarketplaceProvider {
  _PreviewMarketplaceProvider()
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  bool get isLoading => false;

  @override
  bool get isSubmitting => false;

  @override
  String? get errorMessage => null;

  @override
  Set<String> get favoriteProviderIds => const {'fav-1', 'fav-2'};

  @override
  List<FavoriteProvider> get favoriteProviders => [
    FavoriteProvider(id: 'f1', providerId: 'fav-1', provider: _venue()),
    FavoriteProvider(id: 'f2', providerId: 'fav-2', provider: _photographer()),
  ];

  @override
  Future<void> loadFavoriteProviders() async {}

  @override
  Future<void> toggleFavorite(String providerId) async {}
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('favorites — shared vendor cards (430)', (tester) async {
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

    tester.view.physicalSize = const Size(430, 1040);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
            value: _PreviewMarketplaceProvider(),
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

    await expectLater(
      find.byType(FavoriteProvidersScreen),
      matchesGoldenFile('goldens/favorite_providers.png'),
    );
  });
}
