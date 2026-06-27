class CompactYemeniMoneyParts {
  const CompactYemeniMoneyParts({
    required this.number,
    required this.currency,
    this.millionUnit,
  });

  final String number;
  final String? millionUnit;
  final String currency;

  String get plainText {
    final unit = millionUnit;
    return unit == null ? '$number $currency' : '$number$unit $currency';
  }
}

CompactYemeniMoneyParts compactYemeniMoneyParts(num value) {
  final absValue = value.abs();
  final negative = value < 0 ? '-' : '';
  if (absValue >= 1000000) {
    return CompactYemeniMoneyParts(
      number: '$negative${_trimDecimal(absValue / 1000000)}',
      millionUnit: 'م',
      currency: 'ر.ي',
    );
  }
  return CompactYemeniMoneyParts(
    number: '$negative${_formatMoney(absValue)}',
    currency: 'ر.ي',
  );
}

String formatCompactYemeniMoney(num value) {
  return _isolateLtr(compactYemeniMoneyParts(value).plainText);
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

String _isolateLtr(String value) {
  return '\u2066$value\u2069';
}

String _trimDecimal(num value) {
  final fixed = value.toStringAsFixed(value >= 10 ? 0 : 1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
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
