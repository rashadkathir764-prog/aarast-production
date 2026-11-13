import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-109: a code asked again within the minute was refused by the server
// (`OTP_LIMIT_COOLDOWN`), though the first was still good. That refusal now
// leads to the code screen for it.
//
// RA-MO-308: the minute is per number, whoever asked and for whatever
// purpose, and a code is good only for its own purpose. The screen opens
// only for a code this phone itself got for the same number and purpose
// within the minute; otherwise the server's refusal stands, so the screen
// never calls the right code wrong.

const _phone = '+967777123456';

const _cooldown = ApiException(
  'يتاح رمز جديد بعد دقيقة.',
  statusCode: 429,
  serverCode: 'OTP_LIMIT_COOLDOWN',
  retryAfterSeconds: 42,
);

final _start = DateTime(2026, 11, 14, 10);

OtpRequestResult _sent(String purpose, {String phone = _phone}) =>
    OtpRequestResult(
      phone: phone,
      purpose: purpose,
      expiresAt: _start.add(const Duration(minutes: 10)),
      delivery: 'WHATSAPP',
      deliveryStatus: 'DELIVERED',
    );

void main() {
  late DateTime now;

  setUp(() => now = _start);

  Future<(AuthController, _ScriptedRepository)> controller(
    List<Object> answers,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final api = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _ScriptedRepository(api, storage, answers);
    return (AuthController(repository, clock: () => now), repository);
  }

  void expectRefused(AuthController auth, OtpRequestResult? otp) {
    expect(otp, isNull);
    expect(auth.errorCode, 'OTP_LIMIT_COOLDOWN');
    expect(auth.errorMessage, 'يتاح رمز جديد بعد دقيقة.');
  }

  test(
    'a sign-in code asked again within the minute opens the first',
    () async {
      final (auth, _) = await controller([_sent('LOGIN'), _cooldown]);
      final first = await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

      now = now.add(const Duration(seconds: 20));
      final otp = await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

      expect(otp, isNotNull);
      expect(otp!.phone, _phone);
      expect(otp.purpose, 'LOGIN');
      expect(otp.expiresAt, first!.expiresAt);
      expect(otp.noticeMessage, contains('لسا شغال'));
      expect(auth.otpRequest, same(otp));
      expect(auth.errorMessage, isNull);
      expect(auth.errorCode, isNull);
    },
  );

  test(
    'a sign-up code asked again within the minute opens the first',
    () async {
      final (auth, _) = await controller([_sent('REGISTER'), _cooldown]);
      await auth.startRegistration(name: 'سلمى', phone: _phone);

      now = now.add(const Duration(seconds: 20));
      final otp = await auth.startRegistration(name: 'سلمى', phone: _phone);

      expect(otp?.purpose, 'REGISTER');
      expect(auth.errorMessage, isNull);
    },
  );

  test('a code of another purpose is not opened: the refusal stands', () async {
    // A password reset asked a moment ago, then a sign-in: the code in
    // WhatsApp is the reset's, and the sign-in screen would call it wrong.
    final (auth, _) = await controller([_sent('RESET_PASSWORD'), _cooldown]);
    await auth.requestOtp(phone: _phone, purpose: 'RESET_PASSWORD');

    now = now.add(const Duration(seconds: 20));
    final otp = await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

    expectRefused(auth, otp);
    expect(auth.otpRequest?.purpose, 'RESET_PASSWORD');
  });

  // RA-MO-109's own case: the system closed the app while the person was in
  // WhatsApp. The request in memory is gone; the mark kept on the phone
  // still says this phone asked for this number and purpose.
  test(
    'after the app was closed, the code this phone asked for opens',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AuthStorage(await SharedPreferences.getInstance());
      final api = ApiClient(tokenProvider: storage.readAccessToken);
      final before = AuthController(
        _ScriptedRepository(api, storage, [_sent('LOGIN')]),
        clock: () => now,
      );
      await before.requestOtp(phone: _phone, purpose: 'LOGIN');

      now = now.add(const Duration(seconds: 25));
      final after = AuthController(
        _ScriptedRepository(api, storage, [_cooldown, _cooldown]),
        clock: () => now,
      );
      final otp = await after.requestOtp(phone: _phone, purpose: 'LOGIN');
      expect(otp?.purpose, 'LOGIN');
      expect(after.errorMessage, isNull);

      // Another purpose after the restart is still the server's refusal.
      expectRefused(
        after,
        await after.requestOtp(phone: _phone, purpose: 'RESET_PASSWORD'),
      );
    },
  );

  test('nothing asked from this phone (someone else asked): '
      'the refusal stands', () async {
    final (auth, _) = await controller([_cooldown, _cooldown]);

    expectRefused(auth, await auth.requestOtp(phone: _phone, purpose: 'LOGIN'));
    expectRefused(
      auth,
      await auth.startRegistration(name: 'سلمى', phone: _phone),
    );
  });

  test('a code asked for another number is not opened', () async {
    final (auth, _) = await controller([
      _sent('LOGIN', phone: '+967777000111'),
      _cooldown,
    ]);
    await auth.requestOtp(phone: '+967777000111', purpose: 'LOGIN');

    now = now.add(const Duration(seconds: 20));
    expectRefused(auth, await auth.requestOtp(phone: _phone, purpose: 'LOGIN'));
  });

  test('past the minute the refusal is someone else\'s: it stands, and '
      'asking again inside the minute does not lengthen it', () async {
    final (auth, _) = await controller([_sent('LOGIN'), _cooldown, _cooldown]);
    await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

    now = now.add(const Duration(seconds: 50));
    expect(await auth.requestOtp(phone: _phone, purpose: 'LOGIN'), isNotNull);

    now = now.add(const Duration(seconds: 15));
    expectRefused(auth, await auth.requestOtp(phone: _phone, purpose: 'LOGIN'));
  });

  test('a code the server already took is not opened again', () async {
    final (auth, _) = await controller([_sent('VERIFY_PHONE'), _cooldown]);
    await auth.requestOtp(phone: _phone, purpose: 'VERIFY_PHONE');
    expect(
      await auth.verifyOtp(phone: _phone, purpose: 'VERIFY_PHONE', code: '1'),
      isTrue,
    );

    now = now.add(const Duration(seconds: 20));
    expectRefused(
      auth,
      await auth.requestOtp(phone: _phone, purpose: 'VERIFY_PHONE'),
    );
  });

  test('any other refusal still stops with its own words', () async {
    final (auth, _) = await controller([
      _sent('LOGIN'),
      const ApiException(
        'هذا الرقم طلب 5 رموز في ساعة. يتاح رمز جديد بعد 40 دقيقة.',
        statusCode: 429,
        serverCode: 'OTP_LIMIT_PHONE_HOUR',
      ),
    ]);
    await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

    final otp = await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

    expect(otp, isNull);
    expect(auth.errorCode, 'OTP_LIMIT_PHONE_HOUR');
    expect(auth.errorMessage, contains('40 دقيقة'));
  });
}

/// Answers each code request in turn: a sent code, or a refusal.
class _ScriptedRepository extends AuthRepository {
  _ScriptedRepository(super.apiClient, super.authStorage, this.answers);

  final List<Object> answers;

  Future<OtpRequestResult> _next() async {
    final answer = answers.removeAt(0);
    if (answer is ApiException) throw answer;
    return answer as OtpRequestResult;
  }

  @override
  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) => _next();

  @override
  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
  }) => _next();

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async => OtpVerifyResult(verified: true, phone: phone, purpose: purpose);
}
