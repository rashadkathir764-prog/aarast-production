// A provider's published prices are read one way, in one currency, and
// written whole (critique ب2, RA-MO-259). The list row and the shelf card
// took min and max across every currency and wrote «من 1,500 ر.ي» from a
// price in dollars; three copies of the reading each did it their own way.

import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_details_view.dart';
import 'package:flutter_test/flutter_test.dart';

MarketplaceService _service(String id, String price, String currency) =>
    MarketplaceService(
      id: id,
      providerId: 'p',
      title: id,
      isActive: true,
      basePrice: price,
      currency: currency,
    );

String _plain(String text) =>
    text.replaceAll(RegExp('[\\u2066-\\u2069\\u00a0\\u202f]'), ' ');

void main() {
  test('prices in another currency are not put beside the first one', () {
    final span = providerPriceSpan([
      _service('a', '450000', 'YER'),
      _service('b', '1500', 'USD'),
      _service('c', '900000', 'YER'),
    ]);
    expect(span, isNotNull);
    expect(span!.min, 450000);
    expect(span.max, 900000);
    expect(span.currency, 'YER');
  });

  test('a range and a single price are written whole', () {
    final range = _plain(
      providerPriceRange([
        _service('a', '1250000', 'YER'),
        _service('b', '1340000', 'YER'),
      ])!,
    );
    expect(range, contains('1,250,000'));
    expect(range, contains('1,340,000'));
    expect(range, isNot(contains('مليون')));
    expect(
      _plain(providerPriceRange([_service('a', '450000', 'YER')])!),
      contains('450,000'),
    );
  });

  test('no published price is no range', () {
    expect(providerPriceSpan([_service('a', '', 'YER')]), isNull);
    expect(providerPriceRange(const []), isNull);
  });

  // The comparison's column read the services alone: a provider priced in
  // his packages said «السعر عند الطلب» over the packages' own prices.
  test('the comparison reads the packages with the services', () {
    const package = ProviderPackage(
      id: 'pk',
      providerId: 'p',
      title: 'الباقة الكاملة',
      isActive: true,
      price: '250000',
      currency: 'YER',
    );
    expect(providerPriceRange(const [], packages: const [package]), isNotNull);
    expect(
      _plain(providerPriceRange(const [], packages: const [package])!),
      contains('250,000'),
    );
  });

  // The short figure names no currency («من 15 ألفًا»), so it is the app's
  // own alone: a price in another one keeps its sign.
  test('a card shortens the app\'s currency only', () {
    final riyal = _plain(
      providerFromPriceShort((min: 250000, max: 250000, currency: 'YER'))!,
    );
    expect(riyal, contains('250 ألفًا'));
    final saudi = _plain(
      providerFromPriceShort((min: 15000, max: 15000, currency: 'SAR'))!,
    );
    expect(saudi, contains('15,000'));
    expect(saudi, contains('ر.س'));
    expect(saudi, isNot(contains('ألفًا')));
  });
}
