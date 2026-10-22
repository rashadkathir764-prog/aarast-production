/// Spells an amount in spoken Yemeni Arabic, under amount fields, so a zero
/// too many or too few is seen before saving: 350000 is
/// «ثلاثمية وخمسين ألف ريال».
String amountInWords(int amount, {String currency = 'ريال'}) {
  if (amount <= 0) return 'صفر $currency';
  final parts = <String>[];
  final millions = amount ~/ 1000000;
  final thousands = (amount % 1000000) ~/ 1000;
  final rest = amount % 1000;
  if (millions > 0) parts.add(_scaled(millions, 'مليون', 'مليونين', 'مليون'));
  if (thousands > 0) parts.add(_scaled(thousands, 'ألف', 'ألفين', 'آلاف'));
  if (rest > 0) parts.add(_below1000(rest));
  return '${parts.join(' و')} $currency';
}

/// «ألف», «ألفين», «ثلاثة آلاف», «مية ألف»; millions say «ثلاثة مليون».
String _scaled(int n, String one, String two, String few) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n <= 10) return '${_below1000(n)} $few';
  return '${_below1000(n)} $one';
}

const _units = [
  '',
  'واحد',
  'اثنين',
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
  'عشرين',
  'ثلاثين',
  'أربعين',
  'خمسين',
  'ستين',
  'سبعين',
  'ثمانين',
  'تسعين',
];
const _hundreds = [
  '',
  'مية',
  'ميتين',
  'ثلاثمية',
  'أربعمية',
  'خمسمية',
  'ستمية',
  'سبعمية',
  'ثمانمية',
  'تسعمية',
];

String _below1000(int n) {
  final words = <String>[];
  if (n >= 100) words.add(_hundreds[n ~/ 100]);
  final r = n % 100;
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
