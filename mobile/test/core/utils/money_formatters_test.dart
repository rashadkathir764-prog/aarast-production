import 'package:aarast_mobile/core/utils/compact_money_figure.dart';
import 'package:aarast_mobile/core/utils/money_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

// The design critique's blockers (2026-11-14): «باقي 1.3 مليون» refused the
// 1,300,000 typed from it (م1), offers of 1,250,000 and 1,340,000 read alike
// (ب1), and rounded figures that did not add up (م2). One formatter, three
// ways.

void main() {
  test('full and sum-safe amounts preserve stored legacy fractions', () {
    for (final entry in <num, String>{
      1000.50: '1,000.5',
      700.25: '700.25',
      0.25: '0.25',
      -0.25: '-0.25',
    }.entries) {
      expect(
        fullMoneyParts(entry.key, currencyCode: 'YER').number,
        entry.value,
      );
      expect(
        sumSafeMoneyParts(entry.key, currencyCode: 'YER').number,
        entry.value,
      );
    }
    expect(fullMoneyFromText('700.25', 'YER'), contains('700.25'));
  });
  test('a record amount is written whole (م1)', () {
    expect(
      fullMoneyParts(1250000, currencyCode: 'YER').plainText,
      '1,250,000\u{00a0}ر.ي',
    );
    expect(
      fullMoneyParts(-450000, currencyCode: 'SAR').plainText,
      '-450,000\u{00a0}ر.س',
    );
    expect(
      stripMoneyDirectionalityMarks(
        formatFullMoney(999999, currencyCode: 'YER'),
      ),
      // Stripped for reading back: its no-break spaces become plain.
      '999,999 ر.ي',
    );
  });

  test('two offers that differ never read alike (ب1)', () {
    expect(
      fullMoneyFromText('1250000', 'YER'),
      isNot(fullMoneyFromText('1340000', 'YER')),
    );
    expect(fullMoneyFromText('1,250,000', null), '1,250,000\u{00a0}ر.ي');
    expect(fullMoneyFromText('', 'YER'), isNull);
    expect(fullMoneyFromText('abc', 'YER'), isNull);
  });

  test(
    'figures read together are shortened only when nothing is lost (م2)',
    () {
      expect(
        sumSafeMoneyParts(3000000, currencyCode: 'YER').plainText,
        '3\u{00a0}ملايين\u{00a0}ر.ي',
      );
      expect(
        sumSafeMoneyParts(1500000, currencyCode: 'YER').plainText,
        '1.5\u{00a0}مليون\u{00a0}ر.ي',
      );
      expect(
        sumSafeMoneyParts(1450000, currencyCode: 'YER').plainText,
        '1,450,000\u{00a0}ر.ي',
      );
      expect(
        sumSafeMoneyParts(800000, currencyCode: 'YER').plainText,
        '800,000\u{00a0}ر.ي',
      );
      expect(
        sumSafeMoneyFigure(1450000, currencyCode: 'YER'),
        contains('1,450,000'),
      );
      // The unit is kept on the figure's line (a no-break space).
      expect(
        sumSafeMoneyFigure(250000, currencyCode: 'YER'),
        allOf(startsWith('250'), endsWith('ألفًا')),
      );
      expect(
        sumSafeMoneyFigure(250050, currencyCode: 'YER'),
        contains('250,050'),
      );
    },
  );

  test('a short figure is counted by the number shown (D129)', () {
    String plain(num value) => stripMoneyDirectionalityMarks(
      formatCompactMoney(value, currencyCode: 'YER'),
    );
    // D136: the digits always lead; one and two are not said as words.
    expect(plain(1000000), '1 مليون ر.ي');
    expect(plain(2000000), '2 مليون ر.ي');
    expect(plain(3000000), '3 ملايين ر.ي');
    expect(plain(15000000), '15 مليونًا ر.ي');
    expect(plain(100000000), '100 مليون ر.ي');
    expect(plain(1500000), '1.5 مليون ر.ي');
    // The word beside digits a screen draws itself.
    CompactYemeniMoneyParts parts(num value) =>
        compactMoneyParts(value, currencyCode: 'YER');
    expect(parts(2000000).number, '2');
    expect(parts(2000000).millionUnit, 'مليون');
    expect(parts(4000000).millionUnit, 'ملايين');
    expect(parts(25000000).millionUnit, 'مليونًا');
    expect(parts(2000000).semanticText, '2 مليون ريال يمني');
    expect(parts(1000000).plainText, '1\u{00a0}مليون\u{00a0}ر.ي');
  });

  test('a headline keeps the short way', () {
    expect(
      compactMoneyParts(1250000, currencyCode: 'YER').plainText,
      '1.3\u{00a0}مليون\u{00a0}ر.ي',
    );
  });
}
