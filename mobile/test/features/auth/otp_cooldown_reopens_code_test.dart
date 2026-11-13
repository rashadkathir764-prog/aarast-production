import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-109: the system closed the app while the person read the code in
// WhatsApp. The app opened at its start, the number was typed again, and
// the server refused a second code within the minute, though the first was
// still good. That refusal now leads to the code screen for it.

const _cooldown = ApiException(
  'يتاح رمز جديد بعد دقيقة.',
  statusCode: 429,
  serverCode: 'OTP_LIMIT_COOLDOWN',
  retryAfterSeconds: 42,
);

void main() {
  test(
    'a sign-in code asked again within the minute opens the first',
    () async {
      final auth = await _controller(_cooldown);

      final otp = await auth.requestOtp(
        phone: '+967777123456',
        purpose: 'LOGIN',
      );

      expect(otp, isNotNull);
      expect(otp!.phone, '+967777123456');
      expect(otp.purpose, 'LOGIN');
      expect(otp.noticeMessage, contains('لسا شغال'));
      expect(auth.errorMessage, isNull);
      expect(auth.errorCode, isNull);
    },
  );

  test(
    'a sign-up code asked again within the minute opens the first',
    () async {
      final auth = await _controller(_cooldown);

      final otp = await auth.startRegistration(
        name: 'سلمى',
        phone: '+967777123456',
      );

      expect(otp?.purpose, 'REGISTER');
      expect(auth.errorMessage, isNull);
    },
  );

  test('any other refusal still stops with its own words', () async {
    final auth = await _controller(
      const ApiException(
        'هذا الرقم طلب 5 رموز في ساعة. يتاح رمز جديد بعد 40 دقيقة.',
        statusCode: 429,
        serverCode: 'OTP_LIMIT_PHONE_HOUR',
      ),
    );

    final otp = await auth.requestOtp(phone: '+967777123456', purpose: 'LOGIN');

    expect(otp, isNull);
    expect(auth.errorCode, 'OTP_LIMIT_PHONE_HOUR');
    expect(auth.errorMessage, contains('40 دقيقة'));
  });
}

Future<AuthController> _controller(ApiException refusal) async {
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final api = ApiClient(tokenProvider: storage.readAccessToken);
  return AuthController(_RefusingRepository(api, storage, refusal));
}

class _RefusingRepository extends AuthRepository {
  _RefusingRepository(super.apiClient, super.authStorage, this.refusal);

  final ApiException refusal;

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async => throw refusal;

  @override
  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
  }) async => throw refusal;
}
