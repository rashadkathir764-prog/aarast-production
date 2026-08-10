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
