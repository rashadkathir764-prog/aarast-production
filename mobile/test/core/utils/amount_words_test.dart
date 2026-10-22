import 'package:aarast_mobile/core/utils/amount_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('spells the amounts the design shows', () {
    expect(amountInWords(3000000), 'ثلاثة مليون ريال');
    expect(amountInWords(500000), 'خمسمية ألف ريال');
    expect(amountInWords(350000), 'ثلاثمية وخمسين ألف ريال');
    expect(amountInWords(150000), 'مية وخمسين ألف ريال');
    expect(amountInWords(400000), 'أربعمية ألف ريال');
    expect(amountInWords(800000), 'ثمانمية ألف ريال');
    expect(amountInWords(600000), 'ستمية ألف ريال');
    expect(amountInWords(60000), 'ستين ألف ريال');
    expect(amountInWords(20000), 'عشرين ألف ريال');
  });

  test('handles ones, twos, teens and mixed amounts', () {
    expect(amountInWords(0), 'صفر ريال');
    expect(amountInWords(1000), 'ألف ريال');
    expect(amountInWords(2000), 'ألفين ريال');
    expect(amountInWords(3000), 'ثلاثة آلاف ريال');
    expect(amountInWords(1000000), 'مليون ريال');
    expect(amountInWords(2000000), 'مليونين ريال');
    expect(amountInWords(15000000), 'خمسة عشر مليون ريال');
    expect(amountInWords(1250000), 'مليون وميتين وخمسين ألف ريال');
    expect(amountInWords(1150000), 'مليون ومية وخمسين ألف ريال');
    expect(amountInWords(2500), 'ألفين وخمسمية ريال');
    expect(amountInWords(25000), 'خمسة وعشرين ألف ريال');
    expect(
      amountInWords(3600, currency: 'ريال سعودي'),
      'ثلاثة آلاف وستمية ريال سعودي',
    );
  });
}
