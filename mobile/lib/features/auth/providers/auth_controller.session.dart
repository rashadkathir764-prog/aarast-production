part of 'auth_controller.dart';

// The session lifecycle (restore, refresh, logout, expiry) and account
// deletion, the session-ending flow a restore reconciles.
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

    final deletionStore = _pendingAccountDeletionStore;
    if (deletionStore != null) {
      try {
        final pendingDeletion = await deletionStore.read();
        if (!_isCurrentSessionOperation(operation)) return;
        if (pendingDeletion != null) {
          _pendingAccountDeletionUser = _user;
          _accountDeletionAwaitingServerConfirmation = true;
          await _reconcilePendingAccountDeletion(
            pendingDeletion,
            operation: operation,
          );
          return;
        }
      } on Object catch (error, stackTrace) {
        if (!_isCurrentSessionOperation(operation)) return;
        _user = null;
        _authRepository.bindClientSession(null);
        _status = AuthStatus.terminationFailed;
        _errorCode = 'PENDING_ACCOUNT_DELETION_STORAGE_FAILED';
        _errorMessage =
            'تعذّر التحقق من حالة حذف الحساب المحلية بأمان. أعد تشغيل التطبيق وحاول مرة أخرى.';
        appLogEvent(
          'ACCOUNT_DELETION_RECOVERY_FAILED',
          category: AppLogCategory.auth,
          level: AppLogLevel.error,
          reason: 'secure_marker_read_failed',
          source: 'AuthController.restoreSession',
          error: error,
          stackTrace: stackTrace,
        );
        notifyListeners();
        return;
      }
    }

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
      unawaited(_offlineSyncService?.syncPendingChanges());
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
    if (_accountDeletionAwaitingServerConfirmation) {
      await _retryPendingAccountDeletion();
      return;
    }
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
    bool allowTerminating = false,
  }) {
    final inFlight = _logoutInFlight;
    if (inFlight != null) return inFlight;
    if (_status != AuthStatus.authenticated &&
        _status != AuthStatus.terminationFailed &&
        !(allowTerminating && _status == AuthStatus.terminating) &&
        !(allowChecking && _status == AuthStatus.checking)) {
      return Future<void>.value();
    }
    if (_status != AuthStatus.terminationFailed ||
        reason == 'account_deleted') {
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
    _expiredSessionPhone = markSessionExpired ? _user?.phone : null;
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
        remoteSessionAlreadyDestroyed:
            reason == 'account_deleted' || reason == 'phone_changed',
        clearGuestDraft: reason == 'account_deleted',
        // C58: an expired session keeps its unsent changes for the same
        // account; a sign-out the person chose wipes them.
        keepUnsentChanges: markSessionExpired,
      );
      if (!_isCurrentSessionOperation(operation)) return;

      _pendingLogoutUserId = null;
      if (reason == 'account_deleted') {
        _accountDeletionAwaitingServerConfirmation = false;
        _pendingAccountDeletionUser = null;
      }
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

  /// V1 checklist 4.14, step 1: sends a code to [newPhone]. Returns an
  /// Arabic error, or null when the code was sent.
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

  /// Permanently deletes the account, then tears the local session down and
  /// clears account caches, queued writes, and the installation guest draft.
  /// Ordinary logout and session rejection intentionally preserve that draft.
  /// Ambiguous server outcomes keep the dashboard unmounted behind the safe
  /// termination gate until the durable request can be reconciled or retried.
  Future<bool> deleteAccount() async {
    if (_status != AuthStatus.authenticated || _user == null || _isSubmitting) {
      return false;
    }
    final store = _pendingAccountDeletionStore;
    if (store == null) {
      _pendingAccountDeletionUser = _user;
      _pendingLogoutUserId = _user?.id;
      _accountDeletionAwaitingServerConfirmation = true;
      _user = null;
      _authRepository.bindClientSession(null);
      _status = AuthStatus.terminationFailed;
      _errorCode = 'ACCOUNT_DELETION_STORAGE_UNAVAILABLE';
      _errorMessage = 'تعذّر تجهيز حذف الحساب بأمان على هذا الجهاز.';
      notifyListeners();
      return false;
    }
    final operation = ++_sessionOperationGeneration;
    final outgoingUser = _user!;
    final outgoingUserId = outgoingUser.id;
    _pendingAccountDeletionUser = outgoingUser;
    _pendingLogoutUserId = outgoingUserId;
    _accountDeletionAwaitingServerConfirmation = true;
    _user = null;
    _authRepository.bindClientSession(null);
    _status = AuthStatus.terminating;
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    appLogEvent(
      'ACCOUNT_DELETION_STARTED',
      category: AppLogCategory.auth,
      userId: outgoingUserId,
      source: 'AuthController.deleteAccount',
    );
    notifyListeners();
    late final PendingAccountDeletion pendingDeletion;
    try {
      pendingDeletion = await store.putIfAbsent(outgoingUserId);
    } on Object catch (error, stackTrace) {
      if (!_isCurrentSessionOperation(operation)) return false;
      _isSubmitting = false;
      _status = AuthStatus.terminationFailed;
      _errorCode = 'ACCOUNT_DELETION_STORAGE_FAILED';
      _errorMessage = 'تعذّر حفظ طلب حذف الحساب بأمان. لم يُرسل الطلب.';
      appLogEvent(
        'ACCOUNT_DELETION_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: outgoingUserId,
        reason: 'secure_marker_write_failed',
        source: 'AuthController.deleteAccount',
        error: error,
        stackTrace: stackTrace,
      );
      notifyListeners();
      return false;
    }
    if (!_isCurrentSessionOperation(operation)) return false;
    _isSubmitting = false;
    notifyListeners();
    try {
      await _authRepository.deleteAccount(
        clientRequestId: pendingDeletion.clientRequestId,
      );
    } on ApiException catch (error) {
      if (!_isCurrentSessionOperation(operation)) return false;
      appLogEvent(
        'ACCOUNT_DELETION_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.warning,
        userId: outgoingUserId,
        reason: 'server_result_requires_reconciliation',
        source: 'AuthController.deleteAccount',
        attributes: {
          'httpStatus': ?error.statusCode,
          'errorCode': ?error.serverCode,
        },
      );
      await _reconcilePendingAccountDeletion(
        pendingDeletion,
        operation: operation,
        initialError: error,
      );
      return false;
    } on Object catch (error, stackTrace) {
      if (!_isCurrentSessionOperation(operation)) return false;
      _errorMessage =
          'جارٍ التحقق من اكتمال حذف الحساب. سيستأنف التطبيق التحقق تلقائياً.';
      _errorCode = 'ACCOUNT_DELETION_PENDING';
      appLogEvent(
        'ACCOUNT_DELETION_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: outgoingUserId,
        reason: 'server_delete_failed',
        source: 'AuthController.deleteAccount',
        error: error,
        stackTrace: stackTrace,
      );
      _status = AuthStatus.terminationFailed;
      notifyListeners();
      return false;
    }
    if (!_isCurrentSessionOperation(operation)) return false;
    _isSubmitting = false;
    _accountDeletionAwaitingServerConfirmation = false;
    appLogEvent(
      'ACCOUNT_DELETION_SERVER_COMPLETED',
      category: AppLogCategory.auth,
      userId: outgoingUserId,
      source: 'AuthController.deleteAccount',
    );
    await _startSessionTermination(
      reason: 'account_deleted',
      requestLoginAfterCompletion: true,
      markSessionExpired: false,
      allowTerminating: true,
    );
    return _status == AuthStatus.unauthenticated;
  }

  Future<void> _retryPendingAccountDeletion() async {
    final store = _pendingAccountDeletionStore;
    final userId = _pendingLogoutUserId ?? _pendingAccountDeletionUser?.id;
    if (store == null || userId == null) return;
    final operation = ++_sessionOperationGeneration;
    _status = AuthStatus.terminating;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
    try {
      final record = await store.read() ?? await store.putIfAbsent(userId);
      if (!_isCurrentSessionOperation(operation)) return;
      await _reconcilePendingAccountDeletion(record, operation: operation);
    } on Object catch (error, stackTrace) {
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.terminationFailed;
      _errorCode = 'ACCOUNT_DELETION_RECOVERY_FAILED';
      _errorMessage = 'تعذّر التحقق من حذف الحساب الآن. حاول مرة أخرى.';
      appLogEvent(
        'ACCOUNT_DELETION_RECOVERY_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: userId,
        reason: 'retry_failed',
        source: 'AuthController.logout',
        error: error,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  Future<void> _reconcilePendingAccountDeletion(
    PendingAccountDeletion pendingDeletion, {
    required int operation,
    ApiException? initialError,
  }) async {
    _pendingLogoutUserId = pendingDeletion.userId;
    _user = null;
    _authRepository.bindClientSession(null);
    _status = AuthStatus.terminating;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final status = await _authRepository.accountDeletionStatus(
        userId: pendingDeletion.userId,
        clientRequestId: pendingDeletion.clientRequestId,
      );
      if (!_isCurrentSessionOperation(operation)) return;
      if (status == AccountDeletionServerStatus.deleted) {
        _accountDeletionAwaitingServerConfirmation = false;
        await _startSessionTermination(
          reason: 'account_deleted',
          requestLoginAfterCompletion: true,
          markSessionExpired: false,
          allowTerminating: true,
        );
        return;
      }
      if (status == AccountDeletionServerStatus.notStarted &&
          initialError != null &&
          !initialError.isAmbiguousMutationFailure) {
        await _restoreAfterDefinitiveAccountDeletionRejection(
          pendingDeletion,
          initialError,
        );
        return;
      }
      if (status == AccountDeletionServerStatus.pending) {
        _status = AuthStatus.terminationFailed;
        _errorCode = 'ACCOUNT_DELETION_PENDING';
        _errorMessage =
            'جارٍ التحقق من اكتمال حذف الحساب. حاول التحقق مرة أخرى.';
        notifyListeners();
        return;
      }
      if (status == AccountDeletionServerStatus.notStarted) {
        await _authRepository.deleteAccount(
          clientRequestId: pendingDeletion.clientRequestId,
        );
      }
      if (!_isCurrentSessionOperation(operation)) return;
      _accountDeletionAwaitingServerConfirmation = false;
      await _startSessionTermination(
        reason: 'account_deleted',
        requestLoginAfterCompletion: true,
        markSessionExpired: false,
        allowTerminating: true,
      );
    } on ApiException catch (error) {
      if (!_isCurrentSessionOperation(operation)) return;
      AccountDeletionServerStatus? verifiedStatus;
      try {
        verifiedStatus = await _authRepository.accountDeletionStatus(
          userId: pendingDeletion.userId,
          clientRequestId: pendingDeletion.clientRequestId,
        );
      } on Object {
        verifiedStatus = null;
      }
      if (!_isCurrentSessionOperation(operation)) return;
      if (verifiedStatus == AccountDeletionServerStatus.deleted) {
        _accountDeletionAwaitingServerConfirmation = false;
        await _startSessionTermination(
          reason: 'account_deleted',
          requestLoginAfterCompletion: true,
          markSessionExpired: false,
          allowTerminating: true,
        );
        return;
      }
      if (verifiedStatus == AccountDeletionServerStatus.notStarted &&
          !error.isAmbiguousMutationFailure) {
        await _restoreAfterDefinitiveAccountDeletionRejection(
          pendingDeletion,
          error,
        );
        return;
      }
      _status = AuthStatus.terminationFailed;
      _errorCode = 'ACCOUNT_DELETION_PENDING';
      _errorMessage = 'جارٍ التحقق من اكتمال حذف الحساب. حاول التحقق مرة أخرى.';
      notifyListeners();
    } on Object catch (error, stackTrace) {
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.terminationFailed;
      _errorCode = 'ACCOUNT_DELETION_PENDING';
      _errorMessage =
          'جارٍ التحقق من اكتمال حذف الحساب. سيستأنف التطبيق التحقق تلقائياً.';
      appLogEvent(
        'ACCOUNT_DELETION_RECOVERY_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        userId: pendingDeletion.userId,
        reason: 'status_or_replay_failed',
        source: 'AuthController.restoreSession',
        error: error,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }

  Future<void> _restoreAfterDefinitiveAccountDeletionRejection(
    PendingAccountDeletion pendingDeletion,
    ApiException error,
  ) async {
    await _pendingAccountDeletionStore!.removeAfterDefinitiveRejection(
      pendingDeletion,
    );
    final retainedUser = _pendingAccountDeletionUser;
    _accountDeletionAwaitingServerConfirmation = false;
    _pendingAccountDeletionUser = null;
    _pendingLogoutUserId = null;
    _errorCode = error.serverCode;
    _errorMessage = error.message;
    if (retainedUser != null) {
      _user = retainedUser;
      _authRepository.bindClientSession(retainedUser.id);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }
    _status = AuthStatus.checking;
    notifyListeners();
    await restoreSession();
  }
}

/// Server codes of a phone change, as Arabic actions (V1 checklist 4.14).
String? phoneChangeErrorMessage(String? code) => switch (code) {
  'PHONE_IN_USE' => 'هذا الرقم مسجّل لحساب آخر. استخدم رقمًا آخر.',
  'PHONE_UNCHANGED' => 'هذا هو رقمك الحالي.',
  _ => null,
};
