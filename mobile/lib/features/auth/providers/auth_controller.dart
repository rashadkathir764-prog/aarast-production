import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/session/session_teardown_coordinator.dart';
import '../../../core/utils/app_clock.dart';
import '../../onboarding/onboarding_api.dart' show GuestOnboardingStorage;
import '../data/auth_repository.dart';
import '../models/auth_otp.dart';
import '../../../core/session/safe_user.dart';

part 'auth_controller.sign_in.dart';
part 'auth_controller.session.dart';

enum AuthStatus {
  checking,
  authenticated,
  terminating,
  terminationFailed,
  unauthenticated,
}

final RegExp _privateInviteTokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

String? _validInviteToken(String? token) {
  final cleanToken = token?.trim();
  if (cleanToken == null || !_privateInviteTokenPattern.hasMatch(cleanToken)) {
    return null;
  }
  return cleanToken;
}

class AuthController extends _AuthControllerCore
    with _AuthSignIn, _AuthSession {
  AuthController(
    AuthRepository authRepository, {
    OfflineSyncService? offlineSyncService,
    GuestOnboardingStorage? guestOnboardingStorage,
    SessionTeardownCoordinator? sessionTeardownCoordinator,
    DateTime Function()? clock,
  }) : super(
         authRepository,
         offlineSyncService,
         clock ?? appNow,
         sessionTeardownCoordinator ??
             SessionTeardownCoordinator(
               auth: authRepository,
               clearLocalAccountData: () async {
                 await offlineSyncService?.clearLocalData();
               },
               clearLocalAccountDataKeepingUnsent: () async {
                 await offlineSyncService?.clearLocalData(
                   keepUnsentChanges: true,
                 );
               },
               clearGuestDraft: () async {
                 await guestOnboardingStorage?.clearDraft();
               },
             ),
       );

  AuthStatus get status => _status;

  SafeUser? get user => _user;

  /// D63: the signed-in account waits out its 30 days before erasure; the
  /// app shows only w06 until it is taken back.
  bool get deletionPending =>
      _status == AuthStatus.authenticated && _user?.deletionPending == true;

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  String? get errorCode => _errorCode;

  OtpRequestResult? get otpRequest => _otpRequest;

  bool get hasPendingInviteResume =>
      _status == AuthStatus.authenticated &&
      _pendingInviteResumeToken != null &&
      !_pendingInviteRouteClaimed;

  /// True right after a mid-session 401 invalidated the session. The UI
  /// redirects to login once, then acknowledges.
  bool get sessionExpired => _sessionExpired;

  /// This session began by creating the account (a08b «احفظ خطتي»), so a
  /// plan kept on the phone is saved without asking again: a new account
  /// has no other plan to weigh it against.
  bool get accountJustCreated => _accountJustCreated;

  /// The last request failed because the server could not be reached (no
  /// connection), not because it said no.
  bool get failedOffline => _failedOffline;

  /// D75: the last sign-up's code was for a number that already had an
  /// account, so it signed in to that account instead.
  bool get signUpFoundAccount => _signUpFoundAccount;

  /// The name on the account [signUpFoundAccount] entered, when the server
  /// said it; null otherwise.
  String? get signUpFoundAccountName =>
      _signUpFoundAccount ? _signUpFoundAccountName : null;

  /// What the last sign-in code proved about a number with no account (D75),
  /// for signing up with it; null otherwise, and null once the server no
  /// longer accepts it ([phoneProofLifetime]).
  String? get phoneProof => _freshPhoneProof;

  /// The server keeps a phone proof ten minutes
  /// (`backend/src/modules/identity/internal/auth/phone-proof.ts`); the
  /// phone stops offering it half a minute before, so a sign-up never
  /// sends one the server has already dropped and asks for a code instead.
  static const phoneProofLifetime = Duration(minutes: 9, seconds: 30);

  /// The proof for [phone] (as typed, normalised), or null when the last
  /// proof was for another number, is too old, or there is none.
  String? phoneProofFor(String phone) {
    final proof = _freshPhoneProof;
    final proven = _phoneProofPhone;
    if (proof == null || proven == null) return null;
    try {
      return normalizeYemeniPhone(proven) == normalizeYemeniPhone(phone)
          ? proof
          : null;
    } on FormatException {
      return null;
    }
  }

  String? get _freshPhoneProof {
    final provenAt = _phoneProofAt;
    if (_phoneProof == null || provenAt == null) return null;
    final age = _now().difference(provenAt);
    return age < phoneProofLifetime ? _phoneProof : null;
  }

  /// The screen that says so has said it: it is said once, right after the
  /// sign-up, not on every later visit.
  void acknowledgeSignUpFoundAccount() => _signUpFoundAccount = false;

  /// True once after a sign-up entered an existing account: the page the
  /// person lands on says so (J1-10), and never again for that sign-in.
  bool claimSignUpFoundAccountNotice() {
    final pending = _signUpFoundAccountNoticePending && _signUpFoundAccount;
    _signUpFoundAccountNoticePending = false;
    return pending;
  }

  /// The number of the account whose session expired, so x18 can offer to
  /// sign that same account in again. Null after any other sign-out.
  String? get expiredSessionPhone => _expiredSessionPhone;

  /// Keeps the page an expiring session was on, said by the router at the
  /// moment the session expired (before the account's screens are torn
  /// down), so x18 «بعد الدخول ترجع مكانك» can keep its word.
  void noteExpiredSessionLocation(String location) {
    if (!_sessionExpired || _expiredSessionLocation != null) return;
    _expiredSessionLocation = location;
  }

  /// The page noted by [noteExpiredSessionLocation], once.
  String? claimExpiredSessionLocation() {
    final location = _expiredSessionLocation;
    _expiredSessionLocation = null;
    return location;
  }

  bool get loginRequestedAfterLogout => _loginRequestedAfterLogout;

  bool get hasPendingAuthenticatedEntry =>
      _status == AuthStatus.authenticated && _authenticatedEntryPending;

  /// Returns a verified private invite exactly once to the router that lives
  /// inside the newly-created account boundary. The token remains memory-only
  /// and is consumed by the matching invite screen after navigation.
  String? claimPendingInviteResumeRoute() {
    if (!hasPendingInviteResume) return null;
    _pendingInviteRouteClaimed = true;
    return _pendingInviteResumeToken;
  }

  bool claimLoginAfterLogout() {
    if (!_loginRequestedAfterLogout) return false;
    _loginRequestedAfterLogout = false;
    return true;
  }

  String? claimPendingAuthenticatedEntry() {
    if (!hasPendingAuthenticatedEntry) return null;
    _authenticatedEntryPending = false;
    final location = _pendingAuthenticatedEntryLocation;
    _pendingAuthenticatedEntryLocation = null;
    return location;
  }

  void requestAuthenticatedEntry([String? successLocation]) {
    if (_status != AuthStatus.authenticated) return;
    _queueAuthenticatedEntry(successLocation);
    notifyListeners();
  }

  /// Allows only the route carrying the same private token to resume. A stale
  /// or unrelated route cannot consume another invite's phone proof.
  bool consumePendingInviteResume(String token) {
    final cleanToken = _validInviteToken(token);
    if (cleanToken == null || cleanToken != _pendingInviteResumeToken) {
      return false;
    }
    _clearPendingInviteResume();
    return true;
  }

  void clearError() {
    _errorMessage = null;
    _errorCode = null;
    _failedOffline = false;
    notifyListeners();
  }
}

// AuthController's state and the entry/invite helpers every flow shares.
abstract class _AuthControllerCore extends ChangeNotifier {
  _AuthControllerCore(
    this._authRepository,
    this._offlineSyncService,
    this._now,
    this._sessionTeardownCoordinator,
  );

  final AuthRepository _authRepository;
  final OfflineSyncService? _offlineSyncService;

  /// The app's «now» ([appNow]); a test passes its own.
  final DateTime Function() _now;
  final SessionTeardownCoordinator _sessionTeardownCoordinator;

  AuthStatus _status = AuthStatus.checking;
  SafeUser? _user;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _errorCode;
  OtpRequestResult? _otpRequest;
  bool _sessionExpired = false;
  bool _accountJustCreated = false;
  bool _failedOffline = false;
  bool _signUpFoundAccount = false;
  String? _signUpFoundAccountName;
  bool _signUpFoundAccountNoticePending = false;
  String? _phoneProof;
  String? _phoneProofPhone;
  DateTime? _phoneProofAt;
  String? _expiredSessionPhone;
  String? _expiredSessionLocation;
  bool _loginRequestedAfterLogout = false;
  bool _authenticatedEntryPending = false;
  String? _pendingAuthenticatedEntryLocation;
  String? _pendingInviteResumeToken;
  bool _pendingInviteRouteClaimed = false;
  int _sessionOperationGeneration = 0;
  String? _pendingLogoutUserId;
  String _pendingLogoutReason = 'explicit_account_logout';
  bool _pendingLogoutRequestsLogin = true;
  bool _pendingLogoutMarksSessionExpired = false;
  Future<void>? _logoutInFlight;

  void _clearPendingInviteResume() {
    _pendingInviteResumeToken = null;
    _pendingInviteRouteClaimed = false;
  }

  void _queueAuthenticatedEntry(String? successLocation) {
    _authenticatedEntryPending = true;
    _pendingAuthenticatedEntryLocation = successLocation;
  }

  void _clearPendingAuthenticatedEntry() {
    _authenticatedEntryPending = false;
    _pendingAuthenticatedEntryLocation = null;
  }

  bool _isCurrentSessionOperation(int generation) {
    return generation == _sessionOperationGeneration;
  }
}
