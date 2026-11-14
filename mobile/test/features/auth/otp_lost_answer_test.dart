import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_otp.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A code was asked for; WhatsApp delivered it, but the server's answer never
// reached the phone. The phone said it could not reach the server and never
// opened the code screen, and the next tap was refused within the minute.
//
// The request is noted before it is sent. A request that never left forgets
// its note and says so; one that left without an answer opens the code
// screen with an honest notice; when it is not known whether it left, the
// note stays so the next tap's cooldown reopens the code screen. RA-MO-308's
// safety holds throughout: same number, same purpose, under one minute.

const _phone = '+967777123456';
const _otherPhone = '+967777000111';

const _cooldown = ApiException(
  'يتاح رمز جديد بعد دقيقة.',
  statusCode: 429,
  serverCode: 'OTP_LIMIT_COOLDOWN',
  retryAfterSeconds: 42,
);

/// The request left; its answer did not come back (a receive timeout).
const _lostAnswer = ApiException(
  'ما وصلنا للخادم في الوقت.',
  isNetworkFailure: true,
  transportCause: ReachabilityCause.timeout,
);

/// The request never left the phone.
const _noNetwork = ApiException(
  'ما في نت.',
  isNetworkFailure: true,
  transportCause: ReachabilityCause.noNetwork,
);

/// A transport failure whose kind is not known: it may have left.
const _unknownFailure = ApiException(
  'ما وصلنا للخادم. تأكد من النت وجرّب مرة ثانية.',
  isNetworkFailure: true,
  transportCause: ReachabilityCause.unknown,
);

const _deliveryUnavailable = ApiException(
  'ما قدرنا نرسل الرمز على واتساب.',
  statusCode: 503,
  serverCode: 'OTP_DELIVERY_UNAVAILABLE',
);

final _start = DateTime(2026, 11, 14, 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late AuthStorage storage;
  late ApiClient api;

  setUp(() async {
    now = _start;
    SharedPreferences.setMockInitialValues({});
    storage = AuthStorage(await SharedPreferences.getInstance());
    api = ApiClient(tokenProvider: storage.readAccessToken);
  });

  (AuthController, _ScriptedRepository) controller(List<Object> answers) {
    final repository = _ScriptedRepository(api, storage, answers);
    return (AuthController(repository, clock: () => now), repository);
  }

  void expectLostAnswerOpened(
    AuthController auth,
    OtpRequestResult? otp, {
    required String purpose,
  }) {
    expect(otp, isNotNull);
    expect(otp!.phone, _phone);
    expect(otp.purpose, purpose);
    expect(otp.isDeliveryConfirmed, isFalse);
    expect(otp.noticeMessage, contains('ما وصلنا رد'));
    expect(otp.noticeMessage, isNot(contains('الخادم')));
    expect(auth.otpRequest, same(otp));
    expect(auth.errorMessage, isNull);
    expect(auth.errorCode, isNull);
    expect(auth.failedOffline, isFalse);
  }

  void expectReopened(
    AuthController auth,
    OtpRequestResult? otp, {
    required String purpose,
  }) {
    expect(otp, isNotNull, reason: 'the code already sent is reopened');
    expect(otp!.purpose, purpose);
    expect(otp.noticeMessage, contains('لسا شغال'));
    expect(auth.errorMessage, isNull);
    expect(auth.errorCode, isNull);
  }

  void expectRefused(AuthController auth, OtpRequestResult? otp) {
    expect(otp, isNull);
    expect(auth.errorCode, 'OTP_LIMIT_COOLDOWN');
    expect(auth.errorMessage, 'يتاح رمز جديد بعد دقيقة.');
  }

  group('through the real network client', () {
    test('a receive timeout opens the code screen with an honest notice, '
        'and keeps the note', () async {
      final repository = AuthRepository(
        api..dio.httpClientAdapter = _FailingAdapter.receiveTimeout(),
        storage,
      );
      final auth = AuthController(repository, clock: () => now);

      final otp = await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

      expectLostAnswerOpened(auth, otp, purpose: 'LOGIN');
      final note = storage.recalledCodeRequest();
      expect(note?.phone, _phone);
      expect(note?.purpose, 'LOGIN');
      expect(note?.at.isAtSameMomentAs(_start), isTrue);
    });

    test(
      'no connection keeps the no-internet message and forgets the note',
      () async {
        final repository = AuthRepository(
          api..dio.httpClientAdapter = _FailingAdapter.hostLookup(),
          storage,
        );
        final auth = AuthController(repository, clock: () => now);

        final otp = await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

        expect(otp, isNull);
        expect(auth.failedOffline, isTrue);
        expect(
          auth.errorMessage,
          'ما قدرنا نرسل الرمز. تأكد من النت وجرّب مرة ثانية.',
        );
        expect(storage.recalledCodeRequest(), isNull);
      },
    );

    // The connection never opened, so nothing was asked of the server and
    // no code exists: the code screen must not open on a promise of one.
    test('a connection that never opened is not taken for a lost answer, '
        'and forgets the note', () async {
      final repository = AuthRepository(
        api..dio.httpClientAdapter = _FailingAdapter.connectTimeout(),
        storage,
      );
      final auth = AuthController(repository, clock: () => now);

      final otp = await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

      expect(otp, isNull);
      expect(auth.otpRequest, isNull);
      expect(auth.failedOffline, isTrue);
      expect(storage.recalledCodeRequest(), isNull);
    });

    test('the note is written before the request is sent', () async {
      final adapter = _HeldAdapter();
      final repository = AuthRepository(
        api..dio.httpClientAdapter = adapter,
        storage,
      );
      final auth = AuthController(repository, clock: () => now);

      final pending = auth.startRegistration(name: 'سلمى', phone: _phone);
      await adapter.called.future;
      final note = storage.recalledCodeRequest();
      expect(note?.purpose, 'REGISTER');
      expect(note?.phone, _phone);

      // A second tap while the first waits sends nothing.
      expect(await auth.startRegistration(name: 'سلمى', phone: _phone), isNull);
      adapter.release();
      expect((await pending)?.purpose, 'REGISTER');
      expect(adapter.calls, 1);
    });
  });

  group('the next tap after a request whose fate is not known', () {
    test('sign-in', () async {
      final (auth, _) = controller([_unknownFailure, _cooldown]);
      expect(await auth.requestOtp(phone: _phone, purpose: 'LOGIN'), isNull);
      expect(auth.failedOffline, isTrue);

      now = now.add(const Duration(seconds: 20));
      expectReopened(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
        purpose: 'LOGIN',
      );
    });

    test('registration and provider registration', () async {
      final (auth, _) = controller([_unknownFailure, _cooldown]);
      expect(await auth.startRegistration(name: 'سلمى', phone: _phone), isNull);

      now = now.add(const Duration(seconds: 20));
      expectReopened(
        auth,
        await auth.startRegistration(name: 'سلمى', phone: _phone),
        purpose: 'REGISTER',
      );
    });

    test('a resend from the code screen after a lost answer', () async {
      final (auth, _) = controller([_lostAnswer, _cooldown]);
      expectLostAnswerOpened(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'VERIFY_PHONE'),
        purpose: 'VERIFY_PHONE',
      );

      now = now.add(const Duration(seconds: 30));
      expectReopened(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'VERIFY_PHONE'),
        purpose: 'VERIFY_PHONE',
      );
    });

    test('an invite code', () async {
      final (auth, _) = controller([_unknownFailure, _cooldown]);
      expect(
        await auth.requestInviteOtp(token: 'invite-token', phone: _phone),
        isNull,
      );

      now = now.add(const Duration(seconds: 20));
      expectReopened(
        auth,
        await auth.requestInviteOtp(token: 'invite-token', phone: _phone),
        purpose: 'INVITE_ACCESS',
      );
    });

    // The code that moves the account to a new number is asked the same
    // way, from the sheet in «حسابي».
    test('a new number\'s code whose answer was lost opens the code '
        'step with the notice', () async {
      final (auth, _) = controller([_lostAnswer]);

      final asked = await auth.requestPhoneChange(_phone);

      expect(asked.error, isNull);
      expect(asked.notice, contains('ما وصلنا رد'));
    });

    test('a new number\'s code refused within the minute reopens the '
        'code step', () async {
      final (auth, _) = controller([_unknownFailure, _cooldown]);
      final first = await auth.requestPhoneChange(_phone);
      expect(first.error, isNotNull);

      now = now.add(const Duration(seconds: 20));
      final second = await auth.requestPhoneChange(_phone);

      expect(second.error, isNull);
      expect(second.notice, contains('لسا شغال'));
    });

    test('a new number\'s code with no connection stays on the number '
        'step', () async {
      final (auth, _) = controller([_noNetwork]);

      final asked = await auth.requestPhoneChange(_phone);

      expect(asked.error, 'ما في نت.');
      expect(asked.notice, isNull);
      expect(storage.recalledCodeRequest(), isNull);
    });

    test('a new number\'s code that was sent says nothing extra', () async {
      final (auth, _) = controller([
        OtpRequestResult(
          phone: _phone,
          purpose: 'PHONE_CHANGE',
          expiresAt: _start.add(const Duration(minutes: 5)),
          delivery: 'WHATSAPP',
          deliveryStatus: 'DELIVERED',
        ),
      ]);

      final asked = await auth.requestPhoneChange(_phone);

      expect(asked.error, isNull);
      expect(asked.notice, isNull);
    });

    // From the review of this branch: the server ties an invite's code to
    // that invite. The note kept only the number and «INVITE_ACCESS», so a
    // second invite for the same number, asked within the minute, reopened
    // the code screen for a code that belongs to the first.
    test('an invite code is never reopened for another invite', () async {
      final (auth, _) = controller([_unknownFailure, _cooldown]);
      expect(
        await auth.requestInviteOtp(token: 'invite-token-a', phone: _phone),
        isNull,
      );

      now = now.add(const Duration(seconds: 20));
      expectRefused(
        auth,
        await auth.requestInviteOtp(token: 'invite-token-b', phone: _phone),
      );
    });

    test(
      'an invite code is reopened for its own invite after a restart',
      () async {
        final (auth, _) = controller([_unknownFailure]);
        await auth.requestInviteOtp(token: 'invite-token-a', phone: _phone);

        // A new app: only what the phone's storage kept.
        now = now.add(const Duration(seconds: 20));
        final (reopened, _) = controller([_cooldown]);
        final otp = await reopened.requestInviteOtp(
          token: 'invite-token-a',
          phone: _phone,
        );
        expectReopened(reopened, otp, purpose: 'INVITE_ACCESS');
        // The invite's own token is not what the phone keeps.
        expect(
          storage.recalledCodeRequest()?.purpose,
          isNot(contains('invite-token-a')),
        );
      },
    );

    test('an invite code whose answer was lost opens the code', () async {
      final (auth, _) = controller([_lostAnswer]);
      expectLostAnswerOpened(
        auth,
        await auth.requestInviteOtp(token: 'invite-token', phone: _phone),
        purpose: 'INVITE_ACCESS',
      );
    });

    test('the app was closed and opened again within the minute', () async {
      final (before, _) = controller([_lostAnswer]);
      await before.requestOtp(phone: _phone, purpose: 'LOGIN');

      now = now.add(const Duration(seconds: 40));
      final (after, _) = controller([_cooldown]);
      expectReopened(
        after,
        await after.requestOtp(phone: _phone, purpose: 'LOGIN'),
        purpose: 'LOGIN',
      );
    });

    test('past the minute the refusal stands', () async {
      final (auth, _) = controller([_unknownFailure, _cooldown]);
      await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

      now = now.add(const Duration(seconds: 61));
      expectRefused(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
      );
    });

    test('another number is never reopened', () async {
      final (auth, _) = controller([_lostAnswer, _cooldown]);
      await auth.requestOtp(phone: _otherPhone, purpose: 'LOGIN');

      now = now.add(const Duration(seconds: 20));
      expectRefused(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
      );
    });

    test('another purpose is never reopened', () async {
      final (auth, _) = controller([_lostAnswer, _cooldown]);
      await auth.requestOtp(phone: _phone, purpose: 'RESET_PASSWORD');

      now = now.add(const Duration(seconds: 20));
      expectRefused(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
      );
    });

    test(
      'a refused second request does not lengthen the first one\'s minute',
      () async {
        final (auth, _) = controller([_lostAnswer, _cooldown, _cooldown]);
        await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

        now = now.add(const Duration(seconds: 50));
        expect(
          await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
          isNotNull,
        );

        now = now.add(const Duration(seconds: 15));
        expectRefused(
          auth,
          await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
        );
      },
    );
  });

  group('the note', () {
    test('a request that never left keeps the earlier code\'s note', () async {
      final (auth, _) = controller([_sent('LOGIN'), _noNetwork, _cooldown]);
      await auth.requestOtp(phone: _phone, purpose: 'LOGIN');

      now = now.add(const Duration(seconds: 10));
      expect(await auth.requestOtp(phone: _phone, purpose: 'LOGIN'), isNull);
      expect(
        storage.recalledCodeRequest()?.at.isAtSameMomentAs(_start),
        isTrue,
      );

      now = now.add(const Duration(seconds: 10));
      expectReopened(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
        purpose: 'LOGIN',
      );
    });

    test('a refusal that ends the code clears the note', () async {
      final (auth, _) = controller([_deliveryUnavailable, _cooldown]);
      expect(await auth.requestOtp(phone: _phone, purpose: 'LOGIN'), isNull);
      expect(auth.errorCode, 'OTP_DELIVERY_UNAVAILABLE');
      expect(storage.recalledCodeRequest(), isNull);

      now = now.add(const Duration(seconds: 20));
      expectRefused(
        auth,
        await auth.requestOtp(phone: _phone, purpose: 'LOGIN'),
      );
    });

    test('a verified code clears the note', () async {
      final (auth, _) = controller([_lostAnswer]);
      await auth.requestOtp(phone: _phone, purpose: 'VERIFY_PHONE');
      expect(
        await auth.verifyOtp(
          phone: _phone,
          purpose: 'VERIFY_PHONE',
          code: '123456',
        ),
        isTrue,
      );
      expect(storage.recalledCodeRequest(), isNull);
    });
  });
}

OtpRequestResult _sent(String purpose) => OtpRequestResult(
  phone: _phone,
  purpose: purpose,
  expiresAt: _start.add(const Duration(minutes: 10)),
  delivery: 'WHATSAPP',
  deliveryStatus: 'DELIVERED',
);

/// Answers each code request in turn: a sent code, or a failure.
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
  Future<OtpRequestResult> requestInviteOtp({
    required String token,
    required String phone,
  }) => _next();

  @override
  Future<OtpRequestResult> requestPhoneChange(String newPhone) => _next();

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async => OtpVerifyResult(verified: true, phone: phone, purpose: purpose);
}

class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this._error);

  _FailingAdapter.receiveTimeout()
    : this(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

  _FailingAdapter.connectTimeout()
    : this(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );

  _FailingAdapter.hostLookup()
    : this(
        (options) => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Failed host lookup: api.example'),
        ),
      );

  final DioException Function(RequestOptions options) _error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => Future.error(_error(options));

  @override
  void close({bool force = false}) {}
}

/// Holds the server's answer until the test releases it.
class _HeldAdapter implements HttpClientAdapter {
  final called = Completer<void>();
  final _answer = Completer<void>();
  int calls = 0;

  void release() => _answer.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (!called.isCompleted) called.complete();
    await _answer.future;
    return ResponseBody.fromString(
      jsonEncode({
        'phone': _phone,
        'purpose': 'REGISTER',
        'expiresAt': '2026-11-14T10:10:00.000Z',
        'delivery': 'WHATSAPP',
        'deliveryStatus': 'DELIVERED',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
