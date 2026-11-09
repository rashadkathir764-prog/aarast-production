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
