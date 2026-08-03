import 'dart:async';

import 'package:dio/dio.dart';

import '../diagnostics/app_logger.dart';

enum SessionLocalTeardownStage {
  authStorage,
  accountCache,
  guestDraft,
  pushRegistration,
  deletedAccountState,
}

enum SessionRemoteTeardownOutcome { completed, failed, timedOut, skipped }

class SessionLocalTeardownException implements Exception {
  const SessionLocalTeardownException({
    required this.stage,
    required this.cause,
    required this.stackTrace,
  });

  final SessionLocalTeardownStage stage;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'Local session teardown failed at ${stage.name}';
}

class SessionAuthTeardownLease {
  SessionAuthTeardownLease({required this.userId, required this.storageEpoch});

  final String userId;
  final int storageEpoch;
  String? _accessToken;
  String? _refreshToken;
  bool _credentialsSealed = false;

  String? get accessTokenForRemoteTeardown => _accessToken;
  String? get refreshTokenForRemoteTeardown => _refreshToken;
  bool get hasSensitiveCredentials =>
      _accessToken?.isNotEmpty == true || _refreshToken?.isNotEmpty == true;

  void captureCredentials({String? accessToken, String? refreshToken}) {
    if (_credentialsSealed) return;
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearSensitiveCredentials() {
    _credentialsSealed = true;
    _accessToken = null;
    _refreshToken = null;
  }
}

class SessionPushTeardownLease {
  const SessionPushTeardownLease({
    required this.userId,
    required this.installationId,
    this.bindingGeneration = 0,
  });

  final String userId;
  final String? installationId;
  final int bindingGeneration;
}

abstract interface class SessionAuthTeardownPort {
  SessionAuthTeardownLease beginSessionTeardown(String userId);

  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease);

  Future<void> clearLocalSession(SessionAuthTeardownLease lease);

  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  });
}

abstract interface class SessionPushTeardownPort {
  SessionPushTeardownLease? beginAccountTeardown(String userId);

  Future<void> clearLocalRegistration(SessionPushTeardownLease lease);

  Future<void> unregisterRemote(
    SessionPushTeardownLease lease, {
    required CancelToken cancelToken,
    String? bearerToken,
  });
}

class SessionTeardownLease {
  SessionTeardownLease._({
    required this.userId,
    required this.auth,
    required this.push,
  });

  final String userId;
  final SessionAuthTeardownLease auth;
  final SessionPushTeardownLease? push;

  bool _credentialsCaptureAttempted = false;
  bool _credentialsCaptureFailed = false;
  bool _authStorageCleared = false;
  bool _accountCacheCleared = false;
  bool _guestDraftCleared = false;
  bool _pushRegistrationCleared = false;
  bool _deletedAccountStateCleared = false;

  bool get hasSensitiveCredentials => auth.hasSensitiveCredentials;
}

class SessionTeardownResult {
  const SessionTeardownResult({
    required this.authRemote,
    required this.pushRemote,
  });

  final SessionRemoteTeardownOutcome authRemote;
  final SessionRemoteTeardownOutcome pushRemote;

  bool get localCleanupCompleted => true;
}

class SessionTeardownCoordinator {
  SessionTeardownCoordinator({
    required SessionAuthTeardownPort auth,
    required Future<void> Function() clearLocalAccountData,
    required Future<void> Function() clearGuestDraft,
    Future<void> Function(String userId)? clearDeletedAccountState,
    SessionPushTeardownPort? push,
    this.credentialCaptureTimeout = const Duration(seconds: 2),
    this.localStageTimeout = const Duration(seconds: 5),
    this.remoteTimeout = const Duration(seconds: 2),
  }) : assert(credentialCaptureTimeout > Duration.zero),
       assert(localStageTimeout > Duration.zero),
       assert(remoteTimeout > Duration.zero),
       _auth = auth,
       _push = push,
       _clearLocalAccountData = clearLocalAccountData,
       _clearGuestDraft = clearGuestDraft,
       _clearDeletedAccountState = clearDeletedAccountState;

  final SessionAuthTeardownPort _auth;
  final SessionPushTeardownPort? _push;
  final Future<void> Function() _clearLocalAccountData;
  final Future<void> Function() _clearGuestDraft;
  final Future<void> Function(String userId)? _clearDeletedAccountState;
  final Duration credentialCaptureTimeout;
  final Duration localStageTimeout;
  final Duration remoteTimeout;

  SessionTeardownLease? _activeLease;

  SessionTeardownLease? get activeLease => _activeLease;

  SessionTeardownLease begin(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    final existing = _activeLease;
    if (existing != null) {
      if (existing.userId != normalizedUserId) {
        throw StateError('A different account teardown is already active');
      }
      return existing;
    }

    final lease = SessionTeardownLease._(
      userId: normalizedUserId,
      auth: _auth.beginSessionTeardown(normalizedUserId),
      push: _push?.beginAccountTeardown(normalizedUserId),
    );
    _activeLease = lease;
    appLogEvent(
      'SESSION_TEARDOWN_STARTED',
      category: AppLogCategory.session,
      userId: normalizedUserId,
      source: 'SessionTeardownCoordinator.begin',
    );
    return lease;
  }

  Future<SessionTeardownResult> terminate(
    SessionTeardownLease lease, {
    bool remoteSessionAlreadyDestroyed = false,
  }) async {
    if (!identical(_activeLease, lease)) {
      throw StateError('The teardown lease is no longer active');
    }

    if (!remoteSessionAlreadyDestroyed) {
      await _captureRemoteCredentials(lease);
    }
    await _runLocalCleanup(
      lease,
      clearDeletedAccountState: remoteSessionAlreadyDestroyed,
    );
    final result = remoteSessionAlreadyDestroyed
        ? const SessionTeardownResult(
            authRemote: SessionRemoteTeardownOutcome.skipped,
            pushRemote: SessionRemoteTeardownOutcome.skipped,
          )
        : await _drainRemoteTeardown(lease);
    lease.auth.clearSensitiveCredentials();
    if (identical(_activeLease, lease)) {
      _activeLease = null;
    }
    appLogEvent(
      'SESSION_TEARDOWN_COMPLETED',
      category: AppLogCategory.session,
      userId: lease.userId,
      source: 'SessionTeardownCoordinator.terminate',
      attributes: {
        'authRemoteOutcome': result.authRemote.name,
        'pushRemoteOutcome': result.pushRemote.name,
      },
    );
    return result;
  }

  Future<void> _captureRemoteCredentials(SessionTeardownLease lease) async {
    if (lease._credentialsCaptureAttempted) return;
    lease._credentialsCaptureAttempted = true;
    try {
      await _auth
          .captureRemoteCredentials(lease.auth)
          .timeout(credentialCaptureTimeout);
      appLogEvent(
        'SESSION_REMOTE_LEASE_CAPTURED',
        category: AppLogCategory.session,
        userId: lease.userId,
        source: 'SessionTeardownCoordinator.captureRemoteCredentials',
      );
    } on TimeoutException catch (error, stackTrace) {
      lease._credentialsCaptureFailed = true;
      lease.auth.clearSensitiveCredentials();
      appLogEvent(
        'SESSION_REMOTE_LEASE_CAPTURE_TIMED_OUT',
        category: AppLogCategory.session,
        level: AppLogLevel.warning,
        userId: lease.userId,
        reason: 'credential_capture_deadline_reached',
        source: 'SessionTeardownCoordinator.captureRemoteCredentials',
        attributes: {'timeoutMs': credentialCaptureTimeout.inMilliseconds},
        error: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      lease._credentialsCaptureFailed = true;
      lease.auth.clearSensitiveCredentials();
      appLogEvent(
        'SESSION_REMOTE_LEASE_CAPTURE_FAILED',
        category: AppLogCategory.session,
        level: AppLogLevel.warning,
        userId: lease.userId,
        source: 'SessionTeardownCoordinator.captureRemoteCredentials',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _runLocalCleanup(
    SessionTeardownLease lease, {
    required bool clearDeletedAccountState,
  }) async {
    if (!lease._authStorageCleared) {
      await _runLocalStage(
        SessionLocalTeardownStage.authStorage,
        () => _auth.clearLocalSession(lease.auth),
      );
      lease._authStorageCleared = true;
    }
    if (!lease._accountCacheCleared) {
      await _runLocalStage(
        SessionLocalTeardownStage.accountCache,
        _clearLocalAccountData,
      );
      lease._accountCacheCleared = true;
    }
    if (!lease._guestDraftCleared) {
      await _runLocalStage(
        SessionLocalTeardownStage.guestDraft,
        _clearGuestDraft,
      );
      lease._guestDraftCleared = true;
    }
    final pushLease = lease.push;
    if (!lease._pushRegistrationCleared && pushLease != null) {
      await _runLocalStage(
        SessionLocalTeardownStage.pushRegistration,
        () => _push!.clearLocalRegistration(pushLease),
      );
      lease._pushRegistrationCleared = true;
    }
    final deletedAccountClear = _clearDeletedAccountState;
    if (clearDeletedAccountState &&
        !lease._deletedAccountStateCleared &&
        deletedAccountClear != null) {
      await _runLocalStage(
        SessionLocalTeardownStage.deletedAccountState,
        () => deletedAccountClear(lease.userId),
      );
      lease._deletedAccountStateCleared = true;
    }
  }

  Future<void> _runLocalStage(
    SessionLocalTeardownStage stage,
    Future<void> Function() action,
  ) async {
    appLogEvent(
      'SESSION_LOCAL_CLEAR_STARTED',
      category: AppLogCategory.session,
      source: 'SessionTeardownCoordinator.runLocalStage',
      attributes: {'operation': stage.name},
    );
    try {
      await action().timeout(localStageTimeout);
      appLogEvent(
        'SESSION_LOCAL_CLEAR_COMPLETED',
        category: AppLogCategory.session,
        source: 'SessionTeardownCoordinator.runLocalStage',
        attributes: {'operation': stage.name},
      );
    } on TimeoutException catch (error, stackTrace) {
      appLogEvent(
        'SESSION_LOCAL_CLEAR_TIMED_OUT',
        category: AppLogCategory.session,
        level: AppLogLevel.error,
        reason: 'local_stage_deadline_reached',
        source: 'SessionTeardownCoordinator.runLocalStage',
        attributes: {
          'operation': stage.name,
          'timeoutMs': localStageTimeout.inMilliseconds,
        },
        error: error,
        stackTrace: stackTrace,
      );
      throw SessionLocalTeardownException(
        stage: stage,
        cause: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      appLogEvent(
        'SESSION_LOCAL_CLEAR_FAILED',
        category: AppLogCategory.session,
        level: AppLogLevel.warning,
        source: 'SessionTeardownCoordinator.runLocalStage',
        attributes: {'operation': stage.name},
        error: error,
        stackTrace: stackTrace,
      );
      throw SessionLocalTeardownException(
        stage: stage,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<SessionTeardownResult> _drainRemoteTeardown(
    SessionTeardownLease lease,
  ) async {
    appLogEvent(
      'SESSION_REMOTE_DRAIN_STARTED',
      category: AppLogCategory.session,
      userId: lease.userId,
      source: 'SessionTeardownCoordinator.drainRemoteTeardown',
    );
    final cancelToken = CancelToken();
    final authTracker = _RemoteTeardownTracker(
      lease._credentialsCaptureFailed
          ? SessionRemoteTeardownOutcome.failed
          : null,
    );
    final pushLease = lease.push;
    final pushBearerToken = lease.auth.accessTokenForRemoteTeardown;
    final pushTracker = _RemoteTeardownTracker(
      pushLease == null
          ? SessionRemoteTeardownOutcome.skipped
          : pushBearerToken == null || pushBearerToken.isEmpty
          ? SessionRemoteTeardownOutcome.failed
          : null,
    );
    final operations = <Future<void>>[];

    if (authTracker.outcome == null) {
      operations.add(
        _trackRemote(
          authTracker,
          () => _auth.revokeRemoteSession(lease.auth, cancelToken: cancelToken),
        ),
      );
    }
    if (pushLease != null && pushTracker.outcome == null) {
      operations.add(
        _trackRemote(
          pushTracker,
          () => _push!.unregisterRemote(
            pushLease,
            cancelToken: cancelToken,
            bearerToken: pushBearerToken,
          ),
        ),
      );
    }

    if (operations.isNotEmpty) {
      try {
        await Future.wait(operations).timeout(remoteTimeout);
      } on TimeoutException {
        appLogEvent(
          'SESSION_REMOTE_DRAIN_TIMED_OUT',
          category: AppLogCategory.session,
          level: AppLogLevel.warning,
          userId: lease.userId,
          source: 'SessionTeardownCoordinator.drainRemoteTeardown',
          attributes: {'timeoutMs': remoteTimeout.inMilliseconds},
        );
        authTracker.markTimedOutIfPending();
        pushTracker.markTimedOutIfPending();
        cancelToken.cancel('Session teardown deadline reached');
        try {
          await Future.wait(
            operations,
          ).timeout(const Duration(milliseconds: 100));
        } on Object {
          // The deadline is final. Generation guards prevent late work from
          // mutating a replacement session even if a transport ignores cancel.
        }
      }
    }

    final result = SessionTeardownResult(
      authRemote: authTracker.outcome ?? SessionRemoteTeardownOutcome.completed,
      pushRemote: pushTracker.outcome ?? SessionRemoteTeardownOutcome.completed,
    );
    appLogEvent(
      'SESSION_REMOTE_DRAIN_COMPLETED',
      category: AppLogCategory.session,
      userId: lease.userId,
      source: 'SessionTeardownCoordinator.drainRemoteTeardown',
      level:
          result.authRemote == SessionRemoteTeardownOutcome.completed &&
              (result.pushRemote == SessionRemoteTeardownOutcome.completed ||
                  result.pushRemote == SessionRemoteTeardownOutcome.skipped)
          ? AppLogLevel.info
          : AppLogLevel.warning,
      attributes: {
        'authOutcome': result.authRemote.name,
        'pushOutcome': result.pushRemote.name,
      },
    );
    return result;
  }

  Future<void> _trackRemote(
    _RemoteTeardownTracker tracker,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      tracker.markCompletedIfPending();
    } on Object {
      tracker.markFailedIfPending();
    }
  }
}

class _RemoteTeardownTracker {
  _RemoteTeardownTracker(this.outcome);

  SessionRemoteTeardownOutcome? outcome;

  void markCompletedIfPending() {
    outcome ??= SessionRemoteTeardownOutcome.completed;
  }

  void markFailedIfPending() {
    outcome ??= SessionRemoteTeardownOutcome.failed;
  }

  void markTimedOutIfPending() {
    outcome ??= SessionRemoteTeardownOutcome.timedOut;
  }
}
