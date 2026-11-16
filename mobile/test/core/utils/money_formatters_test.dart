import 'package:aarast_mobile/core/utils/compact_money_figure.dart';
import 'package:aarast_mobile/core/utils/money_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

// The design critique's blockers (2026-11-14): «باقي 1.3 مليون» refused the
// 1,300,000 typed from it (م1), offers of 1,250,000 and 1,340,000 read alike
// (ب1), and rounded figures that did not add up (م2). One formatter, three
// ways.

void main() {
  test('a record amount is written whole (م1)', () {
    expect(
      fullMoneyParts(1250000, currencyCode: 'YER').plainText,
      '1,250,000 ر.ي',
    );
    expect(
      fullMoneyParts(-450000, currencyCode: 'SAR').plainText,
      '-450,000 ر.س',
    );
    expect(
      stripMoneyDirectionalityMarks(
        formatFullMoney(999999, currencyCode: 'YER'),
      ),
      '999,999 ر.ي',
    );
  });

  test('two offers that differ never read alike (ب1)', () {
    expect(
      fullMoneyFromText('1250000', 'YER'),
      isNot(fullMoneyFromText('1340000', 'YER')),
    );
    expect(fullMoneyFromText('1,250,000', null), '1,250,000 ر.ي');
    expect(fullMoneyFromText('', 'YER'), isNull);
    expect(fullMoneyFromText('abc', 'YER'), isNull);
  });

  test(
    'figures read together are shortened only when nothing is lost (م2)',
    () {
      expect(
        sumSafeMoneyParts(3000000, currencyCode: 'YER').plainText,
        '3 مليون ر.ي',
      );
      expect(
        sumSafeMoneyParts(1500000, currencyCode: 'YER').plainText,
        '1.5 مليون ر.ي',
      );
      expect(
        sumSafeMoneyParts(1450000, currencyCode: 'YER').plainText,
        '1,450,000 ر.ي',
      );
      expect(
        sumSafeMoneyParts(800000, currencyCode: 'YER').plainText,
        '800,000 ر.ي',
      );
      expect(
        sumSafeMoneyFigure(1450000, currencyCode: 'YER'),
        contains('1,450,000'),
      );
      // The unit is kept on the figure's line (a no-break space).
      expect(
        sumSafeMoneyFigure(250000, currencyCode: 'YER'),
        allOf(startsWith('250'), endsWith('ألف')),
      );
      expect(
        sumSafeMoneyFigure(250050, currencyCode: 'YER'),
        contains('250,050'),
      );
    },
  );

  test('a headline keeps the short way', () {
    expect(
      compactMoneyParts(1250000, currencyCode: 'YER').plainText,
      '1.3 مليون ر.ي',
    );
  });
}
