import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid login stays private and offers safe recovery paths', () async {
    final harness = await _AuthHarness.create();
    harness.repository.loginFailure = const ApiException(
      'Invalid credentials',
      statusCode: 401,
      serverCode: 'INVALID_CREDENTIALS',
    );

    final success = await harness.controller.login(
      phone: '777123456',
      password: 'wrong-password',
    );

    expect(success, isFalse);
    expect(harness.controller.errorCode, 'INVALID_CREDENTIALS');
    expect(harness.controller.errorMessage, contains('نسيت كلمة المرور'));
    expect(harness.controller.errorMessage, contains('أنشئ حسابًا جديدًا'));
    expect(harness.controller.errorMessage, isNot(contains('لا يوجد حساب')));
  });

  test(
    'verified-phone guidance is not collapsed into wrong password',
    () async {
      final harness = await _AuthHarness.create();
      harness.repository.loginFailure = const ApiException(
        'Phone verification required',
        statusCode: 401,
        serverCode: 'PHONE_VERIFICATION_REQUIRED',
      );

      final success = await harness.controller.login(
        phone: '777123456',
        password: 'correct-password',
      );

      expect(success, isFalse);
      expect(harness.controller.errorCode, 'PHONE_VERIFICATION_REQUIRED');
      expect(harness.controller.errorMessage, contains('الدخول برمز تحقق'));
      expect(harness.controller.errorMessage, isNot(contains('غير صحيحة')));
    },
  );

  test('OTP service failure is not collapsed into wrong password', () async {
    final harness = await _AuthHarness.create();
    harness.repository.loginFailure = const ApiException(
      'OTP delivery is temporarily unavailable',
      statusCode: 503,
      serverCode: 'OTP_DELIVERY_UNAVAILABLE',
    );

    final success = await harness.controller.login(
      phone: '777123456',
      password: 'correct-password',
    );

    expect(success, isFalse);
    expect(harness.controller.errorCode, 'OTP_DELIVERY_UNAVAILABLE');
    expect(
      harness.controller.errorMessage,
      'تعذر إرسال رمز التحقق عبر واتساب. تأكد أن الرقم صحيح وعليه واتساب، ثم حاول مرة أخرى.',
    );
    expect(harness.controller.errorMessage, isNot(contains('كلمة المرور')));
  });

  test(
    'registration conflict is translated after phone ownership proof',
    () async {
      final harness = await _AuthHarness.create();
      harness.repository.registerFailure = const ApiException(
        'Phone or email already registered',
        statusCode: 409,
        serverCode: 'ACCOUNT_ALREADY_EXISTS',
      );

      final success = await harness.controller.register(
        name: 'مستخدم',
        phone: '777123456',
        otpCode: '123456',
      );

      expect(success, isFalse);
      expect(harness.controller.errorCode, 'ACCOUNT_ALREADY_EXISTS');
      expect(harness.controller.errorMessage, contains('عليه حساب من قبل'));
      expect(harness.controller.errorMessage, isNot(contains('Phone')));
    },
  );

  test(
    'admin app credential conflict uses app-specific Arabic guidance',
    () async {
      final harness = await _AuthHarness.create();
      harness.repository.registerFailure = const ApiException(
        'App password already set',
        statusCode: 409,
        serverCode: 'ADMIN_APP_PASSWORD_ALREADY_SET',
      );

      final success = await harness.controller.register(
        name: 'مشرف يستخدم التطبيق',
        phone: '777123456',
        otpCode: '123456',
      );

      expect(success, isFalse);
      expect(harness.controller.errorCode, 'ADMIN_APP_PASSWORD_ALREADY_SET');
      expect(harness.controller.errorMessage, contains('حساب التطبيق'));
      expect(harness.controller.errorMessage, contains('كلمة مرور التطبيق'));
    },
  );

  test(
    'OTP errors distinguish retry from safe post-proof registration',
    () async {
      final invalidHarness = await _AuthHarness.create();
      invalidHarness.repository.verifyFailure = const ApiException(
        'OTP code is invalid or expired',
        statusCode: 400,
        serverCode: 'OTP_INVALID_OR_EXPIRED',
      );

      expect(
        await invalidHarness.controller.verifyOtp(
          phone: '777123456',
          purpose: 'LOGIN',
          code: '111111',
        ),
        isFalse,
      );
      expect(invalidHarness.controller.errorMessage, contains('انتهى وقته'));

      final missingHarness = await _AuthHarness.create();
      missingHarness.repository.verifyFailure = const ApiException(
        'Account not found after phone proof',
        statusCode: 404,
        serverCode: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
      );

      expect(
        await missingHarness.controller.verifyOtp(
          phone: '777123456',
          purpose: 'LOGIN',
          code: '123456',
        ),
        isFalse,
      );
      expect(
        missingHarness.controller.errorCode,
        'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
      );
      expect(missingHarness.controller.errorMessage, contains('تم التحقق'));
      expect(missingHarness.controller.errorMessage, contains('أنشئ حسابًا'));
    },
  );
}

class _AuthHarness {
  const _AuthHarness({required this.controller, required this.repository});

  final AuthController controller;
  final _FailingAuthRepository repository;

  static Future<_AuthHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final client = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _FailingAuthRepository(client, storage);
    final controller = AuthController(repository);
    await controller.restoreSession();
    return _AuthHarness(controller: controller, repository: repository);
  }
}

class _FailingAuthRepository extends AuthRepository {
  _FailingAuthRepository(super.apiClient, super.authStorage);

  ApiException? loginFailure;
  ApiException? registerFailure;
  ApiException? verifyFailure;

  @override
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    throw loginFailure ?? StateError('loginFailure was not configured');
  }

  @override
  Future<AuthResponse> register({
    required String name,
    required String phone,
    String? otpCode,
    String? phoneProof,
  }) async {
    throw registerFailure ?? StateError('registerFailure was not configured');
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    throw verifyFailure ?? StateError('verifyFailure was not configured');
  }
}
