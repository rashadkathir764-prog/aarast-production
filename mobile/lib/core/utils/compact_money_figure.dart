import 'keep_currency_on_line.dart';
import 'money_formatters.dart';

/// A short money figure that always carries its unit (V-01): «3 مليون»,
/// «250 ألف», and below a thousand the currency itself («750 ر.ي»). One
/// convention for every figure in a column, so no line reads a bare number
/// beside another with its currency. The space before the unit never breaks.
///
/// Millions come from [compactMoneyParts] (one decimal); thousands follow
/// the same rule.
String compactMoneyFigure(num value, {required String currencyCode}) {
  final parts = compactMoneyParts(value, currencyCode: currencyCode);
  final million = parts.millionUnit;
  if (million != null) return keepCurrencyOnLine('${parts.number} $million');
  final abs = value.abs();
  if (abs >= 1000) {
    final thousands = compactTenths(abs, 1000);
    // 999,999 rounds to «1000 ألف»: that is a million.
    if (thousands == '1000') {
      return compactMoneyFigure(
        value.isNegative ? -1000000 : 1000000,
        currencyCode: currencyCode,
      );
    }
    final sign = value.isNegative ? '-' : '';
    return keepCurrencyOnLine('$sign$thousands ألف');
  }
  return keepCurrencyOnLine(parts.plainText);
}
