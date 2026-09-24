import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/session/pending_account_deletion.dart';
import '../../../core/session/session_teardown_coordinator.dart';
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
    PendingAccountDeletionStore? pendingAccountDeletionStore,
  }) : super(
         authRepository,
         offlineSyncService,
         pendingAccountDeletionStore,
         sessionTeardownCoordinator ??
             SessionTeardownCoordinator(
               auth: authRepository,
               clearLocalAccountData: () async {
                 await offlineSyncService?.clearLocalData();
               },
               clearGuestDraft: () async {
                 await guestOnboardingStorage?.clearDraft();
               },
             ),
       );

  AuthStatus get status => _status;

  SafeUser? get user => _user;

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
    notifyListeners();
  }
}

// AuthController's state and the entry/invite helpers every flow shares.
abstract class _AuthControllerCore extends ChangeNotifier {
  _AuthControllerCore(
    this._authRepository,
    this._offlineSyncService,
    this._pendingAccountDeletionStore,
    this._sessionTeardownCoordinator,
  );

  final AuthRepository _authRepository;
  final OfflineSyncService? _offlineSyncService;
  final PendingAccountDeletionStore? _pendingAccountDeletionStore;
  final SessionTeardownCoordinator _sessionTeardownCoordinator;

  AuthStatus _status = AuthStatus.checking;
  SafeUser? _user;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _errorCode;
  OtpRequestResult? _otpRequest;
  bool _sessionExpired = false;
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
  bool _accountDeletionAwaitingServerConfirmation = false;
  SafeUser? _pendingAccountDeletionUser;

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
