part of 'auth_controller.dart';

// The session lifecycle (restore, refresh, logout, expiry) and the account's
// deletion request (D63), which keeps the session and shows w06 instead.
mixin _AuthSession on _AuthControllerCore {
  Future<void> restoreSession() async {
    AppLogger.global?.ensureSessionCorrelation();
    final operation = ++_sessionOperationGeneration;
    appLogEvent(
      'SESSION_LOAD_STARTED',
      category: AppLogCategory.session,
      reason: 'restore_requested',
      source: 'AuthController.restoreSession',
    );
    _status = AuthStatus.checking;
    _user = _authRepository.readCachedUser();
    _authRepository.bindClientSession(_user?.id);
    notifyListeners();

    final token = await _authRepository.readAccessToken();
    if (!_isCurrentSessionOperation(operation)) return;
    if (token == null || token.isEmpty) {
      _user = null;
      _authRepository.bindClientSession(null);
      _status = AuthStatus.unauthenticated;
      appLogEvent(
        'SESSION_LOAD_COMPLETED',
        category: AppLogCategory.session,
        reason: 'no_access_token',
        source: 'AuthController.restoreSession',
      );
      notifyListeners();
      return;
    }

    try {
      final restoredUser = await _authRepository.me();
      if (!_isCurrentSessionOperation(operation)) return;
      _user = restoredUser;
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.ensureCacheOwner(_user!.id);
        if (!_isCurrentSessionOperation(operation)) return;
        await _offlineSyncService?.cacheCurrentUser(_user!);
        if (!_isCurrentSessionOperation(operation)) return;
      }
      _status = AuthStatus.authenticated;
      appLogEvent(
        'SESSION_RESTORED',
        category: AppLogCategory.session,
        userId: _user?.id,
        reason: 'server_session_confirmed',
        source: 'AuthController.restoreSession',
      );
      // An account waiting out its deletion sends nothing: the server
      // refuses every write until it is taken back (D63).
      if (_user?.deletionPending != true) {
        unawaited(_offlineSyncService?.syncPendingChanges());
      }
    } on ApiException catch (error) {
      if (!_isCurrentSessionOperation(operation)) return;
      if (CachePolicy.shouldUseCache(error) && _user != null) {
        _status = AuthStatus.authenticated;
        appLogEvent(
          'SESSION_RESTORED',
          category: AppLogCategory.session,
          level: AppLogLevel.warning,
          userId: _user?.id,
          reason: 'offline_cached_account',
          source: 'AuthController.restoreSession',
        );
        await _offlineSyncService?.noteNetworkFailure(error.message);
      } else {
        final cachedUserId = _user?.id;
        appLogEvent(
          'SESSION_RESTORE_FAILED',
          category: AppLogCategory.session,
          level: AppLogLevel.warning,
          userId: cachedUserId,
          reason: 'server_session_rejected',
          source: 'AuthController.restoreSession',
          attributes: {
            'httpStatus': ?error.statusCode,
            'errorCode': ?error.serverCode,
          },
        );
        _pendingLogoutUserId = cachedUserId ?? 'unknown-session';
        await _startSessionTermination(
          reason: 'server_session_rejected',
          requestLoginAfterCompletion: false,
          markSessionExpired: false,
          allowChecking: true,
        );
        return;
      }
    }
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    if (_status != AuthStatus.authenticated) return;
    final operation = _sessionOperationGeneration;
    try {
      final refreshedUser = await _authRepository.me();
      if (!_isCurrentSessionOperation(operation)) return;
      _user = refreshedUser;
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.cacheCurrentUser(_user!);
        if (!_isCurrentSessionOperation(operation)) return;
      }
      notifyListeners();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await handleSessionExpired();
      }
    }
  }

  Future<void> logout() async {
    final retrying = _status == AuthStatus.terminationFailed;
    return _startSessionTermination(
      reason: retrying ? _pendingLogoutReason : 'explicit_account_logout',
      requestLoginAfterCompletion: retrying
          ? _pendingLogoutRequestsLogin
          : true,
      markSessionExpired: retrying ? _pendingLogoutMarksSessionExpired : false,
    );
  }

  Future<void> _startSessionTermination({
    required String reason,
    required bool requestLoginAfterCompletion,
    required bool markSessionExpired,
    bool allowChecking = false,
  }) {
    final inFlight = _logoutInFlight;
    if (inFlight != null) return inFlight;
    if (_status != AuthStatus.authenticated &&
        _status != AuthStatus.terminationFailed &&
        !(allowChecking && _status == AuthStatus.checking)) {
      return Future<void>.value();
    }
    if (_status != AuthStatus.terminationFailed) {
      _pendingLogoutReason = reason;
      _pendingLogoutRequestsLogin = requestLoginAfterCompletion;
      _pendingLogoutMarksSessionExpired = markSessionExpired;
    }
    final operation = _performLogout(
      reason: _pendingLogoutReason,
      requestLoginAfterCompletion: _pendingLogoutRequestsLogin,
      markSessionExpired: _pendingLogoutMarksSessionExpired,
    );
    _logoutInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_logoutInFlight, operation)) {
        _logoutInFlight = null;
      }
    });
  }

  Future<void> _performLogout({
    required String reason,
    required bool requestLoginAfterCompletion,
    required bool markSessionExpired,
  }) async {
    final operation = ++_sessionOperationGeneration;
    final outgoingUserId = _pendingLogoutUserId ?? _user?.id;
    _pendingLogoutUserId = outgoingUserId;
    SessionTeardownLease? teardownLease;
    Object? beginFailure;
    if (outgoingUserId != null) {
      try {
        teardownLease = _sessionTeardownCoordinator.begin(outgoingUserId);
      } on Object catch (error) {
        beginFailure = error;
      }
    } else {
      beginFailure = StateError('Authenticated session has no user identity');
    }
    appLogEvent(
      'LOGOUT_STARTED',
      category: AppLogCategory.auth,
      userId: outgoingUserId,
      reason: reason,
      source: 'AuthController.logout',
    );
    _authRepository.bindClientSession(null);
    _clearPendingInviteResume();
    _clearPendingAuthenticatedEntry();
    _loginRequestedAfterLogout = false;
    _sessionExpired = markSessionExpired;
    _accountJustCreated = false;
    _signUpFoundAccount = false;
    _signUpFoundAccountNoticePending = false;
    _expiredSessionPhone = markSessionExpired ? _user?.phone : null;
    // Noted by the router when the expiry is announced, below.
    _expiredSessionLocation = null;
    _user = null;
    _status = AuthStatus.terminating;
    _errorMessage = markSessionExpired
        ? 'انتهت جلستك. سجّل الدخول مرة أخرى للمتابعة.'
        : null;
    _errorCode = null;
    notifyListeners();

    if (beginFailure != null || teardownLease == null) {
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.terminationFailed;
      _errorMessage =
          'تعذر تنظيف بيانات الجلسة المحلية بأمان. حاول تسجيل الخروج مرة أخرى.';
      _errorCode = 'LOCAL_SESSION_TEARDOWN_FAILED';
      appLogEvent(
        'LOGOUT_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: outgoingUserId,
        reason: 'local_teardown_begin_failed',
        source: 'AuthController.logout',
        error: beginFailure,
      );
      notifyListeners();
      return;
    }

    try {
      await _sessionTeardownCoordinator.terminate(
        teardownLease,
        remoteSessionAlreadyDestroyed: reason == 'phone_changed',
        // C58: an expired session keeps its unsent changes for the same
        // account; a sign-out the person chose wipes them.
        keepUnsentChanges: markSessionExpired,
      );
      if (!_isCurrentSessionOperation(operation)) return;

      _pendingLogoutUserId = null;
      _loginRequestedAfterLogout = requestLoginAfterCompletion;
      _status = AuthStatus.unauthenticated;
      appLogEvent(
        'LOGOUT_COMPLETED',
        category: AppLogCategory.auth,
        userId: outgoingUserId,
        reason: reason,
        source: 'AuthController.logout',
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.terminationFailed;
      _errorMessage =
          'تعذر تنظيف بيانات الجلسة المحلية بأمان. حاول تسجيل الخروج مرة أخرى.';
      _errorCode = 'LOCAL_SESSION_TEARDOWN_FAILED';
      appLogEvent(
        'LOGOUT_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: outgoingUserId,
        reason: 'local_session_teardown_failed',
        source: 'AuthController.logout',
        error: error,
        stackTrace: stackTrace,
      );
    }
    notifyListeners();
  }

  /// Called by the API layer when any non-auth request returns 401. Ends
  /// the session cleanly instead of letting every screen degrade into
  /// misleading errors. It uses the same local teardown boundary as an
  /// explicit logout so account data cannot remain mounted or be reused.
  Future<void> handleSessionExpired() async {
    if (_status != AuthStatus.authenticated) return;
    appLogEvent(
      'UNAUTHORIZED_401',
      category: AppLogCategory.session,
      level: AppLogLevel.warning,
      userId: _user?.id,
      reason: 'confirmed_session_expiry',
      source: 'AuthController.handleSessionExpired',
    );
    await _startSessionTermination(
      reason: 'confirmed_session_expiry',
      requestLoginAfterCompletion: false,
      markSessionExpired: true,
    );
  }

  /// Called by the API layer when the server answers `403
  /// ACCOUNT_DELETION_PENDING`: the account asked to be deleted from another
  /// phone. Reading it again brings its day, so w06 shows (D63).
  Future<void> handleAccountDeletionPending() async {
    if (_status != AuthStatus.authenticated || _user?.deletionPending == true) {
      return;
    }
    await refreshCurrentUser();
  }

  /// V1 checklist 4.14, step 1: sends a code to [newPhone]. Returns an
  /// Arabic error, or null when the code was sent.
  /// D75: adds a password to an account made by number and code, or changes
  /// it. Returns an Arabic error, or null once saved; the account is read
  /// again so «حسابي» says it has one.
  Future<String?> setPassword(
    String newPassword,
    String? currentPassword,
  ) async {
    try {
      await _authRepository.setPassword(
        newPassword: newPassword,
        currentPassword: currentPassword,
      );
    } on ApiException catch (error) {
      if (error.serverCode == 'INVALID_CREDENTIALS') {
        return 'كلمة المرور الحالية غلط.';
      }
      // A failed connection is not proof the net is down: the server, or
      // its name, may be the one out of reach. Say what is known.
      return error.isNetworkFailure
          ? 'ما قدرنا نوصل للخادم. تأكد من النت وجرّب مرة ثانية.'
          : error.message;
    }
    await refreshCurrentUser();
    return null;
  }

  Future<String?> requestPhoneChange(String newPhone) async {
    try {
      await _authRepository.requestPhoneChange(newPhone);
      return null;
    } on ApiException catch (error) {
      return phoneChangeErrorMessage(error.serverCode) ?? error.message;
    }
  }

  /// Step 2: the code moves the account to [newPhone]. The server has ended
  /// every session, so this one ends locally too and sign-in opens, now with
  /// the new number. Returns an Arabic error, or null on success.
  Future<String?> confirmPhoneChange(String newPhone, String code) async {
    try {
      await _authRepository.confirmPhoneChange(newPhone, code);
    } on ApiException catch (error) {
      return phoneChangeErrorMessage(error.serverCode) ?? error.message;
    }
    await _startSessionTermination(
      reason: 'phone_changed',
      requestLoginAfterCompletion: true,
      markSessionExpired: false,
    );
    return null;
  }

  void acknowledgeSessionExpiry() {
    _sessionExpired = false;
  }

  /// D63 (w05 «احذف حسابي»): the account will be erased after its 30 days.
  /// The session stays: the app shows w06 until the request is taken back
  /// or the account is gone. Returns an Arabic error, or null on success.
  Future<String?> requestAccountDeletion() =>
      _changeAccountDeletion(request: true);

  /// D63 (w06 «تراجعت، رجّع حسابي»): the account and its plans are back.
  Future<String?> cancelAccountDeletion() =>
      _changeAccountDeletion(request: false);

  Future<String?> _changeAccountDeletion({required bool request}) async {
    final user = _user;
    if (_status != AuthStatus.authenticated || user == null || _isSubmitting) {
      return 'ما قدرنا الحين. حاول مرة ثانية.';
    }
    final operation = _sessionOperationGeneration;
    final source =
        'AuthController.${request ? 'request' : 'cancel'}AccountDeletion';
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
    try {
      if (request) {
        final schedule = await _authRepository.requestAccountDeletion();
        if (!_isCurrentSessionOperation(operation)) return null;
        _user = user.withDeletion(
          requestedAt: schedule.requestedAt,
          scheduledFor: schedule.scheduledFor,
        );
      } else {
        await _authRepository.cancelAccountDeletion();
        if (!_isCurrentSessionOperation(operation)) return null;
        _user = user.withDeletion();
      }
      await _offlineSyncService?.cacheCurrentUser(_user!);
      appLogEvent(
        request ? 'ACCOUNT_DELETION_REQUESTED' : 'ACCOUNT_DELETION_CANCELLED',
        category: AppLogCategory.auth,
        userId: user.id,
        source: source,
      );
      if (!request) unawaited(_offlineSyncService?.syncPendingChanges());
      return null;
    } on ApiException catch (error) {
      appLogEvent(
        'ACCOUNT_DELETION_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.warning,
        userId: user.id,
        reason: request ? 'request_refused' : 'cancel_refused',
        source: source,
        attributes: {
          'httpStatus': ?error.statusCode,
          'errorCode': ?error.serverCode,
        },
      );
      // The other phone may have taken it back already, or asked first.
      if (error.serverCode == 'DELETION_NOT_PENDING' ||
          error.serverCode == 'ACCOUNT_DELETION_PENDING') {
        await refreshCurrentUser();
        return null;
      }
      return error.message;
    } on FormatException {
      return 'ما قدرنا نتأكد من الطلب. حاول مرة ثانية.';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}

/// Server codes of a phone change, as Arabic actions (V1 checklist 4.14).
String? phoneChangeErrorMessage(String? code) => switch (code) {
  'PHONE_IN_USE' => 'هذا الرقم مسجّل لحساب آخر. استخدم رقمًا آخر.',
  'PHONE_UNCHANGED' => 'هذا هو رقمك الحالي.',
  _ => null,
};
