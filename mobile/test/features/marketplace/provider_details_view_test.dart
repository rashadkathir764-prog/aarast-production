import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('provider details view delegates every product action', (
    tester,
  ) async {
    var backCalls = 0;
    var shareCalls = 0;
    var favoriteCalls = 0;
    MarketplaceService? requestedService;

    await _pumpView(
      tester,
      services: const [_service],
      packages: const [_package],
      reviews: const [_review],
      onBack: () => backCalls++,
      onShare: () => shareCalls++,
      onFavorite: () => favoriteCalls++,
      onRequestQuote: (service) => requestedService = service,
    );

    await tester.tap(find.byTooltip('رجوع'));
    await tester.tap(find.byTooltip('مشاركة'));
    await tester.tap(find.byTooltip('حفظ المورد'));
    await tester.pump();

    final quoteAction = find.byTooltip('طلب عرض لهذه الخدمة');
    await tester.ensureVisible(quoteAction);
    await tester.pumpAndSettle();
    await tester.tap(quoteAction);
    await tester.pump();

    expect(backCalls, 1);
    expect(shareCalls, 1);
    expect(favoriteCalls, 1);
    expect(requestedService?.id, _service.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider details empty sections stay truthful at 320px RTL', (
    tester,
  ) async {
    await _pumpView(tester, width: 320, height: 900, textScale: 1.3);

    expect(find.text('لا توجد خدمات منشورة'), findsOneWidget);
    expect(find.text('لا توجد باقات منشورة حاليًا.'), findsOneWidget);
    expect(find.byKey(const Key('provider-media-fallback')), findsOneWidget);
    expect(find.textContaining('لا توجد صور منشورة'), findsOneWidget);
    final reviewsEmpty = find.text('لا توجد تقييمات بعد.');
    await tester.scrollUntilVisible(
      reviewsEmpty,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(reviewsEmpty, findsOneWidget);
    expect(find.textContaining('YER'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('show all opens the complete swipeable provider gallery', (
    tester,
  ) async {
    final galleryService = _service.copyWith(
      images: const [
        ProviderServiceImage(id: 'image-1', imageUrl: 'https://img.test/1.jpg'),
        ProviderServiceImage(id: 'image-2', imageUrl: 'https://img.test/2.jpg'),
        ProviderServiceImage(id: 'image-3', imageUrl: 'https://img.test/3.jpg'),
        ProviderServiceImage(id: 'image-4', imageUrl: 'https://img.test/4.jpg'),
        ProviderServiceImage(id: 'image-5', imageUrl: 'https://img.test/5.jpg'),
        ProviderServiceImage(id: 'image-6', imageUrl: 'https://img.test/6.jpg'),
      ],
    );

    await _pumpView(
      tester,
      services: [galleryService],
      width: 320,
      height: 1200,
      textScale: 1.3,
    );

    final showAll = find.text('عرض الكل');
    await tester.ensureVisible(showAll);
    await tester.tap(showAll);
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.byTooltip('إغلاق معرض الصور'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a cover-only provider exposes the same single photo in gallery',
    (tester) async {
      await _pumpView(
        tester,
        provider: _providerWithCover,
        width: 320,
        height: 1000,
        textScale: 1.3,
      );

      expect(find.textContaining('معرض الصور 1'), findsOneWidget);
      expect(find.text('معرض الصور'), findsOneWidget);
      expect(find.text('عرض الكل'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpView(
  WidgetTester tester, {
  MarketplaceProvider provider = _provider,
  List<MarketplaceService> services = const [],
  List<ProviderPackage> packages = const [],
  List<ProviderReview> reviews = const [],
  VoidCallback? onBack,
  VoidCallback? onShare,
  VoidCallback? onFavorite,
  ValueChanged<MarketplaceService>? onRequestQuote,
  double width = 390,
  double height = 1400,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ProviderDetailsView(
            provider: provider,
            services: services,
            packages: packages,
            reviews: reviews,
            isFavorite: false,
            onBack: onBack ?? () {},
            onShare: onShare ?? () {},
            onFavorite: onFavorite ?? () {},
            onRequestQuote: onRequestQuote ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _provider = MarketplaceProvider(
  id: 'provider-1',
  businessName: 'قاعة السلام',
  ownerName: 'مالك القاعة',
  ratingAverage: 4.7,
  ratingCount: 12,
  isFeatured: true,
  city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
  description: 'قاعة مناسبة للمناسبات العائلية.',
);

const _providerWithCover = MarketplaceProvider(
  id: 'provider-cover',
  businessName: 'قاعة بصورة غلاف',
  ownerName: 'مالك القاعة',
  ratingAverage: 0,
  ratingCount: 0,
  isFeatured: false,
  coverUrl: 'https://img.test/cover.jpg',
  city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
);

const _service = MarketplaceService(
  id: 'service-1',
  providerId: 'provider-1',
  title: 'تنسيق قاعة',
  isFeatured: false,
  isActive: true,
  basePrice: '1200',
  currency: 'SAR',
  category: ProviderCategory(id: 'cat-1', nameAr: 'القاعات'),
);

const _package = ProviderPackage(
  id: 'package-1',
  providerId: 'provider-1',
  title: 'باقة استقبال',
  isActive: true,
  price: '3500',
  currency: 'YER',
  items: 'القاعة\nالضيافة',
);

const _review = ProviderReview(
  id: 'review-1',
  rating: 5,
  userName: 'عميل موثق',
  comment: 'خدمة ممتازة.',
);
