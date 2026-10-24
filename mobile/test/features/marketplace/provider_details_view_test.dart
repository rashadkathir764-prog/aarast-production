import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// f03 «صفحة المزود», on the prototype's own provider (استوديو ضوء صنعاء).

final _now = DateTime(2026, 10, 24, 12);

void main() {
  testWidgets('g02 data saver keeps the page photo from loading', (
    tester,
  ) async {
    await _pumpView(tester, dataSaver: true);

    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const ValueKey('provider-media-fallback')),
      findsOneWidget,
    );
  });

  testWidgets('f03 shows the provider as the prototype does', (tester) async {
    await _pumpView(tester, withinBudget: true);

    expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
    expect(find.byTooltip('موثّق'), findsOneWidget);
    expect(find.textContaining('4.8', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('(63) · صنعاء، حدة', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('يرد عادة خلال ساعتين'), findsOneWidget);
    expect(find.text('450,000 - 600,000 ر.ي'), findsOneWidget);
    expect(find.text('ضمن بندك'), findsOneWidget);
    expect(find.text('آخر تحديث للسعر قبل 3 أسابيع'), findsOneWidget);
    expect(find.text('الباقات'), findsOneWidget);
    expect(find.text('صور فقط'), findsOneWidget);
    expect(find.text('مصور واحد · 300 صورة'), findsOneWidget);
    expect(find.text('350,000 ر.ي'), findsOneWidget);
    expect(find.text('صور وفيديو'), findsOneWidget);
    expect(find.text('مصورين · فيلم 10 دقائق · ألبوم'), findsOneWidget);
    expect(find.text('1 / 3 صورة'), findsOneWidget);

    // Dropped by the classification (no data behind them), and the old
    // page's extras that are not in the prototype.
    expect(find.textContaining('دفعوا فعلًا'), findsNothing);
    expect(find.textContaining('من 11 عرس'), findsNothing);
    expect(find.textContaining('فاضي'), findsNothing);
    expect(find.textContaining('مرجع تخطيطي'), findsNothing);
    expect(find.byTooltip('مشاركة'), findsNothing);
    expect(find.byTooltip('حفظ المزود'), findsNothing);
    expect(find.textContaining('التقييمات'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back and a package lead where they should', (tester) async {
    var backs = 0;
    final opened = <String?>[];
    await _pumpView(tester, onBack: () => backs++, onOpenOffer: opened.add);

    await tester.tap(find.byTooltip('رجوع'));
    await tester.tap(find.text('صور وفيديو'));
    await tester.pump();

    expect(backs, 1);
    expect(opened, ['service-video']);
  });

  testWidgets('the photo opens the full gallery', (tester) async {
    await _pumpView(tester);

    await tester.tap(find.bySemanticsLabel('افتح الصور'));
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('without packages the priced services are the offers', (
    tester,
  ) async {
    await _pumpView(tester, packages: const []);

    expect(find.text('الباقات'), findsOneWidget);
    expect(find.text('تصوير كامل'), findsOneWidget);
    expect(find.text('600,000 ر.ي'), findsOneWidget);
    expect(find.text('ضمن بندك'), findsNothing);
  });

  testWidgets('nothing priced shows no price and no offers', (tester) async {
    await _pumpView(
      tester,
      provider: _provider(withResponses: false, address: null),
      services: const [],
      packages: const [],
    );

    expect(find.byKey(const ValueKey('provider-details-price')), findsNothing);
    expect(find.text('الباقات'), findsNothing);
    expect(find.textContaining('يرد عادة'), findsNothing);
    // The cover is the only photo left.
    expect(find.text('1 / 1 صورة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an old price asks to confirm it', (tester) async {
    await _pumpView(
      tester,
      services: [
        _photoService(
          'service-old',
          '450000',
          _now.subtract(const Duration(days: 120)),
        ),
      ],
      packages: const [],
    );

    expect(
      find.text('آخر تحديث للسعر قبل 4 شهور · تأكد منه لما تطلب العرض'),
      findsOneWidget,
    );
  });

  testWidgets('a failed refresh over an older copy offers a retry', (
    tester,
  ) async {
    var retries = 0;
    await _pumpView(
      tester,
      detailsErrorMessage: 'تعذر تحديث المزود.',
      onRetryDetails: () => retries++,
    );

    expect(
      find.byKey(const ValueKey('journey-list-notice-error')),
      findsOneWidget,
    );
    await tester.tap(find.text('حاول مرة ثانية'));
    expect(retries, 1);
  });

  testWidgets('f03 stays readable at 320px and 1.3 text', (tester) async {
    await _pumpView(tester, width: 320, textScale: 1.3, withinBudget: true);

    expect(tester.takeException(), isNull);
    expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
  });
}

MarketplaceProvider _provider({
  bool withResponses = true,
  String? address = 'حدة',
}) => MarketplaceProvider(
  id: 'provider-1',
  businessName: 'استوديو ضوء صنعاء',
  ownerName: 'مالك الاستوديو',
  ratingAverage: 4.8,
  ratingCount: 63,
  isFeatured: false,
  city: const MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء'),
  address: address,
  coverUrl: 'https://img.test/cover.jpg',
  verifiedAt: DateTime(2026, 9, 1),
  responsiveness: withResponses
      ? const ProviderResponsiveness(
          sampleSize: 11,
          answeredPercent: 100,
          typicalResponseHours: 2,
        )
      : null,
);

MarketplaceService _photoService(String id, String price, DateTime updated) =>
    MarketplaceService(
      id: id,
      providerId: 'provider-1',
      title: id == 'service-video' ? 'تصوير كامل' : 'تصوير صور',
      isFeatured: false,
      isActive: true,
      basePrice: price,
      currency: 'YER',
      priceUpdatedAt: updated,
      category: const ProviderCategory(id: 'cat-photo', nameAr: 'التصوير'),
      images: [
        ProviderServiceImage(
          id: '$id-image',
          imageUrl: 'https://img.test/$id.jpg',
        ),
      ],
    );

final _services = [
  _photoService(
    'service-photos',
    '450000',
    _now.subtract(const Duration(days: 30)),
  ),
  _photoService(
    'service-video',
    '600000',
    _now.subtract(const Duration(days: 21)),
  ),
];

const _packages = [
  ProviderPackage(
    id: 'package-photos',
    providerId: 'provider-1',
    serviceId: 'service-photos',
    title: 'صور فقط',
    items: 'مصور واحد\n300 صورة',
    price: '350000',
    currency: 'YER',
    isActive: true,
  ),
  ProviderPackage(
    id: 'package-video',
    providerId: 'provider-1',
    serviceId: 'service-video',
    title: 'صور وفيديو',
    items: 'مصورين\nفيلم 10 دقائق\nألبوم',
    price: '550000',
    currency: 'YER',
    isActive: true,
  ),
];

Future<void> _pumpView(
  WidgetTester tester, {
  MarketplaceProvider? provider,
  List<MarketplaceService>? services,
  List<ProviderPackage> packages = _packages,
  bool withinBudget = false,
  VoidCallback? onBack,
  ValueChanged<String?>? onOpenOffer,
  String? detailsErrorMessage,
  VoidCallback? onRetryDetails,
  double width = 384,
  double textScale = 1,
  bool dataSaver = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1400);
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
            provider: provider ?? _provider(),
            services: services ?? _services,
            packages: packages,
            onBack: onBack ?? () {},
            onOpenOffer: onOpenOffer ?? (_) {},
            withinBudget: withinBudget,
            detailsErrorMessage: detailsErrorMessage,
            onRetryDetails: onRetryDetails,
            now: _now,
            dataSaver: dataSaver,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
