import 'currency_label.dart';

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

  String get plainText {
    final unit = millionUnit;
    return unit == null ? '$number $currency' : '$number $unit $currency';
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
    return _isolateLtr('$number $suffix');
  }
}

CompactYemeniMoneyParts compactYemeniMoneyParts(num value) {
  return compactMoneyParts(value, currencyCode: defaultCurrencyCode);
}

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
