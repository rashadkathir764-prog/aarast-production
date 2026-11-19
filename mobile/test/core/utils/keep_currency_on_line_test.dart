import 'package:aarast_mobile/core/utils/keep_currency_on_line.dart';
import 'package:aarast_mobile/core/utils/money_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

// D118: a line never breaks inside an amount.
void main() {
  test('every space inside an amount is a no-break space', () {
    expect(keepCurrencyOnLine('50,000 ر.ي'), '50,000\u00a0ر.ي');
    expect(keepCurrencyOnLine('2.6 مليون ر.ي'), '2.6\u00a0مليون\u00a0ر.ي');
    expect(
      formatCompactMoney(50000, currencyCode: 'YER'),
      isNot(contains(' ')),
    );
    expect(
      fullMoneyParts(2600000, currencyCode: 'YER').plainText,
      isNot(contains(' ')),
    );
  });

  test('a hidden amount has nothing to keep together', () {
    expect(keepCurrencyOnLine('••••'), '••••');
  });
}
