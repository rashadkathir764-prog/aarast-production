// Full-screen visual preview for the approved editorial provider details:
// real-media hero, overlapping detail sheet, price band, photo collage, flat
// sections, and the pinned quote CTA. The golden deliberately renders the
// honest no-photo fallback; real provider media renders on device.
//
// Regenerate with:
//   flutter test test/provider_details_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/provider_details_screen.dart';

import 'support/preview_fonts.dart';

const _providerId = 'provider-preview';

MarketplaceProvider _provider() {
  return MarketplaceProvider(
    id: _providerId,
    businessName: 'قصر الماسة للاحتفالات',
    ownerName: 'إدارة القصر',
    ratingAverage: 4.8,
    ratingCount: 125,
    isFeatured: true,
    city: const MarketplaceCity(id: 'city-jed', nameAr: 'جدة'),
    address: 'حي الروضة',
    phone: '0555123456',
    description:
        'قاعة فاخرة بتصميم عصري ومساحات واسعة تناسب جميع أفراحكم. فريق '
        'متخصص لخدمتكم بأعلى المعايير، مع تنسيق كامل للإضاءة والضيافة '
        'وخدمة تصوير احترافية طوال الحفل.',
    services: const [
      MarketplaceService(
        id: 'svc-1',
        providerId: _providerId,
        title: 'الباقة الماسية للقاعة الكبرى',
        isFeatured: true,
        isActive: true,
        category: ProviderCategory(id: 'cat-venue', nameAr: 'صالات'),
        basePrice: '35000',
        currency: 'SAR',
      ),
      MarketplaceService(
        id: 'svc-2',
        providerId: _providerId,
        title: 'الباقة الفضية للمناسبات الصغيرة',
        isFeatured: false,
        isActive: true,
        category: ProviderCategory(id: 'cat-venue', nameAr: 'صالات'),
        basePrice: '15000',
        currency: 'SAR',
      ),
    ],
  );
}

List<MarketplaceService> _services() {
  return [
    _provider().services.first.copyWith(
      images: const [
        ProviderServiceImage(id: 'i1', imageUrl: 'https://example.com/1.jpg'),
        ProviderServiceImage(id: 'i2', imageUrl: 'https://example.com/2.jpg'),
        ProviderServiceImage(id: 'i3', imageUrl: 'https://example.com/3.jpg'),
        ProviderServiceImage(id: 'i4', imageUrl: 'https://example.com/4.jpg'),
        ProviderServiceImage(id: 'i5', imageUrl: 'https://example.com/5.jpg'),
        ProviderServiceImage(id: 'i6', imageUrl: 'https://example.com/6.jpg'),
        ProviderServiceImage(id: 'i7', imageUrl: 'https://example.com/7.jpg'),
        ProviderServiceImage(id: 'i8', imageUrl: 'https://example.com/8.jpg'),
        ProviderServiceImage(id: 'i9', imageUrl: 'https://example.com/9.jpg'),
        ProviderServiceImage(id: 'i10', imageUrl: 'https://example.com/10.jpg'),
      ],
    ),
    _provider().services[1],
  ];
}

const _packages = [
  ProviderPackage(
    id: 'pkg-1',
    providerId: _providerId,
    title: 'الباقة الماسية',
    isActive: true,
    serviceTitle: 'القاعة الكبرى',
    price: '35000',
    currency: 'SAR',
    description: 'باقة متكاملة للأفراح الكبرى مع كل الخدمات الأساسية.',
    items: 'قاعة كبار\nأنسز\nغرفة عروس\nخدمة صف سيارات\nضيافة فاخرة',
  ),
];

const _reviews = [
  ProviderReview(
    id: 'r1',
    rating: 5,
    userName: 'أم فيصل',
    comment: 'قاعة راقية وخدمة ممتازة، التنظيم كان أكثر من رائع.',
  ),
  ProviderReview(
    id: 'r2',
    rating: 4,
    userName: 'عبدالله',
    comment: 'المكان جميل والأسعار مناسبة مقارنة بالجودة.',
  ),
];

class _PreviewMarketplaceProvider extends ProviderMarketplaceProvider {
  _PreviewMarketplaceProvider()
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Set<String> get favoriteProviderIds => const {};

  @override
  MarketplaceProvider? providerDetails(String id) => _provider();

  @override
  List<MarketplaceService> servicesFor(String id) => _services();

  @override
  List<ProviderPackage> packagesFor(String id) => _packages;

  @override
  List<ProviderReview> reviewsFor(String id) => _reviews;

  @override
  List<QuoteRequest> quotesForProvider(String providerId) => const [];

  @override
  Future<void> loadProviderDetails(
    String providerId, {
    String? weddingPlanId,
  }) async {}

  @override
  Future<void> toggleFavorite(String providerId) async {}
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('provider details — hero + price + gallery + packages (430)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1580);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
        value: _PreviewMarketplaceProvider(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ProviderDetailsScreen(providerId: _providerId),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('طلب عرض سعر'), findsOneWidget);
    expect(find.byIcon(LucideIcons.filePlus2), findsOneWidget);

    await expectLater(
      find.byType(ProviderDetailsScreen),
      matchesGoldenFile('goldens/provider_details.png'),
    );
  });
}
