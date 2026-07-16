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

  test(
    'builds one private HTTPS link and a correctly encoded WhatsApp URI',
    () {
      final content = InviteShareContent.fromInvite(invite());
      final link = content.inviteLink.toString();

      expect(link, 'https://aarast.shadowgardn.com/invites/$rawToken');
      expect(rawToken.allMatches(content.message), hasLength(1));
      expect(content.message, contains('رشاد'));
      expect(content.message, contains('عرس رشاد وسارة'));
      expect(content.message, contains('هذا الرابط خاص بك'));

      final whatsapp = content.whatsappUri;
      expect(whatsapp.scheme, 'https');
      expect(whatsapp.host, 'wa.me');
      expect(whatsapp.path, '/967777123456');
      expect(whatsapp.queryParameters['text'], content.message);
    },
  );

  test('uses safe generic wording when optional invite labels are absent', () {
    final content = InviteShareContent(
      token: rawToken,
      recipientPhone: '777123456',
    );

    expect(content.message, contains('صاحب الخطة'));
    expect(content.message, contains('خطة الزفاف'));
    expect(content.whatsappUri.path, '/967777123456');
  });

  test('rejects malformed or missing bearer tokens in release code', () {
    expect(
      () => InviteShareContent(
        token: 'invite-id-not-a-bearer-token',
        recipientPhone: '777123456',
      ),
      throwsFormatException,
    );
    expect(
      () => InviteShareContent(
        token: '$rawToken!',
        recipientPhone: '777123456',
      ),
      throwsFormatException,
    );
  });
}
