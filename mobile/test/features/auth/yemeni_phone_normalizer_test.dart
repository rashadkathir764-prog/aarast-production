import 'package:aarast_mobile/features/auth/utils/yemeni_phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeYemeniPhone', () {
    const expected = '+967777758200';

    test('accepts local and international Yemen phone formats', () {
      expect(normalizeYemeniPhone('777758200'), expected);
      expect(normalizeYemeniPhone('0777758200'), expected);
      expect(normalizeYemeniPhone('967777758200'), expected);
      expect(normalizeYemeniPhone('+967777758200'), expected);
      expect(normalizeYemeniPhone('00967777758200'), expected);
    });

    test('accepts Arabic and Eastern Arabic digits', () {
      expect(normalizeYemeniPhone('٧٧٧٧٥٨٢٠٠'), expected);
      expect(normalizeYemeniPhone('۰۷۷۷۷۵۸۲۰۰'), expected);
    });

    test('rejects invalid or duplicated country-code inputs', () {
      expect(() => normalizeYemeniPhone(''), throwsFormatException);
      expect(
        () => normalizeYemeniPhone('+966777758200'),
        throwsFormatException,
      );
      expect(
        () => normalizeYemeniPhone('+967967777758200'),
        throwsFormatException,
      );
    });
  });
}
