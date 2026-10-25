import 'package:aarast_mobile/core/utils/offer_changes.dart';
import 'package:flutter_test/flutter_test.dart';

// B-06: «ايش تغيّر» in one line, the new price first, for the customer
// («they» changed) and for the provider reading his own offer.
void main() {
  QuoteOfferChange change(String field, String? from, String? to) =>
      QuoteOfferChange.fromJson({'field': field, 'from': from, 'to': to});

  test('a new price leads, with the old one beside it', () {
    expect(
      quoteOfferChangeLine(
        changes: [
          change('amount', '550000', '520000'),
          change('message', 'a', 'b'),
        ],
        currency: 'YER',
        own: false,
      ),
      'السعر صار 520,000 ر.ي بدل 550,000',
    );
  });

  test('changed words keep «بنفس السعر», for each side', () {
    final words = [change('message', 'مصورين', 'مصورين · ألبوم')];
    expect(
      quoteOfferChangeLine(changes: words, currency: 'YER', own: false),
      'غيّروا التفاصيل بنفس السعر',
    );
    expect(
      quoteOfferChangeLine(changes: words, currency: 'YER', own: true),
      'غيّرت التفاصيل بنفس السعر',
    );
  });

  test('a renewal names the new end day; version 1 has no line', () {
    expect(
      quoteOfferChangeLine(
        changes: [
          change(
            'validUntil',
            '2026-10-28T00:00:00.000Z',
            '2026-11-07T12:00:00.000Z',
          ),
        ],
        currency: 'YER',
        own: false,
      ),
      'مدّدوا العرض لين 7 نوفمبر',
    );
    expect(
      quoteOfferChangeLine(changes: const [], currency: 'YER', own: false),
      isNull,
    );
  });
}
