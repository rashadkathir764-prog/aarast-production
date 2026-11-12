import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'OTP delivery requests use the transport-safe receive timeout only',
    () async {
      final harness = await _AuthHarness.create(_OtpResponseAdapter());

      await harness.repository.startRegistration(
        name: 'مستخدم جديد',
        phone: '777123456',
      );
      await harness.repository.requestOtp(phone: '777123456', purpose: 'LOGIN');
      await harness.repository.requestPasswordReset(phone: '777123456');

      final adapter = harness.adapter as _OtpResponseAdapter;
      expect(adapter.requests.map((request) => request.path), [
        '/api/v1/auth/register',
        '/api/v1/auth/otp/request',
        '/api/v1/auth/password-reset/request',
      ]);
      expect(
        adapter.requests.map((request) => request.receiveTimeout),
        everyElement(const Duration(seconds: 25)),
      );

      await expectLater(
        harness.repository.login(phone: '777123456', password: 'secret123'),
        throwsA(isA<ApiException>()),
      );
      expect(adapter.requests.last.path, '/api/v1/auth/login');
      expect(adapter.requests.last.receiveTimeout, const Duration(seconds: 12));
    },
  );

  test('registration timeout reports an operation-specific message', () async {
    final harness = await _AuthHarness.create(_ReceiveTimeoutAdapter());
    final controller = AuthController(harness.repository);

    final result = await controller.startRegistration(
      name: 'مستخدم جديد',
      phone: '777123456',
    );

    expect(result, isNull);
    expect(
      controller.errorMessage,
      'ما قدرنا نرسل رمز الحساب الجديد. تأكد من النت وجرّب مرة ثانية.',
    );
  });

  test('OTP timeout reports an operation-specific message', () async {
    final harness = await _AuthHarness.create(_ReceiveTimeoutAdapter());
    final controller = AuthController(harness.repository);

    final result = await controller.requestOtp(
      phone: '777123456',
      purpose: 'LOGIN',
    );

    expect(result, isNull);
    expect(
      controller.errorMessage,
      'ما قدرنا نرسل الرمز. تأكد من النت وجرّب مرة ثانية.',
    );
  });

  test('registration reports an unavailable OTP service precisely', () async {
    final harness = await _AuthHarness.create(_OtpUnavailableAdapter());
    final controller = AuthController(harness.repository);

    final result = await controller.startRegistration(
      name: 'مستخدم جديد',
      phone: '777123456',
    );

    expect(result, isNull);
    expect(controller.errorCode, 'OTP_DELIVERY_UNAVAILABLE');
    expect(
      controller.errorMessage,
      'ما قدرنا نرسل الرمز على واتساب. تأكد إن الرقم صحيح وعليه واتساب، وجرّب مرة ثانية.',
    );
  });

  test('OTP login request reports an unavailable service precisely', () async {
    final harness = await _AuthHarness.create(_OtpUnavailableAdapter());
    final controller = AuthController(harness.repository);

    final result = await controller.requestOtp(
      phone: '777123456',
      purpose: 'LOGIN',
    );

    expect(result, isNull);
    expect(controller.errorCode, 'OTP_DELIVERY_UNAVAILABLE');
    expect(
      controller.errorMessage,
      'ما قدرنا نرسل الرمز على واتساب. تأكد إن الرقم صحيح وعليه واتساب، وجرّب مرة ثانية.',
    );
  });
}

class _AuthHarness {
  const _AuthHarness({required this.repository, required this.adapter});

  final AuthRepository repository;
  final HttpClientAdapter adapter;

  static Future<_AuthHarness> create(HttpClientAdapter adapter) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final client = ApiClient(tokenProvider: storage.readAccessToken);
    client.dio.httpClientAdapter = adapter;
    return _AuthHarness(
      repository: AuthRepository(client, storage),
      adapter: adapter,
    );
  }
}

class _OtpResponseAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/api/v1/auth/login') {
      return _jsonResponse({'message': 'not used'}, statusCode: 400);
    }
    return _jsonResponse({
      'phone': '+967777123456',
      'purpose': options.path == '/api/v1/auth/password-reset/request'
          ? 'RESET_PASSWORD'
          : options.path == '/api/v1/auth/register'
          ? 'REGISTER'
          : 'LOGIN',
      'expiresAt': '2026-07-13T12:05:00.000Z',
      'delivery': 'WHATSAPP',
    });
  }

  ResponseBody _jsonResponse(
    Map<String, Object?> value, {
    int statusCode = 200,
  }) {
    return ResponseBody.fromString(
      jsonEncode(value),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ReceiveTimeoutAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _OtpUnavailableAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'statusCode': 503,
        'code': 'OTP_DELIVERY_UNAVAILABLE',
        'message': 'OTP delivery is temporarily unavailable',
      }),
      503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
