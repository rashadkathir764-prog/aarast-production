import 'package:aarast_mobile/features/sharing/models/plan_role_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('family and helper presets do not expose money by default', () {
    for (final role in ['FAMILY', 'HELPER']) {
      final permissions = PlanRolePermissions.forRole(role);
      expect(permissions.canViewMoney, isFalse);
      expect(permissions.canManageMoney, isFalse);
      expect(permissions.canManageTasks, isTrue);
      expect(permissions.canManageGuests, isTrue);
    }
  });

  test('groom and bride presets support plan, providers, and money', () {
    for (final role in ['GROOM', 'BRIDE']) {
      final permissions = PlanRolePermissions.forRole(role);
      expect(permissions.canEditPlan, isTrue);
      expect(permissions.canManageProviders, isTrue);
      expect(permissions.canManageMoney, isTrue);
    }
  });

  test('money management always grants money visibility', () {
    final permissions = PlanRolePermissions.forRole(
      'VIEWER',
    ).copyWith(canManageMoney: true);

    expect(permissions.canViewMoney, isTrue);
    expect(permissions.canManageMoney, isTrue);

    final member = SharedMember.fromJson({
      'id': 'member-1',
      'weddingPlanId': 'plan-1',
      'userId': 'user-1',
      'role': 'VIEWER',
      'canManageMoney': true,
    });
    expect(member.canViewMoney, isTrue);
    expect(member.canManageMoney, isTrue);
  });

  test('pending plan invitation parses role and participant identity', () {
    final invite = PlanInvite.fromJson({
      'id': 'invite-1',
      'weddingPlanId': 'plan-1',
      'token': 'safe-token',
      'name': 'أحمد',
      'normalizedPhone': '+967777758200',
      'role': 'HELPER',
      'status': 'PENDING',
      'expiresAt': '2026-07-10T00:00:00.000Z',
      'weddingPlan': {'title': 'خطة الزفاف'},
    });

    expect(invite.isPending, isTrue);
    expect(invite.displayName, 'أحمد');
    expect(sharedMemberRoleLabel(invite.role), 'مساعد');
    expect(invite.weddingPlanTitle, 'خطة الزفاف');
  });

  test('only DELIVERED confirms an Aarast invitation delivery', () {
    PlanInvite parse(String deliveryStatus) => PlanInvite.fromJson({
      'id': 'invite-$deliveryStatus',
      'weddingPlanId': 'plan-1',
      'token': 'safe-token',
      'role': 'HELPER',
      'status': 'PENDING',
      'expiresAt': '2026-07-20T00:00:00.000Z',
      'delivery': {'status': deliveryStatus},
    });

    expect(parse('DELIVERED').wasDeliveredByAarast, isTrue);
    expect(parse('PENDING').wasDeliveredByAarast, isFalse);
    expect(parse('UNCERTAIN').wasDeliveredByAarast, isFalse);
    expect(parse('SENT').wasDeliveredByAarast, isFalse);
    expect(parse('UNCERTAIN').hasUncertainDelivery, isTrue);
    expect(parse('UNKNOWN').hasUnknownDelivery, isTrue);
    expect(parse('UNKNOWN').deliverySummaryLabel, 'حالة الإرسال غير معروفة');
  });

  test('invitation delivery cooldown survives parsing and identity copies', () {
    final invite = PlanInvite.fromJson({
      'id': 'invite-cooldown',
      'weddingPlanId': 'plan-1',
      'token': 'one-time-token',
      'role': 'HELPER',
      'status': 'PENDING',
      'expiresAt': '2026-07-20T00:00:00.000Z',
      'delivery': {
        'status': 'UNCERTAIN',
        'attemptedAt': '2026-07-18T10:00:00.000Z',
        'retryAfterSeconds': 60,
      },
    });

    expect(invite.deliveryAttemptedAt, DateTime.utc(2026, 7, 18, 10));
    expect(invite.deliveryRetryRemainingSeconds, inInclusiveRange(59, 60));
    expect(invite.canRetryDelivery, isFalse);

    final listedCopy = invite.withIdentityToken();
    expect(listedCopy.token, invite.id);
    expect(listedCopy.deliveryAttemptedAt, invite.deliveryAttemptedAt);
    expect(
      listedCopy.deliveryRetryAvailableAt,
      invite.deliveryRetryAvailableAt,
    );
    expect(listedCopy.canRetryDelivery, isFalse);
  });
}
