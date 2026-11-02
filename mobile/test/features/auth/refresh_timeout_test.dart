import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Field test Q15: the server rotates the refresh token as soon as it accepts
// a refresh and treats a second use of the old one as theft. A refresh the
// app abandoned early on a slow network would end the session at the next
// one, so the refresh waits longer than ordinary reads.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a session refresh waits 30 seconds for the server', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    await storage.saveSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      user: SafeUser.fromJson({
        'id': 'user-1',
        'name': 'مستخدم',
        'phone': '+967700000000',
      }),
    );
    final client = ApiClient(tokenProvider: storage.readAccessToken);
    Duration? refreshWait;
    Duration? ordinaryWait;
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/v1/auth/refresh') {
            refreshWait = options.receiveTimeout;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'accessToken': 'access-2',
                  'refreshToken': 'refresh-2',
                  'refreshTokenExpiresAt': '2026-12-01T00:00:00.000Z',
                  'user': {
                    'id': 'user-1',
                    'name': 'مستخدم',
                    'phone': '+967700000000',
                    'role': 'USER',
                    'status': 'ACTIVE',
                  },
                },
              ),
            );
            return;
          }
          ordinaryWait = options.receiveTimeout;
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {},
            ),
          );
        },
      ),
    );

    final refreshed = await AuthRepository(client, storage).refreshSession();
    await client.getJson('/api/v1/dashboard/home');

    expect(refreshed, isTrue);
    expect(refreshWait, AuthRepository.refreshReceiveTimeout);
    expect(AuthRepository.refreshReceiveTimeout, const Duration(seconds: 30));
    expect(ordinaryWait, const Duration(seconds: 12));
    expect(
      await storage.readRefreshTokenIfEpoch(storage.sessionEpoch),
      'refresh-2',
    );
  });
}
