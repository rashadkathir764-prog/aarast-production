import 'package:aarast_mobile/core/utils/amount_words.dart';
import 'package:flutter_test/flutter_test.dart';

// D129: the amount under a field is spelt in Modern Standard Arabic.
void main() {
  test('spells the amounts the design shows', () {
    expect(amountInWords(3000000), 'ثلاثة ملايين ريال');
    expect(amountInWords(500000), 'خمسمئة ألف ريال');
    expect(amountInWords(350000), 'ثلاثمئة وخمسون ألف ريال');
    expect(amountInWords(150000), 'مئة وخمسون ألف ريال');
    expect(amountInWords(400000), 'أربعمئة ألف ريال');
    expect(amountInWords(800000), 'ثمانمئة ألف ريال');
    expect(amountInWords(600000), 'ستمئة ألف ريال');
    expect(amountInWords(60000), 'ستون ألف ريال');
    expect(amountInWords(20000), 'عشرون ألف ريال');
  });

  test('handles ones, twos, teens and mixed amounts', () {
    expect(amountInWords(0), 'صفر ريال');
    expect(amountInWords(1000), 'ألف ريال');
    expect(amountInWords(2000), 'ألفا ريال');
    expect(amountInWords(3000), 'ثلاثة آلاف ريال');
    expect(amountInWords(1000000), 'مليون ريال');
    expect(amountInWords(2000000), 'مليونا ريال');
    expect(amountInWords(15000000), 'خمسة عشر مليون ريال');
    expect(amountInWords(1250000), 'مليون ومئتان وخمسون ألف ريال');
    expect(amountInWords(1150000), 'مليون ومئة وخمسون ألف ريال');
    expect(amountInWords(2500), 'ألفان وخمسمئة ريال');
    expect(amountInWords(25000), 'خمسة وعشرون ألف ريال');
    expect(
      amountInWords(3600, currency: 'ريال سعودي'),
      'ثلاثة آلاف وستمئة ريال سعودي',
    );
  });

  test('a scale word that more follows is counted on its own', () {
    expect(amountInWords(15250000), 'خمسة عشر مليونًا ومئتان وخمسون ألف ريال');
    expect(amountInWords(2500000), 'مليونان وخمسمئة ألف ريال');
    expect(amountInWords(25500), 'خمسة وعشرون ألفًا وخمسمئة ريال');
  });

  test('two hundred joins the noun after it', () {
    expect(amountInWords(200000), 'مئتا ألف ريال');
    expect(amountInWords(200), 'مئتا ريال');
    expect(amountInWords(250000), 'مئتان وخمسون ألف ريال');
  });

  test('a hundred and one thousand is a hundred thousand and a thousand', () {
    expect(amountInWords(101000), 'مئة ألف وألف ريال');
    expect(amountInWords(102000), 'مئة ألف وألفا ريال');
    expect(amountInWords(103000), 'مئة وثلاثة آلاف ريال');
  });
}
