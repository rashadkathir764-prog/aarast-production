import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('marketplace provider error copy', () {
    test('backend routing failures use the required connection copy', () {
      expect(
        marketplaceErrorMessage('Cannot GET /providers'),
        aarastServerOlderMessage,
      );
      expect(
        marketplaceErrorMessage('هذه الخدمة غير متاحة الآن.'),
        aarastBackendConnectionErrorMessage,
      );
    });

    test('auth errors are neutral, not feminine-only', () {
      final message = marketplaceErrorMessage(
        'بيانات الدخول غلط أو انتهى دخولك.',
      );

      expect(message, 'سجّل دخول عشان تكمل.');
      expect(message, isNot(contains('تحتاجين')));
    });
    test('structured location errors are shown as Arabic user guidance', () {
      final message = marketplaceErrorMessage(
        'location governorate and cityOrDistrict are required for structured location',
      );

      expect(message, contains('كمّل موقع العرس'));
      expect(message, isNot(contains('governorate')));
      expect(message, isNot(contains('cityOrDistrict')));
    });
  });
}
