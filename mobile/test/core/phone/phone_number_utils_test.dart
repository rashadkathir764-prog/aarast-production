import 'package:aarast_mobile/core/phone/phone_number_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumberUtils', () {
    const expected = '+967777758200';

    test('normalizes all supported Yemen mobile formats', () {
      expect(PhoneNumberUtils.normalizeOptional('777758200'), expected);
      expect(PhoneNumberUtils.normalizeOptional('0777758200'), expected);
      expect(PhoneNumberUtils.normalizeOptional('+967777758200'), expected);
      expect(PhoneNumberUtils.normalizeOptional('00967777758200'), expected);
    });

    test('converts Arabic and Persian digits before normalization', () {
      expect(PhoneNumberUtils.normalizeOptional('٧٧٧٧٥٨٢٠٠'), expected);
      expect(PhoneNumberUtils.normalizeOptional('۰۷۷۷۷۵۸۲۰۰'), expected);
    });

    test('removes common separators and produces a friendly display', () {
      final analysis = PhoneNumberUtils.analyze('(0777) 758-200');

      expect(analysis.normalizedPhone, expected);
      expect(analysis.displayPhone, '+967 777 758 200');
      expect(analysis.isValid, isTrue);
    });

    test('preserves a non-Yemen international number with warning state', () {
      final analysis = PhoneNumberUtils.analyze('+966 50 123 4567');

      expect(analysis.normalizedPhone, '+966501234567');
      expect(analysis.isWarning, isTrue);
      expect(analysis.message, PhoneNumberUtils.internationalWarningMessage);
    });

    test('rejects malformed Yemen and non-phone text', () {
      expect(PhoneNumberUtils.analyze('+967967777758200').isInvalid, isTrue);
      expect(PhoneNumberUtils.analyze('call-me').isInvalid, isTrue);
    });

    test('allows an empty optional phone', () {
      final analysis = PhoneNumberUtils.analyze('  ');

      expect(analysis.isEmpty, isTrue);
      expect(PhoneNumberUtils.normalizeOptional('  '), isNull);
    });
  });
}
