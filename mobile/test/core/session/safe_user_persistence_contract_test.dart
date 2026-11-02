import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists and restores every session-principal field exactly', () {
    final phoneVerifiedAt = DateTime.parse('2026-01-02T03:04:05.000Z');
    final lastLoginAt = DateTime.parse('2026-02-03T04:05:06.000Z');
    final onboardingCompletedAt = DateTime.parse('2026-03-04T05:06:07.000Z');
    final user = SafeUser(
      id: 'user-123',
      name: 'مستخدم اعّرست',
      phone: '+967700000001',
      email: 'user@example.test',
      avatarUrl: 'https://example.test/avatar.webp',
      role: 'USER',
      appRole: 'PROVIDER',
      status: 'ACTIVE',
      locale: 'ar-YE',
      activeWeddingPlanId: 'plan-456',
      onboardingPath: 'GROOM',
      persona: 'OWNER',
      hasPassword: true,
      phoneVerifiedAt: phoneVerifiedAt,
      lastLoginAt: lastLoginAt,
      onboardingCompletedAt: onboardingCompletedAt,
      deletionRequestedAt: DateTime.parse('2026-10-19T09:00:00.000Z'),
      deletionScheduledFor: DateTime.parse('2026-11-18T09:00:00.000Z'),
    );

    final json = user.toJson();

    expect(json, {
      'id': 'user-123',
      'name': 'مستخدم اعّرست',
      'phone': '+967700000001',
      'email': 'user@example.test',
      'avatarUrl': 'https://example.test/avatar.webp',
      'role': 'USER',
      'appRole': 'PROVIDER',
      'status': 'ACTIVE',
      'locale': 'ar-YE',
      'activeWeddingPlanId': 'plan-456',
      'onboardingPath': 'GROOM',
      'persona': 'OWNER',
      // D75: a password is optional; the session knows whether there is one.
      'hasPassword': true,
      'phoneVerifiedAt': '2026-01-02T03:04:05.000Z',
      'lastLoginAt': '2026-02-03T04:05:06.000Z',
      'onboardingCompletedAt': '2026-03-04T05:06:07.000Z',
      // D63: the account's pending deletion (w06).
      'deletion': {
        'requestedAt': '2026-10-19T09:00:00.000Z',
        'scheduledFor': '2026-11-18T09:00:00.000Z',
      },
    });

    final restored = SafeUser.fromJson(json);
    expect(restored.deletionPending, isTrue);
    expect(
      restored.deletionScheduledFor,
      DateTime.parse('2026-11-18T09:00:00.000Z'),
    );
    expect(restored.id, user.id);
    expect(restored.name, user.name);
    expect(restored.phone, user.phone);
    expect(restored.email, user.email);
    expect(restored.avatarUrl, user.avatarUrl);
    expect(restored.role, user.role);
    expect(restored.appRole, user.appRole);
    expect(restored.status, user.status);
    expect(restored.locale, user.locale);
    expect(restored.activeWeddingPlanId, user.activeWeddingPlanId);
    expect(restored.onboardingPath, user.onboardingPath);
    expect(restored.persona, user.persona);
    expect(restored.hasPassword, isTrue);
    expect(restored.phoneVerifiedAt, phoneVerifiedAt);
    expect(restored.lastLoginAt, lastLoginAt);
    expect(restored.onboardingCompletedAt, onboardingCompletedAt);
    expect(restored.isProviderAccount, isTrue);
    expect(restored.isWeddingUserAccount, isFalse);
  });

  test('restores the minimal pre-R9 principal with legacy defaults', () {
    final restored = SafeUser.fromJson({
      'id': 'legacy-user',
      'name': 'Legacy User',
      'role': 'USER',
      'status': 'ACTIVE',
    });

    expect(restored.appRole, 'WEDDING_USER');
    expect(restored.locale, 'ar');
    // An older session knows of no password: none is assumed.
    expect(restored.hasPassword, isFalse);
    expect(restored.phoneVerifiedAt, isNull);
    expect(restored.lastLoginAt, isNull);
    expect(restored.onboardingCompletedAt, isNull);
    expect(restored.isProviderAccount, isFalse);
    expect(restored.isWeddingUserAccount, isTrue);
    expect(restored.toJson(), {
      'id': 'legacy-user',
      'name': 'Legacy User',
      'phone': null,
      'email': null,
      'avatarUrl': null,
      'role': 'USER',
      'appRole': 'WEDDING_USER',
      'status': 'ACTIVE',
      'locale': 'ar',
      'activeWeddingPlanId': null,
      'onboardingPath': null,
      'persona': null,
      'hasPassword': false,
      'phoneVerifiedAt': null,
      'lastLoginAt': null,
      'onboardingCompletedAt': null,
      'deletion': null,
    });
    expect(restored.deletionPending, isFalse);
  });
}
