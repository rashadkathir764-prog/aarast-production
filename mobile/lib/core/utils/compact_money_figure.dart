import 'keep_currency_on_line.dart';
import 'money_formatters.dart';

/// [compactMoneyFigure] when shortening loses nothing («1.5 مليون», «250
/// ألفًا»), else the amount in full («1,450,000 ر.ي»): for figures read
/// together that add up (critique م2: «اتفقت 3.4، دفعت 1.5، باقي 2», and
/// 1.5 + 2 is not 3.4). The rule is [shortensWithoutLoss]; for millions it
/// is [sumSafeMoneyParts]'s own (a tenth of a million), which sits in the
/// pinned Core formatter and is not edited for a tidy-up.
String sumSafeMoneyFigure(num value, {required String currencyCode}) {
  if (shortensWithoutLoss(value)) {
    return compactMoneyFigure(value, currencyCode: currencyCode);
  }
  return keepCurrencyOnLine(
    fullMoneyParts(value, currencyCode: currencyCode).plainText,
  );
}

/// The one rule for a short figure that adds up (critique م2): a million's
/// tenth, or a thousand's tenth below a million, keeps [value] whole.
bool shortensWithoutLoss(num value) {
  final abs = value.abs();
  if (abs >= 1000000) return abs % 100000 == 0;
  if (abs >= 1000) return abs % 100 == 0;
  // Below a thousand the figure is the amount itself: whole is kept whole,
  // a stored fraction (before Q25) is not rounded away.
  return abs == abs.truncateToDouble();
}

/// A short money figure that always carries its unit (V-01): «3 ملايين»,
/// «250 ألفًا», and below a thousand the currency itself («750 ر.ي»). One
/// convention for every figure in a column, so no line reads a bare number
/// beside another with its currency. The space before the unit never breaks.
/// The unit follows the number shown ([countedScaleWords]): «1 مليون»,
/// «2 مليون», «15 مليونًا», «1.5 مليون», «2 ألف», «800 ألف».
///
/// Millions come from [compactMoneyParts] (one decimal); thousands follow
/// the same rule.
String compactMoneyFigure(num value, {required String currencyCode}) {
  final parts = compactMoneyParts(value, currencyCode: currencyCode);
  if (parts.millionUnit != null) {
    return keepCurrencyOnLine(
      countedScaleWords(parts.number, scale: CompactScale.million),
    );
  }
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
    return keepCurrencyOnLine(
      countedScaleWords('$sign$thousands', scale: CompactScale.thousand),
    );
  }
  return keepCurrencyOnLine(parts.plainText);
}
