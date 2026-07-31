import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/core/storage/token_vault.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';

class _FakeTokenVault implements TokenVault {
  String? stored;
  String? refreshStored;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String token) async {
    stored = token;
  }

  @override
  Future<void> delete() async {
    stored = null;
  }

  @override
  Future<String?> readRefresh() async => refreshStored;

  @override
  Future<void> writeRefresh(String token) async {
    refreshStored = token;
  }

  @override
  Future<void> deleteRefresh() async {
    refreshStored = null;
  }
}

class _FakeSensitiveValueVault implements SensitiveValueVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

SafeUser _user(String id) {
  return SafeUser.fromJson({
    'id': id,
    'name': 'مستخدم تجريبي',
    'phone': '+967700000000',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthStorage with TokenVault', () {
    test(
      'production wiring never stores the safe user profile in prefs',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final sensitive = _FakeSensitiveValueVault();
        final storage = AuthStorage(
          preferences,
          tokenVault: _FakeTokenVault(),
          sensitiveValueVault: sensitive,
        );
        await storage.initialize();

        await storage.saveSession(accessToken: 'jwt', user: _user('u1'));

        expect(preferences.getString('aarast_safe_user'), isNull);
        expect(sensitive.values['aarast_safe_user'], contains('+967700000000'));
        expect(storage.readUser()?.id, 'u1');
        await storage.clear();
        expect(sensitive.values, isEmpty);
      },
    );

    test('legacy plaintext safe user migrates into secure storage', () async {
      SharedPreferences.setMockInitialValues({
        'aarast_safe_user':
            '{"id":"legacy","name":"Legacy","phone":"+967700000001"}',
      });
      final preferences = await SharedPreferences.getInstance();
      final sensitive = _FakeSensitiveValueVault();
      final storage = AuthStorage(
        preferences,
        tokenVault: _FakeTokenVault(),
        sensitiveValueVault: sensitive,
      );

      await storage.initialize();

      expect(storage.readUser()?.id, 'legacy');
      expect(preferences.getString('aarast_safe_user'), isNull);
      expect(sensitive.values['aarast_safe_user'], isNotNull);
    });

    test(
      'saveSession stores token in vault, never in plaintext prefs',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final vault = _FakeTokenVault();
        final storage = AuthStorage(preferences, tokenVault: vault);

        await storage.saveSession(accessToken: 'jwt-secret', user: _user('u1'));

        expect(vault.stored, 'jwt-secret');
        expect(preferences.getString('aarast_access_token'), isNull);
        expect(await storage.readAccessToken(), 'jwt-secret');
      },
    );

    test(
      'saveSession keeps access and refresh tokens in the secure vault',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final vault = _FakeTokenVault();
        final storage = AuthStorage(preferences, tokenVault: vault);

        await storage.saveSession(
          accessToken: 'access-secret',
          refreshToken: 'refresh-secret',
          user: _user('u1'),
        );

        expect(await storage.readAccessToken(), 'access-secret');
        expect(await storage.readRefreshToken(), 'refresh-secret');
        expect(preferences.getString('aarast_refresh_token'), isNull);

        await storage.clear();
        expect(vault.refreshStored, isNull);
      },
    );

    test('access-only sessions clear any stale refresh token', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final vault = _FakeTokenVault();
      final storage = AuthStorage(preferences, tokenVault: vault);

      await storage.saveSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        user: _user('u1'),
      );
      await storage.saveSession(
        accessToken: 'legacy-access',
        user: _user('u1'),
      );

      expect(await storage.readAccessToken(), 'legacy-access');
      expect(await storage.readRefreshToken(), isNull);
      expect(preferences.getString('aarast_refresh_token'), isNull);
    });

    test('legacy plaintext token migrates into vault on first read', () async {
      SharedPreferences.setMockInitialValues({
        'aarast_access_token': 'legacy-jwt',
      });
      final preferences = await SharedPreferences.getInstance();
      final vault = _FakeTokenVault();
      final storage = AuthStorage(preferences, tokenVault: vault);

      final token = await storage.readAccessToken();

      expect(token, 'legacy-jwt');
      expect(vault.stored, 'legacy-jwt');
      expect(
        preferences.getString('aarast_access_token'),
        isNull,
        reason: 'plaintext copy must be deleted after migration',
      );
    });

    test('clear removes token from vault and prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final vault = _FakeTokenVault();
      final storage = AuthStorage(preferences, tokenVault: vault);
      await storage.saveSession(accessToken: 'jwt-secret', user: _user('u1'));

      await storage.clear();

      expect(vault.stored, isNull);
      expect(await storage.readAccessToken(), isNull);
    });

    test('a delayed logout cannot clear a newer login session', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      await storage.saveSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        user: _user('old-user'),
      );
      final logoutStarted = Completer<void>();
      final releaseLogout = Completer<void>();
      final client = ApiClient(tokenProvider: storage.readAccessToken);
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/api/v1/auth/logout') {
              logoutStarted.complete();
              await releaseLogout.future;
              handler.resolve(
                Response<Object?>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {'revoked': 1},
                ),
              );
              return;
            }
            if (options.path == '/api/v1/auth/login') {
              handler.resolve(
                Response<Object?>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'accessToken': 'new-access',
                    'refreshToken': 'new-refresh',
                    'refreshTokenExpiresAt': '2026-08-29T00:00:00.000Z',
                    'user': {
                      'id': 'new-user',
                      'name': 'New User',
                      'phone': '+967777123456',
                      'role': 'USER',
                      'status': 'ACTIVE',
                    },
                  },
                ),
              );
              return;
            }
            handler.next(options);
          },
        ),
      );
      final repository = AuthRepository(client, storage);

      final oldLogout = repository.logout();
      await logoutStarted.future;
      await repository.login(phone: '777123456', password: 'new-password');
      releaseLogout.complete();
      await oldLogout;

      expect(await storage.readAccessToken(), 'new-access');
      expect(await storage.readRefreshToken(), 'new-refresh');
      expect(storage.readUser()?.id, 'new-user');
    });

    test('a delayed refresh cannot overwrite a newer login session', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      await storage.saveSession(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        user: _user('old-user'),
      );
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      final client = ApiClient(tokenProvider: storage.readAccessToken);
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/api/v1/auth/refresh') {
              refreshStarted.complete();
              await releaseRefresh.future;
              handler.resolve(
                Response<Object?>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'accessToken': 'stale-refreshed-access',
                    'refreshToken': 'stale-refreshed-refresh',
                    'refreshTokenExpiresAt': '2026-08-29T00:00:00.000Z',
                    'user': {
                      'id': 'old-user',
                      'name': 'Old User',
                      'phone': '+967700000000',
                      'role': 'USER',
                      'status': 'ACTIVE',
                    },
                  },
                ),
              );
              return;
            }
            if (options.path == '/api/v1/auth/login') {
              handler.resolve(
                Response<Object?>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'accessToken': 'new-access',
                    'refreshToken': 'new-refresh',
                    'refreshTokenExpiresAt': '2026-08-29T00:00:00.000Z',
                    'user': {
                      'id': 'new-user',
                      'name': 'New User',
                      'phone': '+967777123456',
                      'role': 'USER',
                      'status': 'ACTIVE',
                    },
                  },
                ),
              );
              return;
            }
            handler.next(options);
          },
        ),
      );
      final repository = AuthRepository(client, storage);

      final oldRefresh = repository.refreshSession();
      await refreshStarted.future;
      await repository.login(phone: '777123456', password: 'new-password');
      releaseRefresh.complete();

      expect(await oldRefresh, isFalse);
      expect(await storage.readAccessToken(), 'new-access');
      expect(await storage.readRefreshToken(), 'new-refresh');
      expect(storage.readUser()?.id, 'new-user');
    });
  });

  group('Local cache privacy across accounts', () {
    Future<OfflineSyncService> buildService() async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      final apiClient = ApiClient(tokenProvider: () async => null);
      return OfflineSyncService(database: database, apiClient: apiClient);
    }

    test('clearLocalData wipes cached rows and queued writes', () async {
      final service = await buildService();
      await service.database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: {'id': 'cost-1', 'totalAmount': '5000'},
      );
      await service.database.enqueueSync(
        entityType: 'cost',
        operation: 'create',
        endpoint: '/api/v1/wedding-plans/plan-1/costs',
        method: 'POST',
        payload: {'totalAmount': '5000'},
        localEntityId: 'cost-1',
      );

      await service.clearLocalData();

      final rows = await service.database.readCachedList(
        table: OfflineTables.cachedCosts,
      );
      expect(rows, isEmpty);
      expect(await service.database.pendingSyncCount(), 0);
    });

    test(
      'ensureCacheOwner wipes cache when a different account signs in',
      () async {
        final service = await buildService();
        await service.ensureCacheOwner('user-a');
        await service.database.saveCachedItem(
          table: OfflineTables.cachedCosts,
          json: {'id': 'cost-1', 'totalAmount': '200000'},
        );

        await service.ensureCacheOwner('user-b');

        final rows = await service.database.readCachedList(
          table: OfflineTables.cachedCosts,
        );
        expect(
          rows,
          isEmpty,
          reason: "user-b must never see user-a's financial data",
        );
      },
    );

    test('ensureCacheOwner keeps cache for the same account', () async {
      final service = await buildService();
      await service.ensureCacheOwner('user-a');
      await service.database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: {'id': 'cost-1', 'totalAmount': '200000'},
      );

      await service.ensureCacheOwner('user-a');

      final rows = await service.database.readCachedList(
        table: OfflineTables.cachedCosts,
      );
      expect(rows, hasLength(1));
    });

    test('clearPlanContext removes only the exited plan graph', () async {
      final service = await buildService();
      await service.ensureCacheOwner('user-a');
      await service.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: {'id': 'plan-a', 'title': 'Plan A'},
      );
      await service.database.saveCachedItem(
        table: OfflineTables.cachedWeddingPlans,
        json: {'id': 'plan-b', 'title': 'Plan B'},
      );

      await service.clearPlanContext('plan-a');

      final rows = await service.database.readCachedList(
        table: OfflineTables.cachedWeddingPlans,
      );
      expect(rows.map((row) => row['id']), ['plan-b']);
    });
  });

  test('logout publishes terminating before network logout finishes', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final user = SafeUser.fromJson({
      'id': 'user-a',
      'name': 'User A',
      'role': 'USER',
      'status': 'ACTIVE',
    });
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _DelayedLogoutRepository(apiClient, storage, user);
    final controller = AuthController(repository);

    await controller.restoreSession();
    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.id, 'user-a');

    final logout = controller.logout();
    expect(controller.status.name, 'terminating');
    expect(controller.user, isNull);
    expect(repository.boundSessions.last, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(repository.logoutCalled, isTrue);
    expect(controller.user, isNull);
    await logout;
    expect(controller.status, AuthStatus.unauthenticated);
  });

  test(
    'failed restore invalidates cached identity before logout finishes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      final user = SafeUser.fromJson({
        'id': 'stale-user',
        'name': 'Stale User',
        'role': 'USER',
        'status': 'ACTIVE',
      });
      final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
      final repository = _FailedRestoreRepository(apiClient, storage, user);
      final controller = AuthController(repository);

      final restore = controller.restoreSession();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, AuthStatus.terminating);
      expect(controller.user, isNull);
      expect(repository.boundSessions.last, isNull);
      expect(repository.logoutCalled, isTrue);

      await restore;
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
    },
  );

  test(
    'logout hides the old account before push cleanup and blocks replacement login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      final firstUser = SafeUser.fromJson({
        'id': 'user-a',
        'name': 'User A',
        'role': 'USER',
        'status': 'ACTIVE',
      });
      final secondUser = SafeUser.fromJson({
        'id': 'user-b',
        'name': 'User B',
        'role': 'USER',
        'status': 'ACTIVE',
      });
      final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
      final repository = _ConcurrentReloginRepository(
        apiClient,
        storage,
        firstUser,
        secondUser,
      );
      final pushCleanup = Completer<void>();
      final push = _DelayedPushTeardown(pushCleanup);
      final controller = AuthController(
        repository,
        sessionTeardownCoordinator: SessionTeardownCoordinator(
          auth: repository,
          push: push,
          clearLocalAccountData: () async {},
          clearGuestDraft: () async {},
        ),
      );

      await controller.restoreSession();
      final oldLogout = controller.logout();
      expect(controller.status.name, 'terminating');
      expect(controller.user, isNull);

      expect(
        await controller.login(phone: '+967700000002', password: 'secret'),
        isFalse,
      );
      expect(controller.user, isNull);
      pushCleanup.complete();
      await oldLogout;

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
      expect(repository.logoutCalled, isTrue);
    },
  );

  test('local logout failure stays behind a retryable safe gate', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    final user = SafeUser.fromJson({
      'id': 'user-a',
      'name': 'User A',
      'role': 'USER',
      'status': 'ACTIVE',
    });
    final apiClient = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _DelayedLogoutRepository(apiClient, storage, user);
    var failCleanup = true;
    final controller = AuthController(
      repository,
      sessionTeardownCoordinator: SessionTeardownCoordinator(
        auth: repository,
        clearLocalAccountData: () async {
          if (failCleanup) throw StateError('local cleanup failed');
        },
        clearGuestDraft: () async {},
      ),
    );

    await controller.restoreSession();
    await controller.logout();

    expect(controller.status.name, 'terminationFailed');
    expect(controller.user, isNull);
    expect(repository.logoutCalled, isTrue);

    failCleanup = false;
    await controller.logout();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(repository.logoutCalled, isTrue);
  });
}

class _DelayedLogoutRepository extends AuthRepository {
  _DelayedLogoutRepository(super.apiClient, super.authStorage, this.cachedUser);

  final SafeUser cachedUser;
  bool logoutCalled = false;
  final List<String?> boundSessions = [];

  @override
  SafeUser? readCachedUser() => cachedUser;

  @override
  Future<String?> readAccessToken() async => 'token-user-a';

  @override
  Future<SafeUser> me() async => cachedUser;

  @override
  void bindClientSession(String? userId) {
    boundSessions.add(userId);
    super.bindClientSession(userId);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {
    logoutCalled = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

class _FailedRestoreRepository extends _DelayedLogoutRepository {
  _FailedRestoreRepository(
    super.apiClient,
    super.authStorage,
    super.cachedUser,
  );

  @override
  Future<SafeUser> me() async {
    throw const ApiException('expired', statusCode: 401);
  }
}

class _ConcurrentReloginRepository extends _DelayedLogoutRepository {
  _ConcurrentReloginRepository(
    super.apiClient,
    super.authStorage,
    super.cachedUser,
    this.loginUser,
  );

  final SafeUser loginUser;

  @override
  Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    return AuthResponse(accessToken: 'new-token', user: loginUser);
  }
}

class _DelayedPushTeardown implements SessionPushTeardownPort {
  _DelayedPushTeardown(this.remoteCompletion);

  final Completer<void> remoteCompletion;

  @override
  SessionPushTeardownLease beginAccountTeardown(String userId) {
    return SessionPushTeardownLease(userId: userId, installationId: 'fid-a');
  }

  @override
  Future<void> clearLocalRegistration(SessionPushTeardownLease lease) async {}

  @override
  Future<void> unregisterRemote(
    SessionPushTeardownLease lease, {
    required CancelToken cancelToken,
    String? bearerToken,
  }) {
    return remoteCompletion.future;
  }
}
