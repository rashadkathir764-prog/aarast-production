import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OTP delivery truth contract', () {
    test('DELIVERED is the only confirmed WhatsApp delivery status', () {
      expect(_result('DELIVERED').isDeliveryConfirmed, isTrue);
      expect(_result('PENDING').isDeliveryConfirmed, isFalse);
      expect(_result('UNCERTAIN').isDeliveryConfirmed, isFalse);
      expect(
        _result('LOCAL_DEV', delivery: 'LOCAL_DEV').isDeliveryConfirmed,
        isFalse,
      );
    });

    test('PENDING and UNCERTAIN cannot surface a stale success message', () {
      for (final status in const ['PENDING', 'UNCERTAIN']) {
        final result = _result(status, message: 'تم إرسال الرمز وتسليمه.');

        expect(result.noticeMessage, contains('ما تأكدنا إنه وصل'));
        expect(result.noticeMessage, isNot(contains('تم إرسال')));
        expect(result.noticeMessage, isNot(contains('تسليمه')));
      }
    });

    test('legacy WhatsApp responses default to PENDING, never delivered', () {
      final result = OtpRequestResult.fromJson({
        'phone': '+967777123456',
        'purpose': 'LOGIN',
        'expiresAt': '2026-07-18T12:00:00.000Z',
        'delivery': 'WHATSAPP',
      });

      expect(result.deliveryStatus, 'PENDING');
      expect(result.isDeliveryConfirmed, isFalse);
      expect(result.noticeMessage, contains('ما تأكدنا إنه وصل'));
    });

    test(
      'local development keeps its explicit code without claiming delivery',
      () {
        final result = OtpRequestResult.fromJson({
          'phone': '+967777123456',
          'purpose': 'LOGIN',
          'expiresAt': '2026-07-18T12:00:00.000Z',
          'delivery': 'LOCAL_DEV',
          'deliveryStatus': 'LOCAL_DEV',
          'code': '123456',
          'message': 'رمز محلي: 123456',
        });

        expect(result.isLocalDev, isTrue);
        expect(result.isDeliveryConfirmed, isFalse);
        expect(result.noticeMessage, 'رمز محلي: 123456');
      },
    );
  });
}

OtpRequestResult _result(
  String deliveryStatus, {
  String delivery = 'WHATSAPP',
  String? message,
}) {
  return OtpRequestResult(
    phone: '+967777123456',
    purpose: 'LOGIN',
    expiresAt: DateTime.utc(2026, 7, 18, 12),
    delivery: delivery,
    deliveryStatus: deliveryStatus,
    message: message,
  );
}
