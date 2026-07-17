import 'package:aarast_mobile/features/sharing/models/invite_share_content.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawToken = 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789';

  PlanInvite invite() {
    return PlanInvite(
      id: 'invite-1',
      weddingPlanId: 'plan-1',
      token: rawToken,
      role: 'VIEWER',
      status: 'PENDING',
      expiresAt: DateTime(2026, 8),
      canViewMoney: false,
      canEditPlan: false,
      canManageTasks: false,
      canManageGuests: false,
      canManageProviders: false,
      canInviteMembers: false,
      canManageMoney: false,
      phone: '+967777123456',
      inviterName: 'رشاد',
      weddingPlanTitle: 'عرس رشاد وسارة',
    );
  }

  test('builds the one private HTTPS link handed to the recipient', () {
    final content = InviteShareContent.fromInvite(invite());
    expect(
      content.inviteLink.toString(),
      'https://aarast.shadowgardn.com/invites/$rawToken',
    );
  });

  test('rejects malformed or missing bearer tokens in release code', () {
    expect(
      () => InviteShareContent(token: 'invite-id-not-a-bearer-token'),
      throwsFormatException,
    );
    expect(
      () => InviteShareContent(token: '$rawToken!'),
      throwsFormatException,
    );
  });
}
