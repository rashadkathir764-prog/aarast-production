import 'package:aarast_mobile/core/utils/compact_money_figure.dart';
import 'package:flutter_test/flutter_test.dart';

// V-01: a short figure always carries its unit, and the unit never wraps away
// from its number (the space between them does not break).
void main() {
  const nbsp = ' ';

  String figure(num value, [String currency = 'YER']) =>
      compactMoneyFigure(value, currencyCode: currency);

  test('millions read «مليون»', () {
    expect(figure(3000000), '3$nbspمليون');
    expect(figure(2600000), '2.6$nbspمليون');
    expect(figure(1000000), '1$nbspمليون');
  });

  test('thousands read «ألف»', () {
    expect(figure(250000), '250$nbspألف');
    expect(figure(1500), '1.5$nbspألف');
    expect(figure(1000), '1$nbspألف');
    expect(figure(12340), '12.3$nbspألف');
  });

  test('a figure that rounds up to a thousand thousands reads one million', () {
    expect(figure(999999), '1$nbspمليون');
  });

  test('below a thousand the currency is the unit', () {
    expect(figure(0), '0$nbspر.ي');
    expect(figure(750), '750$nbspر.ي');
    expect(figure(500, 'SAR'), '500$nbspر.س');
  });

  test('a negative figure keeps its sign and its unit', () {
    expect(figure(-250000), '-250$nbspألف');
    expect(figure(-3000000), '-3$nbspمليون');
  });
}
