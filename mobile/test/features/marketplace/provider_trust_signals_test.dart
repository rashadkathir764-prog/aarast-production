import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/provider_contact_links.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_details_view.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_trust_signals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Trust signals on the provider card (V1 checklist 4.11): the admin
// "verified" badge, the date prices last changed, how fast the provider
// answers, and direct WhatsApp / map actions.

final _now = DateTime.utc(2026, 10, 11, 12);

void main() {
  test('the provider response carries the trust fields', () {
    final provider = MarketplaceProvider.fromJson({
      'id': 'provider-1',
      'businessName': 'قاعة السلام',
      'verifiedAt': '2026-10-01T00:00:00.000Z',
      'latitude': '15.3694000',
      'longitude': '44.1910000',
      'responsiveness': {
        'sampleSize': 6,
        'answeredPercent': 83,
        'typicalResponseHours': 3,
      },
      'serviceSummary': {
        'activeCount': 1,
        'pricesUpdatedAt': '2026-09-20T00:00:00.000Z',
      },
      'services': [
        {
          'id': 'service-1',
          'title': 'تنسيق',
          'basePrice': '1000',
          'currency': 'YER',
          'priceUpdatedAt': '2026-09-20T00:00:00.000Z',
        },
      ],
    });

    expect(provider.isVerified, isTrue);
    expect(provider.latitude, 15.3694);
    expect(provider.longitude, 44.191);
    expect(provider.responsiveness?.answeredPercent, 83);
    expect(provider.responsiveness?.typicalResponseHours, 3);
    expect(provider.serviceSummary?.pricesUpdatedAt, DateTime.utc(2026, 9, 20));
    expect(provider.services.single.priceUpdatedAt, DateTime.utc(2026, 9, 20));

    final bare = MarketplaceProvider.fromJson({
      'id': 'provider-2',
      'businessName': 'مزود',
      'responsiveness': {
        'sampleSize': 3,
        'answeredPercent': 0,
        'typicalResponseHours': null,
      },
    });
    expect(bare.isVerified, isFalse);
    expect(bare.latitude, isNull);
    expect(bare.responsiveness?.typicalResponseHours, isNull);
  });

  test('a WhatsApp link needs a number whose country is known', () {
    expect(
      providerWhatsAppUri('+967 777 123 456').toString(),
      'https://wa.me/967777123456',
    );
    expect(
      providerWhatsAppUri('777123456').toString(),
      'https://wa.me/967777123456',
    );
    expect(
      providerWhatsAppUri('00966501234567').toString(),
      'https://wa.me/966501234567',
    );
    expect(providerWhatsAppUri(null), isNull);
    expect(providerWhatsAppUri('  '), isNull);
    expect(providerWhatsAppUri('not a number'), isNull);
  });

  test('a map link needs a valid pinned location', () {
    expect(
      providerMapUri(15.3694, 44.191).toString(),
      'https://www.google.com/maps/search/?api=1&query=15.3694%2C44.191',
    );
    expect(providerMapUri(null, 44.191), isNull);
    expect(providerMapUri(95, 44.191), isNull);
  });

  test('response and price-date labels read naturally in Arabic', () {
    expect(
      providerResponseLabel(
        const ProviderResponsiveness(
          sampleSize: 5,
          answeredPercent: 80,
          typicalResponseHours: 2,
        ),
      ),
      'يرد عادة خلال ساعتين · ردّ على 80٪ من الطلبات',
    );
    expect(
      providerResponseLabel(
        const ProviderResponsiveness(
          sampleSize: 5,
          answeredPercent: 100,
          typicalResponseHours: 30,
        ),
      ),
      'يرد عادة خلال يومين · ردّ على 100٪ من الطلبات',
    );
    expect(
      providerResponseLabel(
        const ProviderResponsiveness(sampleSize: 3, answeredPercent: 0),
      ),
      'لم يرد على طلبات العروض الأخيرة · ردّ على 0٪ من الطلبات',
    );

    expect(priceFreshnessLabel(_now, _now), 'اليوم');
    expect(
      priceFreshnessLabel(_now.subtract(const Duration(days: 1)), _now),
      'أمس',
    );
    expect(
      priceFreshnessLabel(_now.subtract(const Duration(days: 5)), _now),
      'منذ 5 أيام',
    );
    expect(
      priceFreshnessLabel(_now.subtract(const Duration(days: 64)), _now),
      'منذ شهرين',
    );
    expect(
      priceFreshnessLabel(_now.subtract(const Duration(days: 400)), _now),
      'منذ أكثر من سنة',
    );
  });

  test('the latest price change wins and unpriced services are ignored', () {
    expect(latestPriceUpdate(const []), isNull);
    expect(
      latestPriceUpdate([
        _service('a', DateTime.utc(2026, 8, 1)),
        _service('b', DateTime.utc(2026, 9, 1)),
        _service('c', null),
      ]),
      DateTime.utc(2026, 9, 1),
    );
  });

  testWidgets('the details view shows the trust line and its actions', (
    tester,
  ) async {
    var whatsAppTaps = 0;
    var mapTaps = 0;
    await _pumpView(
      tester,
      provider: _verifiedProvider,
      services: [_service('a', _now.subtract(const Duration(days: 3)))],
      onWhatsApp: () => whatsAppTaps++,
      onOpenMap: () => mapTaps++,
    );

    expect(find.byKey(const Key('provider-details-verified')), findsOneWidget);
    expect(find.text('موثّق'), findsOneWidget);
    expect(
      find.text('يرد عادة خلال 3 ساعات · ردّ على 90٪ من الطلبات'),
      findsOneWidget,
    );
    expect(find.text('آخر تحديث للسعر منذ 3 أيام'), findsOneWidget);

    await tester.tap(find.byKey(const Key('provider-whatsapp-action')));
    await tester.tap(find.byKey(const Key('provider-map-action')));
    expect(whatsAppTaps, 1);
    expect(mapTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an old price is flagged and missing signals stay hidden', (
    tester,
  ) async {
    await _pumpView(
      tester,
      provider: _plainProvider,
      services: [_service('a', _now.subtract(const Duration(days: 120)))],
      width: 320,
      textScale: 1.3,
    );

    expect(find.byKey(const Key('provider-details-verified')), findsNothing);
    expect(find.byKey(const Key('provider-trust-response')), findsNothing);
    expect(find.byKey(const Key('provider-whatsapp-action')), findsNothing);
    expect(find.byKey(const Key('provider-map-action')), findsNothing);
    expect(
      find.text('آخر تحديث للسعر منذ 4 أشهر · تأكد منه عند طلب العرض'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

MarketplaceService _service(String id, DateTime? priceUpdatedAt) {
  return MarketplaceService(
    id: id,
    providerId: 'provider-1',
    title: 'خدمة $id',
    isFeatured: false,
    isActive: true,
    basePrice: priceUpdatedAt == null ? null : '1000',
    currency: 'YER',
    priceUpdatedAt: priceUpdatedAt,
  );
}

Future<void> _pumpView(
  WidgetTester tester, {
  required MarketplaceProvider provider,
  List<MarketplaceService> services = const [],
  VoidCallback? onWhatsApp,
  VoidCallback? onOpenMap,
  double width = 390,
  double textScale = 1,
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
            provider: provider,
            services: services,
            packages: const [],
            reviews: const [],
            isFavorite: false,
            onBack: () {},
            onShare: () {},
            onFavorite: () {},
            onRequestQuote: (_) {},
            onWhatsApp: onWhatsApp,
            onOpenMap: onOpenMap,
            now: _now,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _verifiedProvider = MarketplaceProvider(
  id: 'provider-1',
  businessName: 'قاعة السلام',
  ownerName: 'مالك القاعة',
  ratingAverage: 4.7,
  ratingCount: 12,
  isFeatured: false,
  verifiedAt: DateTime.utc(2026, 10, 1),
  responsiveness: const ProviderResponsiveness(
    sampleSize: 10,
    answeredPercent: 90,
    typicalResponseHours: 3,
  ),
);

const _plainProvider = MarketplaceProvider(
  id: 'provider-2',
  businessName: 'مزود جديد',
  ownerName: 'مالك',
  ratingAverage: 0,
  ratingCount: 0,
  isFeatured: false,
);
