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

  // D112 (Q-12), the first step (the numbers of the Gulf themselves need
  // the server and WhatsApp to take them): a right number of another
  // country was told «رقم الجوال غير صحيح», which it is not. It is told
  // what the app takes.
  test('Q-12: a number of another country is told what the app takes', () {
    const yemenOnly = 'نقبل الأرقام اليمنية بس حاليًا.';
    for (final abroad in [
      '+966501234567',
      '00966 50 123 4567',
      '+971 50 123 4567',
      '+96891234567',
      '+201001234567',
    ]) {
      expect(yemeniPhoneInputError(abroad), yemenOnly, reason: abroad);
      expect(yemeniPhoneRefusal(abroad), yemenOnly, reason: abroad);
    }
    // A Yemeni number written wrong, or no country at all, is a wrong
    // number as before.
    for (final wrong in ['+967 77', '+9677771234567890', '0501234567', '12']) {
      expect(yemeniPhoneRefusal(wrong), 'رقم الجوال غير صحيح', reason: wrong);
    }
    expect(yemeniPhoneInputError('+967 777 123 456'), isNull);
  });
}
