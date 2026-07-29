import 'package:aarast_mobile/features/auth/models/auth_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects access-token-only auth responses', () {
    expect(
      () => AuthResponse.fromJson({
        'accessToken': 'access-token',
        'user': {'id': 'user-1', 'name': 'Test User', 'phone': '+967777758200'},
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('preserves account routing fields from safe user responses', () {
    final response = AuthResponse.fromJson({
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'refreshTokenExpiresAt': '2026-08-05T00:00:00.000Z',
      'user': {
        'id': 'provider-user',
        'name': 'Provider User',
        'phone': '+967777758200',
        'role': 'PROVIDER',
        'appRole': 'PROVIDER',
        'status': 'ACTIVE',
        'activeWeddingPlanId': null,
        'onboardingPath': 'PROVIDER',
        'persona': null,
        'lastLoginAt': '2026-07-06T00:00:00.000Z',
      },
    });

    expect(response.user.role, 'PROVIDER');
    expect(response.user.appRole, 'PROVIDER');
    expect(response.user.onboardingPath, 'PROVIDER');
    expect(response.user.lastLoginAt, DateTime.utc(2026, 7, 6));
    expect(response.user.isProviderAccount, isTrue);
    expect(response.user.toJson()['appRole'], 'PROVIDER');
  });

  test('requires refresh expiry when a refresh token is present', () {
    expect(
      () => AuthResponse.fromJson({
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'user': {'id': 'user-1', 'name': 'Test User', 'phone': '+967777758200'},
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
