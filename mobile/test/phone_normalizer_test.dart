import 'package:aarast_mobile/core/utils/phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeYemenPhone', () {
    test('keeps full international numbers', () {
      expect(normalizeYemenPhone('+967712345678'), '+967712345678');
    });

    test('normalizes local Yemen mobile numbers', () {
      expect(normalizeYemenPhone('712345678'), '+967712345678');
      expect(normalizeYemenPhone('967712345678'), '+967712345678');
      expect(normalizeYemenPhone('00967712345678'), '+967712345678');
    });

    test('normalizes Arabic and Persian digits', () {
      expect(normalizeYemenPhone('٧١٢٣٤٥٦٧٨'), '+967712345678');
      expect(normalizeYemenPhone('۷۱۲۳۴۵۶۷۸'), '+967712345678');
    });
  });
}
