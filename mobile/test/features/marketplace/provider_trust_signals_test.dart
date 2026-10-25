import 'package:aarast_mobile/features/marketplace/data/provider_contact_links.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_trust_signals.dart';
import 'package:flutter_test/flutter_test.dart';

// Trust signals on the provider page (V1 checklist 4.11, f03): the admin
// "verified" badge, the date prices last changed, how fast the provider
// answers, and the direct WhatsApp action.

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

  test('f03 says how fast a provider answers, only from answers', () {
    expect(
      providerRespondsLabel(
        const ProviderResponsiveness(
          sampleSize: 5,
          answeredPercent: 80,
          typicalResponseHours: 2,
        ),
      ),
      'يرد عادة خلال ساعتين',
    );
    expect(
      providerRespondsLabel(
        const ProviderResponsiveness(
          sampleSize: 5,
          answeredPercent: 100,
          typicalResponseHours: 30,
        ),
      ),
      'يرد عادة خلال يومين',
    );
    // Nothing answered, or nothing asked: no promise either way.
    expect(
      providerRespondsLabel(
        const ProviderResponsiveness(sampleSize: 3, answeredPercent: 0),
      ),
      isNull,
    );
    expect(
      providerRespondsLabel(
        const ProviderResponsiveness(
          sampleSize: 0,
          answeredPercent: 0,
          typicalResponseHours: 2,
        ),
      ),
      isNull,
    );
    expect(providerRespondsLabel(null), isNull);
  });

  test('f03 says how old a price is, and asks to confirm an old one', () {
    String line(int days) =>
        priceAgeLine(_now.subtract(Duration(days: days)), _now);

    expect(line(0), 'آخر تحديث للسعر اليوم');
    expect(line(1), 'آخر تحديث للسعر أمس');
    expect(line(5), 'آخر تحديث للسعر قبل 5 أيام');
    expect(line(15), 'آخر تحديث للسعر قبل أسبوعين');
    expect(line(21), 'آخر تحديث للسعر قبل 3 أسابيع');
    expect(line(64), 'آخر تحديث للسعر قبل شهرين');
    expect(
      line(120),
      'آخر تحديث للسعر قبل 4 شهور · تأكد منه لما تطلب العرض',
    );
    expect(
      line(400),
      'آخر تحديث للسعر قبل أكثر من سنة · تأكد منه لما تطلب العرض',
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
}

MarketplaceService _service(String id, DateTime? priceUpdatedAt) {
  return MarketplaceService(
    id: id,
    providerId: 'provider-1',
    title: 'خدمة $id',    isActive: true,
    basePrice: priceUpdatedAt == null ? null : '1000',
    currency: 'YER',
    priceUpdatedAt: priceUpdatedAt,
  );
}
