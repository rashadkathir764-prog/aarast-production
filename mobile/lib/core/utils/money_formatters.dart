import 'currency_label.dart';
import 'keep_currency_on_line.dart';

class CompactYemeniMoneyParts {
  const CompactYemeniMoneyParts({
    required this.number,
    required this.currency,
    required this.spokenCurrency,
    this.millionUnit,
  });

  /// The digits as shown, «3», «1.5», «250,000».
  final String number;

  /// The word that sits beside [number]: «مليون» (1, 2, a fraction, 100 and
  /// up), «ملايين» (3 to 10), «مليونًا» (11 to 99). Null below a million.
  final String? millionUnit;
  final String currency;
  final String spokenCurrency;

  /// The digits and their word, «1 مليون», «2 مليون», «3 ملايين», or the
  /// digits alone below a million.
  String get _counted => millionUnit == null ? number : '$number $millionUnit';

  /// The amount as text, kept on one line ([keepCurrencyOnLine]).
  String get plainText => keepCurrencyOnLine('$_counted $currency');

  String get semanticText => '$_counted $spokenCurrency';

  /// A directionally isolated representation for embedding inside Arabic text.
  ///
  /// The outer LTR isolate keeps the numeric amount in reading order, while
  /// each Arabic suffix is its own RTL isolate. This prevents Unicode bidi
  /// reordering from turning `1.5 مليون ر.ي` into a detached unit/currency.
  String get directionalText {
    final unit = millionUnit;
    if (unit == null) {
      return keepCurrencyOnLine(
        _isolateLtr('$number ${_isolateRtl(currency)}'),
      );
    }
    return keepCurrencyOnLine(
      _isolateLtr('$number ${_isolateRtl(unit)} ${_isolateRtl(currency)}'),
    );
  }
}

/// A short figure's scale: millions or thousands.
enum CompactScale {
  million(one: 'مليون', few: 'ملايين', many: 'مليونًا'),
  thousand(one: 'ألف', few: 'آلاف', many: 'ألفًا');

  const CompactScale({
    required this.one,
    required this.few,
    required this.many,
  });

  /// The singular: beside 1, 2, a fraction, and 100 and up.
  final String one;

  /// After 3 to 10: «3 ملايين».
  final String few;

  /// After 11 to 99: «15 مليونًا».
  final String many;
}

/// [number] as shown («1», «2», «15», «1.5», «-3») with its [scale] word
/// (LANGUAGE.md §4.7, D136): «1 مليون»، «2 مليون»، «3 ملايين»، «15 مليونًا»،
/// «100 مليون»، «1.5 مليون»; «2 ألف»، «3 آلاف»، «250 ألفًا»، «800 ألف».
///
/// A short figure always opens with its digits. One and two are not said as
/// words («مليون»، «مليونان»): the dual changes with its place in the
/// sentence («اتفقت على مليونين»، «الباقي مليونان»), and one figure is read
/// in every place, so the word form was wrong after every preposition.
String countedScaleWords(String number, {required CompactScale scale}) =>
    '$number ${scaleWordBesideDigits(number, scale: scale)}';

/// The [scale] word that sits beside [number]'s digits: the singular for
/// 1, 2, a fraction and 100 up, the plural after 3 to 10, the accusative
/// after 11 to 99.
String scaleWordBesideDigits(String number, {required CompactScale scale}) {
  final whole = int.tryParse(number.replaceAll(',', ''));
  if (whole == null) return scale.one;
  final lastTwo = whole.abs() % 100;
  if (lastTwo >= 3 && lastTwo <= 10) return scale.few;
  if (lastTwo >= 11) return scale.many;
  return scale.one;
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
    number: '$negative${_formatExactMoney(value.abs())}',
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
  if (value.abs() >= 1000000 &&
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
    final number = '$negative${compactTenths(absValue, 1000000)}';
    return CompactYemeniMoneyParts(
      number: number,
      millionUnit: scaleWordBesideDigits(number, scale: CompactScale.million),
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

// Q25 keeps new input whole; stored pre-Q25 amounts have two decimal places
// and must still be read exactly (RA-MO-52), including a rest below one rial.
String _formatExactMoney(num value) {
  final fixed = value.toStringAsFixed(2).split('.');
  final fraction = fixed[1].replaceFirst(RegExp(r'0+$'), '');
  final whole = _formatMoney(int.parse(fixed[0]));
  return fraction.isEmpty ? whole : '$whole.$fraction';
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
