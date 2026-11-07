import 'package:aarast_mobile/core/forms/latin_digits_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _type(TextInputFormatter formatter, String text) =>
    formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );

void main() {
  // A WhatsApp code, a guest count or a price typed on an Arabic keyboard
  // («٥٠٠٠٠٠») vanished under `digitsOnly`, and the field stayed empty.
  test('Arabic-Indic and Eastern digits become 0-9; anything else is dropped', () {
    const digits = LatinDigitsFormatter();
    expect(_type(digits, '١٢٣٤٥٦').text, '123456');
    expect(_type(digits, '۱۲۳').text, '123');
    expect(_type(digits, '12 ٣-4').text, '1234');
    expect(_type(digits, '1.5').text, '15', reason: 'no decimals by default');
    expect(_type(digits, '٥٠٠').selection.baseOffset, 3);
  });

  test('a price keeps one decimal point and its two digits', () {
    const price = LatinDigitsFormatter(decimals: 2);
    expect(_type(price, '٥٠٠٠٠٠').text, '500000');
    expect(_type(price, '٢٥٠٫٧٥').text, '250.75');
    expect(_type(price, '1.234').text, '1.23');
    expect(_type(price, '1.2.3').text, '1.23');
  });

  test('the money fields read the same digits', () {
    for (var i = 0; i < 10; i++) {
      expect(latinDigitOf(0x0660 + i), 0x30 + i);
      expect(latinDigitOf(0x06F0 + i), 0x30 + i);
    }
    expect(latinDigitOf('a'.codeUnitAt(0)), isNull);
  });
}
