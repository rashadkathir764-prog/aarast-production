import 'package:aarast_mobile/features/finance/data/finance_money_rules.dart';
import 'package:aarast_mobile/features/finance/widgets/money_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = MoneyInputFormatter();

  test('groups money input while preserving two decimal places', () {
    expect(formatMoneyInputValue('10000000'), '10,000,000');
    expect(formatMoneyInputValue('1250000.50'), '1,250,000.50');
  });

  test('normalizes Arabic digits and ignores grouping separators', () {
    expect(formatMoneyInputValue('١٠٬٥٠٠٫٧٥'), '10,500.75');
    expect(formatMoneyInputValue('۱۲۰۰۰۰۰'), '1,200,000');
  });

  // RA-MO-113: the whole-riyal fields (the first run's budget and the mahr)
  // deleted the decimal point, so a pasted «5000000.00» became 500,000,000.
  group('whole amounts', () {
    String typed(String text) {
      return const MoneyInputFormatter(wholeOnly: true)
          .formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            ),
          )
          .text;
    }

    test('a pasted amount with a decimal tail is its whole part', () {
      expect(typed('5000000.00'), '5,000,000');
      expect(typed('5,000,000.50'), '5,000,000');
      expect(typed('٥٠٠٠٠٠٠٫٠٠'), '5,000,000');
    });

    // D86: twelve digits at most, where the server stops. A thirteenth was
    // taken and the plan then failed to save under another reason.
    test('a thirteenth digit is not taken', () {
      expect(typed('123456789012'), '123,456,789,012');
      expect(typed('1234567890123'), '');
      expect(
        FinanceMoneyRules.serverAmount.hasMatch(
          '9' * MoneyInputFormatter.maxWholeDigits,
        ),
        isTrue,
      );
      expect(
        FinanceMoneyRules.serverAmount.hasMatch(
          '9' * (MoneyInputFormatter.maxWholeDigits + 1),
        ),
        isFalse,
      );
    });

    test('a point typed alone never shows, and grouping points are '
        'grouping', () {
      expect(typed('5000000.'), '5,000,000');
      expect(typed('5.000.000'), '5,000,000');
      expect(typed('7000000'), '7,000,000');
    });
  });

  test('keeps the cursor aligned when grouping is inserted', () {
    final formatted = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '10000',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );

    expect(formatted.text, '10,000');
    expect(formatted.selection.baseOffset, 6);
  });
}
