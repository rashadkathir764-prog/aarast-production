import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('marketplace provider error copy', () {
    test('backend routing failures use the required connection copy', () {
      expect(
        marketplaceErrorMessage('Cannot GET /providers'),
        aarastBackendConnectionErrorMessage,
      );
      expect(
        marketplaceErrorMessage('هذه الخدمة غير متاحة الآن.'),
        aarastBackendConnectionErrorMessage,
      );
    });

    test('auth errors are neutral, not feminine-only', () {
      final message = marketplaceErrorMessage(
        'بيانات الدخول غير صحيحة أو انتهت الجلسة.',
      );

      expect(message, 'تحتاج إلى تسجيل الدخول للمتابعة.');
      expect(message, isNot(contains('تحتاجين')));
    });
  });
}
