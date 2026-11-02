import 'package:aarast_mobile/core/phone/yemeni_phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

// D75: one rule for a typed phone number on every entry screen.
void main() {
  test('empty asks for the number, in the field own words', () {
    expect(yemeniPhoneInputError(''), 'رقم الجوال مطلوب');
    expect(
      yemeniPhoneInputError('  ', empty: 'اكتب الرقم اللي وصلتك عليه الدعوة'),
      'اكتب الرقم اللي وصلتك عليه الدعوة',
    );
  });

  test('a wrong number says so; a right one, grouped or not, passes', () {
    expect(yemeniPhoneInputError('123'), 'رقم الجوال غير صحيح');
    expect(yemeniPhoneInputError('777 123 456'), isNull);
    expect(yemeniPhoneInputError('777123456'), isNull);
  });
}
