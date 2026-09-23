import 'package:aarast_mobile/core/phone/yemeni_phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

// The `core/utils/phone_normalizer.dart` wrapper (`normalizeYemenPhone`) is
// dissolved (spec M6 fate map); it delegated to the same core function
// callers now import directly, so the same expectations run against it.
void main() {
  group('normalizeYemeniPhone', () {
    test('keeps full international numbers', () {
      expect(normalizeYemeniPhone('+967712345678'), '+967712345678');
    });

    test('normalizes local Yemen mobile numbers', () {
      expect(normalizeYemeniPhone('712345678'), '+967712345678');
      expect(normalizeYemeniPhone('967712345678'), '+967712345678');
      expect(normalizeYemeniPhone('00967712345678'), '+967712345678');
    });

    test('normalizes Arabic and Persian digits', () {
      expect(normalizeYemeniPhone('٧١٢٣٤٥٦٧٨'), '+967712345678');
      expect(normalizeYemeniPhone('۷۱۲۳۴۵۶۷۸'), '+967712345678');
    });
  });
}
