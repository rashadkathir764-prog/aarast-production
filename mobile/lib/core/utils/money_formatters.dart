import 'currency_label.dart';
import 'keep_currency_on_line.dart';

class CompactYemeniMoneyParts {
  const CompactYemeniMoneyParts({
    required this.number,
    required this.currency,
    required this.spokenCurrency,
    this.millionUnit,
  });

  final String number;
  final String? millionUnit;
  final String currency;
  final String spokenCurrency;

  /// The amount as text, kept on one line ([keepCurrencyOnLine]).
  String get plainText {
    final unit = millionUnit;
    return keepCurrencyOnLine(
      unit == null ? '$number $currency' : '$number $unit $currency',
    );
  }

  String get semanticText {
    final unit = millionUnit;
    return unit == null
        ? '$number $spokenCurrency'
        : '$number $unit $spokenCurrency';
  }

  /// A directionally isolated representation for embedding inside Arabic text.
  ///
  /// The outer LTR isolate keeps the numeric amount in reading order, while
  /// each Arabic suffix is its own RTL isolate. This prevents Unicode bidi
  /// reordering from turning `1.5 مليون ر.ي` into a detached unit/currency.
  String get directionalText {
    final unit = millionUnit;
    final suffix = unit == null
        ? _isolateRtl(currency)
        : '${_isolateRtl(unit)} ${_isolateRtl(currency)}';
    return keepCurrencyOnLine(_isolateLtr('$number $suffix'));
  }
}

// The app's money in three ways, one source (the design critique's blockers
// م1 and ب1, 2026-11-14: «باقي 1.3 مليون» refused the 1,300,000 typed from it,
// and offers of 1,250,000 and 1,340,000 read alike on «قارن عروض»):
// - [fullMoneyParts]: every amount on its own record (an agreement, a
//   payment, a date to pay, what is left), in a form or its error, every
//   offer's price, a notice and a shared text. Never rounded.
// - [compactMoneyParts]: one large headline figure on a summary or the home
//   («باقي عليك 1.3 مليون»), where the tenth of a million is the point.
// - [sumSafeMoneyParts]: figures read together that add up (agreed, paid,
//   left): shortened only when shortening loses nothing, else full (RA-MO-168
//   for every such line, not one card).

CompactYemeniMoneyParts compactYemeniMoneyParts(num value) {
  return compactMoneyParts(value, currencyCode: defaultCurrencyCode);
}

/// [value] in full, «1,250,000 ر.ي»: see the three ways above.
CompactYemeniMoneyParts fullMoneyParts(
  num value, {
  required String currencyCode,
}) {
  final negative = value < 0 ? '-' : '';
  return CompactYemeniMoneyParts(
    number: '$negative${_formatMoney(value.abs())}',
    currency: currencyLabelAr(currencyCode),
    spokenCurrency: currencySpokenLabelAr(currencyCode),
  );
}

/// [value] shortened when the tenth of a million keeps it whole («1.5
/// مليون» for 1,500,000), else in full («1,450,000»): for figures that are
/// read together and add up.
CompactYemeniMoneyParts sumSafeMoneyParts(
  num value, {
  required String currencyCode,
}) {
  final hundredThousands = value / 100000;
  if (value.abs() < 1000000 ||
      hundredThousands == hundredThousands.roundToDouble()) {
    return compactMoneyParts(value, currencyCode: currencyCode);
  }
  return fullMoneyParts(value, currencyCode: currencyCode);
}

/// [fullMoneyParts], isolated for Arabic text.
String formatFullMoney(num value, {required String currencyCode}) {
  return fullMoneyParts(value, currencyCode: currencyCode).directionalText;
}

/// An amount the server sends as text («550000», «550,000») in full, «550,000
/// ر.ي»; null when it is not a number. The one reading of an offer's or a
/// service's price (critique ب2: five copies of it, each its own way).
String? fullMoneyFromText(String? amount, String? currency) {
  final value = num.tryParse(amount?.replaceAll(',', '').trim() ?? '');
  if (value == null) return null;
  return fullMoneyParts(
    value,
    currencyCode: currencyCodeFromDisplayInput(currency),
  ).plainText;
}

/// [value]'s digits grouped by thousands, «1,250,000», without a currency.
String formatMoneyNumber(num value) => _formatMoney(value);

CompactYemeniMoneyParts compactMoneyParts(
  num value, {
  required String currencyCode,
}) {
  final absValue = value.abs();
  final negative = value < 0 ? '-' : '';
  if (absValue >= 1000000) {
    return CompactYemeniMoneyParts(
      number: '$negative${compactTenths(absValue, 1000000)}',
      millionUnit: 'مليون',
      currency: currencyLabelAr(currencyCode),
      spokenCurrency: currencySpokenLabelAr(currencyCode),
    );
  }
  return CompactYemeniMoneyParts(
    number: '$negative${_formatMoney(absValue)}',
    currency: currencyLabelAr(currencyCode),
    spokenCurrency: currencySpokenLabelAr(currencyCode),
  );
}

String formatCompactMoney(num value, {required String currencyCode}) {
  return compactMoneyParts(value, currencyCode: currencyCode).directionalText;
}

String plainCompactMoneyForTests(num value, {required String currencyCode}) {
  return stripMoneyDirectionalityMarks(
    formatCompactMoney(value, currencyCode: currencyCode),
  );
}

String formatCompactYemeniMoney(num value) {
  return formatCompactMoney(value, currencyCode: defaultCurrencyCode);
}

String plainCompactYemeniMoneyForTests(num value) {
  return stripMoneyDirectionalityMarks(formatCompactYemeniMoney(value));
}

String stripMoneyDirectionalityMarks(String value) {
  return value
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u2066', '')
      .replaceAll('\u2067', '')
      .replaceAll('\u2068', '')
      .replaceAll('\u2069', '')
      .replaceAll('\u200e', '')
      .replaceAll('\u200f', '');
}

String _isolateLtr(String value) => '\u2066$value\u2069';

String _isolateRtl(String value) => '\u2067$value\u2069';

/// [value] in [unit]s to one decimal, a half rounded up («1.95 مليون» is
/// «2»). Counted in tenths from the value itself: dividing first stores 1.95
/// as 1.9499…, so 1,950,000 read «1.9 مليون» while 1,550,000 read «1.6».
String compactTenths(num value, num unit) {
  final tenths = (value / (unit / 10)).round();
  final whole = tenths ~/ 10;
  final part = tenths % 10;
  return part == 0 ? '$whole' : '$whole.$part';
}

String _formatMoney(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}
