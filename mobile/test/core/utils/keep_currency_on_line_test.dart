import 'package:aarast_mobile/core/utils/keep_currency_on_line.dart';
import 'package:aarast_mobile/core/utils/money_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the currency stays on its number\'s line', () {
    expect(keepCurrencyOnLine('50,000 ر.ي'), '50,000 ر.ي');
    expect(keepCurrencyOnLine('2.6 مليون ر.ي'), '2.6 مليون ر.ي');
    expect(
      keepCurrencyOnLine(formatCompactMoney(50000, currencyCode: 'YER')),
      contains(' '),
    );
  });

  test('a hidden amount has nothing to keep together', () {
    expect(keepCurrencyOnLine('••••'), '••••');
  });
}
