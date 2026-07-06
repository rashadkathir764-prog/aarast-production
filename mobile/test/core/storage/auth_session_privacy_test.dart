import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/token_vault.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';

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

    test(
      'access-only sessions clear any stale refresh token',
      () async {
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
      },
    );

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
        table: OfflineTables.cachedBudgetItems,
        json: {'id': 'exp-1', 'amount': '5000'},
      );
      await service.database.enqueueSync(
        entityType: 'expense',
        operation: 'create',
        endpoint: '/expenses',
        method: 'POST',
        payload: {'amount': '5000'},
        localEntityId: 'exp-1',
      );

      await service.clearLocalData();

      final rows = await service.database.readCachedList(
        table: OfflineTables.cachedBudgetItems,
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
          table: OfflineTables.cachedDebts,
          json: {'id': 'debt-1', 'amount': '200000'},
        );

        await service.ensureCacheOwner('user-b');

        final rows = await service.database.readCachedList(
          table: OfflineTables.cachedDebts,
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
        table: OfflineTables.cachedDebts,
        json: {'id': 'debt-1', 'amount': '200000'},
      );

      await service.ensureCacheOwner('user-a');

      final rows = await service.database.readCachedList(
        table: OfflineTables.cachedDebts,
      );
      expect(rows, hasLength(1));
    });
  });
}
