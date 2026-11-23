// A known account opens at once (2026-11-23): on a phone with its token and
// the account read last, the app does not wait for the server's word before
// it opens. The server's answer follows, and only its refusal (401) ends the
// session, as RA-MO-32 already did when the answer was a network failure.
// Before, the splash waited on `me()` for up to 12 s connect + 12 s receive.

import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cached = SafeUser(
  id: 'user-a',
  name: 'User A',
  role: 'USER',
  status: 'ACTIVE',
);
const _fresh = SafeUser(
  id: 'user-a',
  name: 'User A renamed',
  role: 'USER',
  status: 'ACTIVE',
);

class _SlowServerRepository extends AuthRepository {
  _SlowServerRepository(
    super.apiClient,
    super.authStorage, {
    required this.cachedUser,
    required this.token,
  });

  final SafeUser? cachedUser;
  final String? token;
  final Completer<SafeUser> answer = Completer<SafeUser>();
  int meCalls = 0;

  @override
  SafeUser? readCachedUser() => cachedUser;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<SafeUser> me() {
    meCalls += 1;
    return answer.future;
  }
}

Future<(AuthController, _SlowServerRepository, List<String>)> _controller({
  SafeUser? cachedUser = _cached,
  String? token = 'restored-access-token',
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final repository = _SlowServerRepository(
    ApiClient(tokenProvider: storage.readAccessToken),
    storage,
    cachedUser: cachedUser,
    token: token,
  );
  final clears = <String>[];
  final controller = AuthController(
    repository,
    sessionTeardownCoordinator: SessionTeardownCoordinator(
      auth: repository,
      clearLocalAccountData: () async => clears.add('everything'),
      clearLocalAccountDataKeepingUnsent: () async =>
          clears.add('keeping unsent'),
      clearGuestDraft: () async {},
    ),
  );
  return (controller, repository, clears);
}

/// Lets the restore run up to where it waits on the server.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a known account is signed in before the server answers', () async {
    final (controller, repository, _) = await _controller();
    addTearDown(controller.dispose);

    unawaited(controller.restoreSession());
    await _settle();

    expect(repository.meCalls, 1, reason: 'the server is still asked');
    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.id, 'user-a');

    repository.answer.complete(_fresh);
    await _settle();
    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.name, 'User A renamed');
  });

  test('the server refusing the session still ends it', () async {
    final (controller, repository, clears) = await _controller();
    addTearDown(controller.dispose);

    final restore = controller.restoreSession();
    await _settle();
    expect(controller.status, AuthStatus.authenticated);

    repository.answer.completeError(
      const ApiException('انتهت الجلسة', statusCode: 401),
    );
    await restore;
    await _settle();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(controller.user, isNull);
    expect(clears, ['keeping unsent'], reason: 'an end nobody chose (C58)');
  });

  test('a slow or absent server keeps the known account', () async {
    final (controller, repository, clears) = await _controller();
    addTearDown(controller.dispose);

    final restore = controller.restoreSession();
    await _settle();
    repository.answer.completeError(
      const ApiException('ما فيه نت', isNetworkFailure: true),
    );
    await restore;

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.id, 'user-a');
    expect(clears, isEmpty);
  });

  test(
    'a token with no account read before still waits for the server',
    () async {
      final (controller, repository, _) = await _controller(cachedUser: null);
      addTearDown(controller.dispose);

      unawaited(controller.restoreSession());
      await _settle();
      expect(controller.status, AuthStatus.checking);

      repository.answer.complete(_cached);
      await _settle();
      expect(controller.status, AuthStatus.authenticated);
    },
  );

  test('no token is signed out without asking the server', () async {
    final (controller, repository, _) = await _controller(token: null);
    addTearDown(controller.dispose);

    await controller.restoreSession();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(repository.meCalls, 0);
  });
}
