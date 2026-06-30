import 'package:flutter_test/flutter_test.dart';
import 'package:aarast_mobile/core/utils/arabic_number_formatter.dart';

void main() {
  group('ArabicNumberFormatter', () {
    test('converts basic numbers', () {
      expect(ArabicNumberFormatter.toArabicWords(0), 'صفر');
      expect(ArabicNumberFormatter.toArabicWords(1), 'واحد');
      expect(ArabicNumberFormatter.toArabicWords(15), 'خمسة عشر');
      expect(ArabicNumberFormatter.toArabicWords(42), 'اثنان وأربعون');
      expect(ArabicNumberFormatter.toArabicWords(100), 'مائة');
      expect(ArabicNumberFormatter.toArabicWords(101), 'مائة وواحد');
      expect(
        ArabicNumberFormatter.toArabicWords(345),
        'ثلاثمائة وخمسة وأربعون',
      );
    });

    test('converts thousands', () {
      expect(ArabicNumberFormatter.toArabicWords(1000), 'ألف');
      expect(ArabicNumberFormatter.toArabicWords(2000), 'ألفان');
      expect(ArabicNumberFormatter.toArabicWords(3000), 'ثلاثة آلاف');
      expect(ArabicNumberFormatter.toArabicWords(15000), 'خمسة عشر ألف');
    });

    test('converts millions', () {
      expect(ArabicNumberFormatter.toArabicWords(1000000), 'مليون');
      expect(ArabicNumberFormatter.toArabicWords(2000000), 'مليونان');
      expect(ArabicNumberFormatter.toArabicWords(3000000), 'ثلاثة ملايين');
      expect(
        ArabicNumberFormatter.toArabicWords(12500000),
        'اثنا عشر مليونًا وخمسمائة ألف',
      );
    });
  });
}
