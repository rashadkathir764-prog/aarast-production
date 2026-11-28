/// Spells an amount in Modern Standard Arabic (D129), under amount fields,
/// so a zero too many or too few is seen before saving: 350000 is
/// «ثلاثمئة وخمسون ألف ريال», 3000000 «ثلاثة ملايين ريال».
///
/// The last scale word is joined to the currency, the way MSA counts a
/// noun: «خمسة وعشرون ألف ريال», «مليونا ريال», «مئتا ريال»; a scale word
/// that more follows is counted on its own: «خمسة عشر مليونًا ومئتان
/// وخمسون ألف ريال». A rest below a thousand keeps the currency as a label.
String amountInWords(int amount, {String currency = 'ريال'}) {
  if (amount <= 0) return 'صفر $currency';
  final parts = <String>[];
  final millions = amount ~/ 1000000;
  final thousands = (amount % 1000000) ~/ 1000;
  final rest = amount % 1000;
  if (millions > 0) {
    parts.add(_scaled(millions, _million, last: thousands == 0 && rest == 0));
  }
  if (thousands > 0) parts.add(_scaled(thousands, _thousand, last: rest == 0));
  if (rest > 0) parts.add(_below1000(rest, beforeNoun: true));
  return '${parts.join(' و')} $currency';
}

typedef _Scale = ({
  String one,
  String two,
  String twoJoined,
  String few,
  String many,
});

const _thousand = (
  one: 'ألف',
  two: 'ألفان',
  twoJoined: 'ألفا',
  few: 'آلاف',
  many: 'ألفًا',
);
const _million = (
  one: 'مليون',
  two: 'مليونان',
  twoJoined: 'مليونا',
  few: 'ملايين',
  many: 'مليونًا',
);

/// [n] of [scale]: «ألف», «ألفان», «ثلاثة آلاف», «خمسة عشر ألفًا», «مئة
/// ألف». [last] joins it to the currency that follows: «ألفا ريال»,
/// «خمسة عشر ألف ريال».
String _scaled(int n, _Scale scale, {required bool last}) {
  if (n == 1) return scale.one;
  if (n == 2) return last ? scale.twoJoined : scale.two;
  final lastTwo = n % 100;
  // 101,000 is «مئة ألف وألف», not «مئة وواحد ألف».
  if (lastTwo == 1 || lastTwo == 2) {
    return '${_scaled(n - lastTwo, scale, last: false)} و'
        '${_scaled(lastTwo, scale, last: last)}';
  }
  if (lastTwo >= 3 && lastTwo <= 10) return '${_below1000(n)} ${scale.few}';
  if (lastTwo >= 11) return '${_below1000(n)} ${last ? scale.one : scale.many}';
  return '${_below1000(n, beforeNoun: true)} ${scale.one}';
}

const _units = [
  '',
  'واحد',
  'اثنان',
  'ثلاثة',
  'أربعة',
  'خمسة',
  'ستة',
  'سبعة',
  'ثمانية',
  'تسعة',
];
const _teens = [
  'عشرة',
  'أحد عشر',
  'اثنا عشر',
  'ثلاثة عشر',
  'أربعة عشر',
  'خمسة عشر',
  'ستة عشر',
  'سبعة عشر',
  'ثمانية عشر',
  'تسعة عشر',
];
const _tens = [
  '',
  '',
  'عشرون',
  'ثلاثون',
  'أربعون',
  'خمسون',
  'ستون',
  'سبعون',
  'ثمانون',
  'تسعون',
];
const _hundreds = [
  '',
  'مئة',
  'مئتان',
  'ثلاثمئة',
  'أربعمئة',
  'خمسمئة',
  'ستمئة',
  'سبعمئة',
  'ثمانمئة',
  'تسعمئة',
];

/// [n] below a thousand. [beforeNoun]: a noun follows it directly, so a
/// closing «مئتان» joins it: «مئتا ألف», «مئتا ريال».
String _below1000(int n, {bool beforeNoun = false}) {
  final words = <String>[];
  final h = n ~/ 100;
  final r = n % 100;
  if (h > 0) words.add(h == 2 && r == 0 && beforeNoun ? 'مئتا' : _hundreds[h]);
  if (r >= 10 && r < 20) {
    words.add(_teens[r - 10]);
  } else if (r > 0) {
    final u = r % 10;
    final t = r ~/ 10;
    if (u > 0 && t >= 2) {
      words.add('${_units[u]} و${_tens[t]}');
    } else if (u > 0) {
      words.add(_units[u]);
    } else {
      words.add(_tens[t]);
    }
  }
  return words.join(' و');
}
