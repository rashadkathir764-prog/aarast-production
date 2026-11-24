import '../../../core/experience_v3/aarast_journey_profile.dart'
    show ReaderVoice;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/server_reachability.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/session/session_teardown_coordinator.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/utils/app_clock.dart';
import '../models/auth_otp.dart';
import '../models/auth_response.dart';
import '../../../core/session/safe_user.dart';

/// w05: the word typed to confirm the deletion.
const accountDeletionConfirmWord = 'حذف';

class AuthRepository implements SessionAuthTeardownPort {
  const AuthRepository(this._apiClient, this._authStorage);

  static const _otpDeliveryReceiveTimeout = Duration(seconds: 25);

  /// How long a session refresh waits for the server's answer (Q15).
  static const refreshReceiveTimeout = Duration(seconds: 30);

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  void bindClientSession(String? userId) {
    _apiClient.bindSessionIdentity(userId);
  }

  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    final sessionEpoch = _authStorage.beginSessionEstablishment();
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson('/api/v1/auth/login', {
        'phone': normalizedPhone,
        'password': password,
      });
      final response = _parseAuthResponse(json, operation: 'login');
      await _authStorage.saveSessionAtEpoch(
        expectedEpoch: sessionEpoch,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return response;
    } on Object {
      await _clearFailedSessionIntent(sessionEpoch);
      rethrow;
    }
  }

  Future<OtpRequestResult> startRegistration({
    required String name,
    required String phone,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/register',
      {'name': name, 'phone': normalizedPhone},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  /// D75: adds the app password, or changes it with [currentPassword].
  ///
  /// RA-BE-133: a change signs the other phones out and drops their push
  /// registrations; [pushInstallationId] is this phone's, which stays.
  Future<void> setPassword({
    required String newPassword,
    String? currentPassword,
    String? currentCode,
    String? pushInstallationId,
  }) async {
    await _apiClient.postJson('/api/v1/auth/password', {
      'newPassword': newPassword,
      'currentPassword': ?currentPassword,
      // RA-BE-141: the first password comes with a code to this number.
      'currentCode': ?currentCode,
      'pushInstallationId': ?pushInstallationId,
    });
  }

  Future<AuthResponse> register({
    required String name,
    required String phone,
    String? otpCode,
    String? phoneProof,
  }) async {
    final sessionEpoch = _authStorage.beginSessionEstablishment();
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson('/api/v1/auth/register/complete', {
        'name': name,
        'phone': normalizedPhone,
        if (phoneProof != null)
          'phoneProof': phoneProof
        else
          'otpCode': otpCode,
      });
      final response = _parseAuthResponse(json, operation: 'register');
      await _authStorage.saveSessionAtEpoch(
        expectedEpoch: sessionEpoch,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
      return response;
    } on Object {
      await _clearFailedSessionIntent(sessionEpoch);
      rethrow;
    }
  }

  Future<SafeUser> me() async {
    final sessionEpoch = _authStorage.sessionEpoch;
    final json = await _apiClient.getJson('/api/v1/auth/me');
    final user = SafeUser.fromJson(json);
    await _authStorage.saveUserIfEpoch(user, sessionEpoch);
    return user;
  }

  Future<OtpRequestResult> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/otp/request',
      {'phone': normalizedPhone, 'purpose': purpose},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  /// V1 checklist 4.14: a code to the number the account moves to.
  Future<OtpRequestResult> requestPhoneChange(String newPhone) async {
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/phone-change/request',
      {'phone': normalizeYemeniPhone(newPhone)},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  /// RA-BE-141: a code on WhatsApp to the account's current number, the
  /// proof the phone change (without the password) and the first password
  /// need.
  Future<OtpRequestResult> requestCurrentPhoneCode() async {
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/current-phone-code',
      const {},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  /// Moves the account; the server ends every session of it. RA-BE-141:
  /// with one proof that the account's holder asks it, [currentCode] (the
  /// current number's code) or [currentPassword].
  Future<void> confirmPhoneChange(
    String newPhone,
    String code, {
    String? currentCode,
    String? currentPassword,
  }) async {
    await _apiClient.postJson('/api/v1/auth/phone-change/confirm', {
      'phone': normalizeYemeniPhone(newPhone),
      'code': code.trim(),
      'currentCode': ?currentCode?.trim(),
      'currentPassword': ?currentPassword,
    });
  }

  Future<OtpRequestResult> requestInviteOtp({
    required String token,
    required String phone,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/invites/${Uri.encodeComponent(token)}/request-otp',
      {'phone': normalizedPhone},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    if (json['accountSetupRequired'] is! bool) {
      throw ApiException(
        ReaderVoice.say(
          'صار خطأ عندنا. جرّب مرة ثانية.',
          'صار خطأ عندنا. جرّبي مرة ثانية.',
        ),
      );
    }
    return OtpRequestResult.fromJson(json);
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    final establishesSession = purpose == 'LOGIN';
    final sessionEpoch = establishesSession
        ? _authStorage.beginSessionEstablishment()
        : _authStorage.sessionEpoch;
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson('/api/v1/auth/otp/verify', {
        'phone': normalizedPhone,
        'purpose': purpose,
        'code': code,
      });
      final response = OtpVerifyResult.fromJson(json);
      if (establishesSession) {
        if (!response.hasDurableSession) {
          throw ApiException(
            ReaderVoice.say(
              'ما قدرنا نكمل دخولك، وما حفظنا شي ناقص على الجوال. جرّب مرة ثانية.',
              'ما قدرنا نكمل دخولك، وما حفظنا شي ناقص على الجوال. جرّبي مرة ثانية.',
            ),
          );
        }
        final saved = await _saveOtpSession(
          response,
          expectedEpoch: sessionEpoch,
          reservedEpoch: true,
        );
        if (!saved) {
          throw ApiException(
            ReaderVoice.say(
              'تغيّر الدخول قبل ما نحفظه. جرّب مرة ثانية.',
              'تغيّر الدخول قبل ما نحفظه. جرّبي مرة ثانية.',
            ),
          );
        }
      } else if (response.accessToken != null &&
          response.refreshToken != null &&
          response.user != null) {
        await _authStorage.saveSessionIfEpoch(
          expectedEpoch: sessionEpoch,
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken!,
          user: response.user!,
        );
      } else if (response.user != null) {
        await _authStorage.saveUserIfEpoch(response.user!, sessionEpoch);
      }
      return response;
    } on Object {
      if (establishesSession) {
        await _clearFailedSessionIntent(sessionEpoch);
      }
      rethrow;
    }
  }

  Future<OtpVerifyResult> verifyInviteOtp({
    required String token,
    required String phone,
    required String code,
    String? name,
    String? password,
  }) async {
    final sessionEpoch = _authStorage.beginSessionEstablishment();
    try {
      final normalizedPhone = normalizeYemeniPhone(phone);
      final json = await _apiClient.postJson(
        '/api/v1/invites/${Uri.encodeComponent(token)}/verify-otp',
        {
          'phone': normalizedPhone,
          'code': code,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      final response = OtpVerifyResult.fromJson(json);
      if (!response.hasDurableSession) {
        throw ApiException(
          ReaderVoice.say(
            'ما قدرنا نكمل دخولك للخطة، وما حفظنا شي ناقص على الجوال. جرّب مرة ثانية.',
            'ما قدرنا نكمل دخولك للخطة، وما حفظنا شي ناقص على الجوال. جرّبي مرة ثانية.',
          ),
        );
      }
      final saved = await _saveOtpSession(
        response,
        expectedEpoch: sessionEpoch,
        reservedEpoch: true,
      );
      if (!saved) {
        throw ApiException(
          ReaderVoice.say(
            'تغيّر الدخول قبل ما نحفظه. جرّب مرة ثانية.',
            'تغيّر الدخول قبل ما نحفظه. جرّبي مرة ثانية.',
          ),
        );
      }
      return response;
    } on Object {
      await _clearFailedSessionIntent(sessionEpoch);
      rethrow;
    }
  }

  /// يطلب رمز استعادة كلمة المرور. الخادم لا يكشف وجود الحساب من عدمه.
  Future<OtpRequestResult> requestPasswordReset({required String phone}) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    final json = await _apiClient.postJsonWithReceiveTimeout(
      '/api/v1/auth/password-reset/request',
      {'phone': normalizedPhone},
      receiveTimeout: _otpDeliveryReceiveTimeout,
    );
    return OtpRequestResult.fromJson(json);
  }

  /// يؤكد الاستعادة بالرمز وكلمة المرور الجديدة — الخادم يستهلك الرمز
  /// ويبطل كل الجلسات القائمة، فيبقى الدخول بكلمة المرور الجديدة فقط.
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final normalizedPhone = normalizeYemeniPhone(phone);
    await _apiClient.postJson('/api/v1/auth/password-reset/confirm', {
      'phone': normalizedPhone,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<String?> readAccessToken() => _authStorage.readAccessToken();

  /// RA-MO-109: the last code this phone asked for, kept past a closed app.
  Future<void> rememberCodeRequest({
    required String phone,
    required String purpose,
    required DateTime at,
  }) =>
      _authStorage.rememberCodeRequest(phone: phone, purpose: purpose, at: at);

  CodeRequestMark? recalledCodeRequest() => _authStorage.recalledCodeRequest();

  Future<void> forgetCodeRequest() => _authStorage.forgetCodeRequest();

  /// Notes a code request on this phone before it is sent, so whatever
  /// becomes of its answer the code it may have sent can still be reached.
  /// Every flow that asks for a code goes through it; [CodeRequestNote.settle]
  /// decides what a failed request leaves behind.
  ///
  /// The note is readable at once ([recalledCodeRequest]); its write to
  /// the phone's storage is not awaited, so the request leaves without
  /// waiting for it.
  ///
  /// [boundTo] is what the server ties the code to beyond the number and
  /// the purpose (an invite's code is that invite's alone). The note keeps
  /// a digest of it, so a code is never reopened for another invite and
  /// the invite's token is not written a second time on the phone.
  CodeRequestNote noteCodeRequest({
    required String phone,
    required String purpose,
    required DateTime at,
    String? boundTo,
  }) {
    final earlier = recalledCodeRequest();
    final notedAs = boundTo == null
        ? purpose
        : '$purpose:${sha256.convert(utf8.encode(boundTo)).toString().substring(0, 16)}';
    unawaited(rememberCodeRequest(phone: phone, purpose: notedAs, at: at));
    return CodeRequestNote._(
      this,
      phone: phone,
      purpose: purpose,
      notedAs: notedAs,
      at: at,
      earlier: earlier,
    );
  }

  Future<bool> refreshSession() async {
    final sessionEpoch = _authStorage.sessionEpoch;
    final refreshToken = await _authStorage.readRefreshTokenIfEpoch(
      sessionEpoch,
    );
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      // The server rotates the refresh token as soon as it accepts this
      // request, and treats a second use of the old one as theft. If a slow
      // network made the app stop waiting after the server rotated, the next
      // refresh would end the session (field test Q15), so this request waits
      // longer than ordinary reads.
      final json = await _apiClient.postJsonWithReceiveTimeout(
        '/api/v1/auth/refresh',
        {'refreshToken': refreshToken},
        receiveTimeout: refreshReceiveTimeout,
      );
      final response = _parseAuthResponse(json, operation: 'refresh');
      return _authStorage.saveSessionIfEpoch(
        expectedEpoch: sessionEpoch,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );
    } on ApiException catch (error) {
      if (!error.isUnauthorized) rethrow;
      await _authStorage.clearIfEpoch(sessionEpoch);
      return false;
    }
  }

  SafeUser? readCachedUser() => _authStorage.readUser();

  Future<bool> _saveOtpSession(
    OtpVerifyResult response, {
    required int expectedEpoch,
    bool reservedEpoch = false,
  }) async {
    if (response.accessToken != null &&
        response.refreshToken != null &&
        response.user != null) {
      if (reservedEpoch) {
        return _authStorage.saveSessionAtEpoch(
          expectedEpoch: expectedEpoch,
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken!,
          user: response.user!,
        );
      } else {
        return _authStorage.saveSessionIfEpoch(
          expectedEpoch: expectedEpoch,
          accessToken: response.accessToken!,
          refreshToken: response.refreshToken!,
          user: response.user!,
        );
      }
    } else if (response.user != null) {
      return _authStorage.saveUserIfEpoch(response.user!, expectedEpoch);
    }
    return false;
  }

  Future<SafeUser> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final sessionEpoch = _authStorage.sessionEpoch;
    try {
      final ticket = await _apiClient
          .postJson('/api/v1/media/uploads/presign', {
            'purpose': 'user-avatar',
            'fileName': fileName,
            'contentType': contentType,
            'byteSize': bytes.length,
          });
      final uploadUrl = ticket['uploadUrl']?.toString() ?? '';
      final key = ticket['key']?.toString() ?? '';
      if (uploadUrl.isEmpty || key.isEmpty) {
        throw const ApiException('ما قدرنا نجهّز الصورة للرفع.');
      }
      await _apiClient.putBytes(uploadUrl, bytes, contentType: contentType);
      final verified = await _apiClient.postJson(
        '/api/v1/media/uploads/verify',
        {'key': key, 'purpose': 'user-avatar'},
      );
      final publicUrl = verified['publicUrl']?.toString() ?? '';
      if (publicUrl.isEmpty) {
        throw const ApiException('ما قدرنا نتأكد من الصورة اللي رفعتها.');
      }
      final user = SafeUser.fromJson(
        await _apiClient.patchJson('/api/v1/users/me', {
          'avatarUrl': publicUrl,
        }),
      );
      await _authStorage.saveUserIfEpoch(user, sessionEpoch);
      return user;
    } on ApiException catch (error) {
      if (error.statusCode == 503 ||
          error.message.toLowerCase().contains('media storage')) {
        throw ApiException(
          ReaderVoice.say(
            'رفع الصور مش متاح الحين. جرّب بعد شوي.',
            'رفع الصور مش متاح الحين. جرّبي بعد شوي.',
          ),
          statusCode: 503,
        );
      }
      rethrow;
    }
  }

  /// D63 (w05): the account will be erased after its 30 days. Returns the
  /// day it was asked and the day of the erasure.
  Future<({DateTime requestedAt, DateTime scheduledFor})>
  requestAccountDeletion() async {
    final response = await _apiClient.postJson('/api/v1/users/me/deletion', {
      'confirmWord': accountDeletionConfirmWord,
    });
    final requestedAt = DateTime.tryParse('${response['requestedAt']}');
    final scheduledFor = DateTime.tryParse('${response['scheduledFor']}');
    if (response['status'] != 'PENDING' ||
        requestedAt == null ||
        scheduledFor == null) {
      throw const FormatException(
        'Account deletion response did not confirm the request',
      );
    }
    return (requestedAt: requestedAt, scheduledFor: scheduledFor);
  }

  /// D63 (w06 «تراجعت، رجّع حسابي»): the request is taken back.
  Future<void> cancelAccountDeletion() async {
    final response = await _apiClient.deleteJson('/api/v1/users/me/deletion');
    if (response['status'] != 'NONE') {
      throw const FormatException(
        'Account deletion response did not confirm the take-back',
      );
    }
  }

  @override
  SessionAuthTeardownLease beginSessionTeardown(String userId) {
    return SessionAuthTeardownLease(
      userId: userId,
      storageEpoch: _authStorage.beginSessionInvalidation(),
    );
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {
    final accessToken = await _authStorage.readAccessTokenIfEpoch(
      lease.storageEpoch,
    );
    final refreshToken = await _authStorage.readRefreshTokenIfEpoch(
      lease.storageEpoch,
    );
    lease.captureCredentials(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    // RA-BE-129: the access token lives 15 minutes. Past that, the server
    // refused the sign-out and the device's notice unregistering, so the
    // refresh token stayed alive on the server for 30 days and the phone
    // kept the account's notices. An expired one is traded here, in memory
    // only, for a fresh pair that both requests then carry; the phone's own
    // copy is cleared right after, as before. Offline or refused, the old
    // pair stays and the sign-out on the phone goes on.
    if (refreshToken == null || refreshToken.isEmpty) return;
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !accessTokenExpired(accessToken, now: appNow())) {
      return;
    }
    try {
      final json = await _apiClient
          .postJsonWithReceiveTimeout('/api/v1/auth/refresh', {
            'refreshToken': refreshToken,
          }, receiveTimeout: teardownRefreshTimeout)
          .timeout(teardownRefreshTimeout);
      final fresh = _parseAuthResponse(json, operation: 'teardown_refresh');
      lease.captureCredentials(
        accessToken: fresh.accessToken,
        refreshToken: fresh.refreshToken,
      );
    } on Object {
      // The old pair stays captured; the sign-out on the phone goes on.
    }
  }

  /// How long a sign-out waits to trade an expired access token: inside the
  /// teardown's own two seconds for capturing the credentials.
  static const teardownRefreshTimeout = Duration(milliseconds: 1500);

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {
    final cleared = await _authStorage.clearTerminatingSessionAtEpoch(
      lease.storageEpoch,
    );
    if (!cleared) {
      throw StateError(
        'The session epoch changed before local teardown completed',
      );
    }
  }

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {
    final refreshToken = lease.refreshTokenForRemoteTeardown;
    if (refreshToken == null || refreshToken.isEmpty) return;
    final accessToken = lease.accessTokenForRemoteTeardown;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Remote logout credentials are incomplete');
    }
    await _apiClient.postJsonWithBearer(
      '/api/v1/auth/logout',
      {'refreshToken': refreshToken},
      bearerToken: accessToken,
      cancelToken: cancelToken,
    );
  }

  Future<void> logout() async {
    final userId = _authStorage.readUser()?.id ?? 'unknown-session';
    final lease = beginSessionTeardown(userId);
    await captureRemoteCredentials(lease);
    await clearLocalSession(lease);
    final cancelToken = CancelToken();
    try {
      await revokeRemoteSession(
        lease,
        cancelToken: cancelToken,
      ).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      cancelToken.cancel('Session teardown deadline reached');
    } on Object {
      // Local logout must always complete, even when the network is down.
    } finally {
      lease.clearSensitiveCredentials();
    }
  }

  Future<void> _clearFailedSessionIntent(int sessionEpoch) async {
    try {
      await _authStorage.clearIfEpoch(sessionEpoch);
    } on Object {
      // Preserve the original authentication failure. A later restore still
      // treats the reserved epoch as unauthenticated.
    }
  }

  AuthResponse _parseAuthResponse(
    Map<String, dynamic> json, {
    required String operation,
  }) {
    try {
      return AuthResponse.fromJson(json);
    } on Object catch (error) {
      appLogEvent(
        'AUTH_RESPONSE_PARSE_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        reason: 'invalid_auth_response_shape',
        source: 'AuthRepository.parseAuthResponse',
        attributes: {
          'operation': operation,
          'errorType': error.runtimeType.toString(),
        },
      );
      throw ApiException(
        ReaderVoice.say(
          'ما قدرنا نقرأ رد الدخول. جرّب مرة ثانية.',
          'ما قدرنا نقرأ رد الدخول. جرّبي مرة ثانية.',
        ),
      );
    }
  }
}

/// Whether a signed access token's `exp` has passed (with half a minute to
/// spare for the trip), read without checking the signature: only to know
/// whether to trade it first (RA-BE-129). One that cannot be read is taken
/// as live, and the request finds out.
@visibleForTesting
bool accessTokenExpired(String token, {required DateTime now}) {
  final parts = token.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return false;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).round(),
      isUtc: true,
    );
    return !now.toUtc().add(const Duration(seconds: 30)).isBefore(expiresAt);
  } on Object {
    return false;
  }
}

/// One code request noted on this phone before it was sent ([phone] as
/// typed, [purpose], [at]), with the note it replaced ([earlier]).
///
/// RA-MO-109, RA-MO-308: a refusal to send another code within the
/// server's minute (`OTP_LIMIT_COOLDOWN`) reopens the code screen only for
/// a code this phone itself asked for, for the same number and purpose,
/// under a minute ago; never for another number's code or another
/// purpose's.
class CodeRequestNote {
  CodeRequestNote._(
    this._repository, {
    required this.phone,
    required this.purpose,
    required this.notedAs,
    required this.at,
    required this.earlier,
  });

  final AuthRepository _repository;
  final String phone;

  /// The server's purpose, as the code screen reads it.
  final String purpose;

  /// What the phone's note says of this request: [purpose], with what the
  /// code is bound to when there is something (an invite).
  final String notedAs;
  final DateTime at;
  final CodeRequestMark? earlier;

  /// The server sends one code per number a minute, whoever asks and for
  /// whatever purpose (`PHONE_COOLDOWN` in
  /// `backend/src/modules/identity/internal/auth/otp-dispatch-quota.service.ts`).
  static const cooldown = Duration(minutes: 1);

  /// What the code screen opens after [error] ended this request, or null
  /// when [error] stands. Leaves the note saying what is now true.
  ///
  /// [earlierResult] is the answer this phone got for its earlier request,
  /// when it still has it; it fills in what the note does not keep.
  OtpRequestResult? settle(Object error, {OtpRequestResult? earlierResult}) {
    if (error is ApiException && error.serverCode == 'OTP_LIMIT_COOLDOWN') {
      // This request made no code; an earlier one may still be live.
      _restoreEarlier();
      return _reopenEarlier(earlierResult);
    }
    if (error is ApiException && error.isNetworkFailure) {
      switch (_fateOf(error)) {
        case _RequestFate.neverLeft:
          _restoreEarlier();
          return null;
        case _RequestFate.leftWithoutAnswer:
          return OtpRequestResult(
            phone: phone.trim(),
            purpose: purpose,
            // Not known without the answer; the code screen does not read it.
            expiresAt: at,
            delivery: 'WHATSAPP',
            deliveryStatus: 'UNCERTAIN',
            message: otpLostAnswerNotice,
          );
        case _RequestFate.unknown:
          // It may have left: the note stays, so the next tap's cooldown
          // reopens the code screen.
          return null;
      }
    }
    if (error is FormatException) {
      // The number was refused on the phone, before anything was sent.
      _restoreEarlier();
      return null;
    }
    if (error is ApiException && _isServerRefusal(error)) {
      // The server answered and made no code for this request. A refused
      // delivery also ended the code it replaced for this number and purpose.
      final ended =
          error.serverCode == 'OTP_DELIVERY_UNAVAILABLE' &&
          _sameRequest(earlier);
      if (ended) {
        unawaited(_repository.forgetCodeRequest());
      } else {
        _restoreEarlier();
      }
      return null;
    }
    // An answer the phone could not read: the code may exist, the note stays.
    return null;
  }

  /// A 4xx, or a 5xx that names its reason, comes from the server itself.
  /// A bare 5xx may be a proxy's while the server went on and sent the code.
  static bool _isServerRefusal(ApiException error) {
    final status = error.statusCode;
    if (status == null) return false;
    return status < 500 || error.serverCode != null;
  }

  OtpRequestResult? _reopenEarlier(OtpRequestResult? earlierResult) {
    final mark = earlier;
    if (mark == null || !_sameRequest(mark)) return null;
    if (at.difference(mark.at) >= cooldown) return null;
    final known =
        earlierResult != null &&
            earlierResult.purpose == purpose &&
            _samePhone(earlierResult.phone, phone)
        ? earlierResult
        : null;
    return OtpRequestResult(
      phone: phone.trim(),
      purpose: purpose,
      // After a restart the code's expiry is not known; the code screen
      // does not read it.
      expiresAt: known?.expiresAt ?? mark.at,
      delivery: known?.delivery ?? 'WHATSAPP',
      deliveryStatus: known?.deliveryStatus ?? 'PENDING',
      accountSetupRequired: known?.accountSetupRequired ?? false,
      code: known?.code,
      message: otpEarlierCodeStillLiveNotice,
    );
  }

  bool _sameRequest(CodeRequestMark? mark) =>
      mark != null && mark.purpose == notedAs && _samePhone(mark.phone, phone);

  /// Puts back the note this request replaced: asking again never
  /// lengthens the earlier code's minute.
  void _restoreEarlier() {
    final mark = earlier;
    unawaited(
      mark == null
          ? _repository.forgetCodeRequest()
          : _repository.rememberCodeRequest(
              phone: mark.phone,
              purpose: mark.purpose,
              at: mark.at,
            ),
    );
  }

  static bool _samePhone(String a, String b) {
    try {
      return normalizeYemeniPhone(a) == normalizeYemeniPhone(b);
    } on FormatException {
      return false;
    }
  }

  /// Whether the request left the phone, from what the transport measured.
  ///
  /// A timeout is "left without an answer" only once the connection had
  /// opened: a connection that never opened sent nothing
  /// ([ApiException.connectionNeverOpened]).
  static _RequestFate _fateOf(ApiException error) {
    if (error.connectionNeverOpened) return _RequestFate.neverLeft;
    return switch (error.transportCause) {
      ReachabilityCause.noNetwork ||
      ReachabilityCause.dns ||
      ReachabilityCause.refused ||
      ReachabilityCause.tls => _RequestFate.neverLeft,
      ReachabilityCause.timeout ||
      ReachabilityCause.interrupted => _RequestFate.leftWithoutAnswer,
      ReachabilityCause.serverError ||
      ReachabilityCause.unknown ||
      null => _RequestFate.unknown,
    };
  }
}

enum _RequestFate { neverLeft, leftWithoutAnswer, unknown }
