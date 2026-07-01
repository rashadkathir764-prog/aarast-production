class ArabicNumberFormatter {
  static const List<String> _ones = [
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

  static const List<String> _tens = [
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

  static const List<String> _hundreds = [
    '',
    'مائة',
    'مائتان',
    'ثلاثمائة',
    'أربعمائة',
    'خمسمائة',
    'ستمائة',
    'سبعمائة',
    'ثمانمائة',
    'تسعمائة',
  ];

  /// Converts an integer up to 999 to Arabic words
  static String _convertUnderOneThousand(int number) {
    if (number == 0) return '';

    String result = '';

    final int hundred = number ~/ 100;
    final int rest = number % 100;

    if (hundred > 0) {
      result += _hundreds[hundred];
    }

    if (rest > 0) {
      if (result.isNotEmpty) result += ' و';

      if (rest < 20) {
        result += _ones[rest];
      } else {
        final int ten = rest ~/ 10;
        final int one = rest % 10;

        if (one > 0) {
          result += '${_ones[one]} و${_tens[ten]}';
        } else {
          result += _tens[ten];
        }
      }
    }

    return result;
  }

  static String toArabicWords(int number) {
    if (number == 0) return 'صفر';
    if (number < 0) return 'سالب ${toArabicWords(-number)}';

    String result = '';

    // Billions
    final int billions = number ~/ 1000000000;
    number %= 1000000000;
    if (billions > 0) {
      if (billions == 1) {
        result += 'مليار';
      } else if (billions == 2) {
        result += 'ملياران';
      } else if (billions >= 3 && billions <= 10) {
        result += '${_convertUnderOneThousand(billions)} مليارات';
      } else {
        result += '${_convertUnderOneThousand(billions)} مليار';
      }
    }

    // Millions
    final int millions = number ~/ 1000000;
    number %= 1000000;
    if (millions > 0) {
      if (result.isNotEmpty) result += ' و';

      if (millions == 1) {
        result += 'مليون';
      } else if (millions == 2) {
        result += 'مليونان';
      } else if (millions >= 3 && millions <= 10) {
        result += '${_convertUnderOneThousand(millions)} ملايين';
      } else if (millions == 12) {
        result += 'اثنا عشر مليونًا';
      } else {
        result += '${_convertUnderOneThousand(millions)} مليون';
      }
    }

    // Thousands
    final int thousands = number ~/ 1000;
    number %= 1000;
    if (thousands > 0) {
      if (result.isNotEmpty) result += ' و';

      if (thousands == 1) {
        result += 'ألف';
      } else if (thousands == 2) {
        result += 'ألفان';
      } else if (thousands >= 3 && thousands <= 10) {
        result += '${_convertUnderOneThousand(thousands)} آلاف';
      } else {
        result += '${_convertUnderOneThousand(thousands)} ألف';
      }
    }

    // Rest (under 1000)
    if (number > 0) {
      if (result.isNotEmpty) result += ' و';
      result += _convertUnderOneThousand(number);
    }

    return result.trim();
  }
}
