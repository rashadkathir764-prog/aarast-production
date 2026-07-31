import 'dart:async';

import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clears every local scope before draining remote teardown', () async {
    final events = <String>[];
    final auth = _FakeAuthTeardown(events);
    final push = _FakePushTeardown(events);
    final coordinator = SessionTeardownCoordinator(
      auth: auth,
      push: push,
      clearLocalAccountData: () async => events.add('local-cache'),
      clearGuestDraft: () async => events.add('local-draft'),
    );

    final lease = coordinator.begin('user-a');

    expect(events, ['auth-begin', 'push-begin']);
    final result = await coordinator.terminate(lease);

    expect(events, [
      'auth-begin',
      'push-begin',
      'auth-capture',
      'auth-local',
      'local-cache',
      'local-draft',
      'push-local',
      'auth-remote',
      'push-remote',
    ]);
    expect(result.localCleanupCompleted, isTrue);
    expect(result.authRemote, SessionRemoteTeardownOutcome.completed);
    expect(result.pushRemote, SessionRemoteTeardownOutcome.completed);
    expect(lease.hasSensitiveCredentials, isFalse);
  });

  test(
    'retries only unfinished local cleanup and never opens remote early',
    () async {
      final events = <String>[];
      final auth = _FakeAuthTeardown(events);
      final push = _FakePushTeardown(events);
      var cacheAttempts = 0;
      final coordinator = SessionTeardownCoordinator(
        auth: auth,
        push: push,
        clearLocalAccountData: () async {
          events.add('local-cache');
          cacheAttempts += 1;
          if (cacheAttempts == 1) {
            throw StateError('database unavailable');
          }
        },
        clearGuestDraft: () async => events.add('local-draft'),
      );

      final lease = coordinator.begin('user-a');

      await expectLater(
        coordinator.terminate(lease),
        throwsA(
          isA<SessionLocalTeardownException>().having(
            (error) => error.stage,
            'stage',
            SessionLocalTeardownStage.accountCache,
          ),
        ),
      );
      expect(events.where((event) => event == 'auth-local'), hasLength(1));
      expect(events, isNot(contains('auth-remote')));
      expect(coordinator.activeLease, same(lease));

      final result = await coordinator.terminate(lease);

      expect(result.localCleanupCompleted, isTrue);
      expect(events.where((event) => event == 'auth-local'), hasLength(1));
      expect(events.where((event) => event == 'local-cache'), hasLength(2));
      expect(events, containsAllInOrder(['push-local', 'auth-remote']));
      expect(coordinator.activeLease, isNull);
    },
  );

  test('cancels pending remote work at the shared timeout', () async {
    final events = <String>[];
    final auth = _FakeAuthTeardown(events, hangRemote: true);
    final push = _FakePushTeardown(events, hangRemote: true);
    final coordinator = SessionTeardownCoordinator(
      auth: auth,
      push: push,
      clearLocalAccountData: () async => events.add('local-cache'),
      clearGuestDraft: () async => events.add('local-draft'),
      remoteTimeout: const Duration(milliseconds: 20),
    );

    final result = await coordinator.terminate(coordinator.begin('user-a'));

    expect(result.localCleanupCompleted, isTrue);
    expect(result.authRemote, SessionRemoteTeardownOutcome.timedOut);
    expect(result.pushRemote, SessionRemoteTeardownOutcome.timedOut);
    expect(auth.remoteWasCancelled, isTrue);
    expect(push.remoteWasCancelled, isTrue);
  });

  test('hanging local push clear becomes a retryable push failure', () async {
    final events = <String>[];
    final auth = _FakeAuthTeardown(events);
    final push = _FakePushTeardown(events, hangLocal: true);
    addTearDown(push.releaseLocal);
    final coordinator = SessionTeardownCoordinator(
      auth: auth,
      push: push,
      clearLocalAccountData: () async => events.add('local-cache'),
      clearGuestDraft: () async => events.add('local-draft'),
      localStageTimeout: const Duration(milliseconds: 20),
    );
    final lease = coordinator.begin('user-a');

    await expectLater(
      coordinator.terminate(lease),
      throwsA(
        isA<SessionLocalTeardownException>().having(
          (error) => error.stage,
          'stage',
          SessionLocalTeardownStage.pushRegistration,
        ),
      ),
    );

    expect(events, isNot(contains('auth-remote')));
    expect(events, isNot(contains('push-remote')));
    expect(coordinator.activeLease, same(lease));

    push.releaseLocal();
    final result = await coordinator.terminate(lease);

    expect(result.localCleanupCompleted, isTrue);
    expect(events.where((event) => event == 'push-local'), hasLength(2));
    expect(coordinator.activeLease, isNull);
  });

  test('late credential capture cannot restore sealed secrets', () async {
    final events = <String>[];
    final auth = _FakeAuthTeardown(events, hangCapture: true);
    addTearDown(auth.releaseCapture);
    final coordinator = SessionTeardownCoordinator(
      auth: auth,
      clearLocalAccountData: () async => events.add('local-cache'),
      clearGuestDraft: () async => events.add('local-draft'),
      credentialCaptureTimeout: const Duration(milliseconds: 20),
    );
    final lease = coordinator.begin('user-a');

    final result = await coordinator.terminate(lease);

    expect(result.authRemote, SessionRemoteTeardownOutcome.failed);
    expect(lease.hasSensitiveCredentials, isFalse);

    auth.releaseCapture();
    await auth.captureFinished.future;
    expect(lease.hasSensitiveCredentials, isFalse);
  });
}

class _FakeAuthTeardown implements SessionAuthTeardownPort {
  _FakeAuthTeardown(
    this.events, {
    this.hangCapture = false,
    this.hangRemote = false,
  });

  final List<String> events;
  final bool hangCapture;
  final bool hangRemote;
  final Completer<void> _captureRelease = Completer<void>();
  final Completer<void> captureFinished = Completer<void>();
  bool remoteWasCancelled = false;

  @override
  SessionAuthTeardownLease beginSessionTeardown(String userId) {
    events.add('auth-begin');
    return SessionAuthTeardownLease(userId: userId, storageEpoch: 7);
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {
    events.add('auth-capture');
    if (hangCapture) {
      await _captureRelease.future;
    }
    lease.captureCredentials(
      accessToken: 'access-secret',
      refreshToken: 'refresh-secret',
    );
    if (!captureFinished.isCompleted) captureFinished.complete();
  }

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {
    events.add('auth-local');
  }

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {
    events.add('auth-remote');
    if (!hangRemote) return;
    await cancelToken.whenCancel;
    remoteWasCancelled = true;
  }

  void releaseCapture() {
    if (!_captureRelease.isCompleted) {
      _captureRelease.complete();
    }
  }
}

class _FakePushTeardown implements SessionPushTeardownPort {
  _FakePushTeardown(
    this.events, {
    this.hangLocal = false,
    this.hangRemote = false,
  });

  final List<String> events;
  final bool hangLocal;
  final bool hangRemote;
  final Completer<void> _localRelease = Completer<void>();
  bool remoteWasCancelled = false;

  @override
  SessionPushTeardownLease beginAccountTeardown(String userId) {
    events.add('push-begin');
    return SessionPushTeardownLease(userId: userId, installationId: 'fid-a');
  }

  @override
  Future<void> clearLocalRegistration(SessionPushTeardownLease lease) async {
    events.add('push-local');
    if (hangLocal) {
      await _localRelease.future;
    }
  }

  @override
  Future<void> unregisterRemote(
    SessionPushTeardownLease lease, {
    required CancelToken cancelToken,
    String? bearerToken,
  }) async {
    events.add('push-remote');
    if (!hangRemote) return;
    await cancelToken.whenCancel;
    remoteWasCancelled = true;
  }

  void releaseLocal() {
    if (!_localRelease.isCompleted) {
      _localRelease.complete();
    }
  }
}
