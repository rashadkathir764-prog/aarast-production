import 'package:aarast_mobile/core/utils/compact_money_figure.dart';
import 'package:flutter_test/flutter_test.dart';

// V-01: a short figure always carries its unit, and the unit never wraps away
// from its number (the space between them does not break). D129: the unit is
// counted by the number shown, in Modern Standard Arabic. D136: the figure
// always opens with its digits; one and two are not said as words, because
// the dual changes with its place in the sentence and one figure is read in
// every place.
void main() {
  const nbsp = '\u{00a0}';

  String figure(num value, [String currency = 'YER']) =>
      compactMoneyFigure(value, currencyCode: currency);

  test('millions are counted by the number shown', () {
    expect(figure(1000000), '1$nbspمليون');
    expect(figure(2000000), '2$nbspمليون');
    expect(figure(3000000), '3$nbspملايين');
    expect(figure(10000000), '10$nbspملايين');
    expect(figure(15000000), '15$nbspمليونًا');
    expect(figure(100000000), '100$nbspمليون');
    expect(figure(103000000), '103$nbspملايين');
    expect(figure(111000000), '111$nbspمليونًا');
  });

  test('a fraction takes the singular', () {
    expect(figure(1500000), '1.5$nbspمليون');
    expect(figure(2600000), '2.6$nbspمليون');
    expect(figure(1500), '1.5$nbspألف');
    expect(figure(12340), '12.3$nbspألف');
  });

  test('thousands are counted by the number shown', () {
    expect(figure(1000), '1$nbspألف');
    expect(figure(2000), '2$nbspألف');
    expect(figure(3000), '3$nbspآلاف');
    expect(figure(15000), '15$nbspألفًا');
    expect(figure(250000), '250$nbspألفًا');
    expect(figure(800000), '800$nbspألف');
    expect(figure(101000), '101$nbspألف');
  });

  // A half rounds up the same way every time: dividing before rounding
  // read 1,950,000 as «1.9» and 1,550,000 as «1.6».
  test('a half rounds up, whatever its digits', () {
    expect(figure(1950000), '2$nbspمليون');
    expect(figure(1550000), '1.6$nbspمليون');
    expect(figure(3150000), '3.2$nbspمليون');
    expect(figure(2350000), '2.4$nbspمليون');
    expect(figure(1940000), '1.9$nbspمليون');
    expect(figure(1150), '1.2$nbspألف');
    expect(figure(-1950000), '-2$nbspمليون');
  });

  test('a figure that rounds up to a thousand thousands reads one million', () {
    expect(figure(999999), '1$nbspمليون');
  });

  // D136: the same figure is read after a preposition, as a subject and
  // alone. The word dual was right in one of them only.
  test('no figure is a bare word: the digits always lead', () {
    for (final value in [1000, 2000, 1000000, 2000000, 1950000]) {
      expect(figure(value), matches(RegExp(r'^\d')), reason: '$value');
    }
  });

  test('below a thousand the currency is the unit', () {
    expect(figure(0), '0$nbspر.ي');
    expect(figure(750), '750$nbspر.ي');
    expect(figure(500, 'SAR'), '500$nbspر.س');
  });

  test('a negative figure keeps its sign, its digits and its unit', () {
    expect(figure(-250000), '-250$nbspألفًا');
    expect(figure(-3000000), '-3$nbspملايين');
    expect(figure(-1000000), '-1$nbspمليون');
  });

  test('a stored amount with a fraction is written whole, not rounded', () {
    // Below a thousand every amount «shortened without loss», so a pre-Q25
    // 700.25 read «700 ر.ي» while the same record read 700.25 on its own
    // page (RA-MO-52).
    String plain(String text) =>
        text.replaceAll(RegExp('[\u{2066}-\u{2069}\u{00a0}\u{202f}]'), ' ');
    expect(shortensWithoutLoss(700.25), isFalse);
    expect(
      plain(sumSafeMoneyFigure(700.25, currencyCode: 'YER')),
      contains('700.25'),
    );
    expect(shortensWithoutLoss(700), isTrue);
    expect(shortensWithoutLoss(1000.5), isFalse);
  });
}
