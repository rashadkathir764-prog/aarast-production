import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-271 (batch 8): cancelling an invite that was accepted a moment ago
// said «ما قدرنا نلغي الدعوة.» with no reason, and the row stayed under
// «ينتظرون». The owner was never told the person is now a participant.
void main() {
  test(
    'an invite that stopped waiting says so and the list is read again',
    () async {
      final api = _Api(
        cancelFailure: const ApiException(
          'Invite is no longer pending',
          statusCode: 409,
        ),
      );
      final provider = SharingProvider(api);
      await provider.loadMembers('plan-1');
      expect(provider.invites, hasLength(1));
      expect(provider.members, isEmpty);

      // The invitee accepted meanwhile.
      api.accepted = true;
      final cancelled = await provider.cancelInvite(provider.invites.single);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cancelled, isFalse);
      expect(provider.errorMessage, contains('ما عادت تنتظر'));
      expect(provider.invites, isEmpty);
      expect(provider.members.single.user?.name, 'خالد');
    },
  );

  test('a server out of reach keeps the invite and says the reason', () async {
    final api = _Api(
      cancelFailure: const ApiException(
        'ما في نت الآن. تأكد من الاتصال.',
        isNetworkFailure: true,
      ),
    );
    final provider = SharingProvider(api);
    await provider.loadMembers('plan-1');

    final cancelled = await provider.cancelInvite(provider.invites.single);

    expect(cancelled, isFalse);
    expect(provider.errorMessage, 'ما في نت الآن. تأكد من الاتصال.');
    expect(provider.invites, hasLength(1));
  });
}

class _Api extends SharingApi {
  _Api({required this.cancelFailure})
    : super(ApiClient(tokenProvider: () async => null));

  final ApiException cancelFailure;
  bool accepted = false;

  @override
  Future<List<SharedMember>> cachedSharedMembers(String weddingPlanId) async =>
      const [];

  @override
  Future<List<PlanInvite>?> cachedPlanInvites(String weddingPlanId) async =>
      null;

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async => [
    if (accepted)
      SharedMember(
        id: 'member-1',
        weddingPlanId: 'plan-1',
        userId: 'user-1',
        user: const SharedMemberUser(
          id: 'user-1',
          name: 'خالد',
          phone: '+967777123456',
        ),
        role: 'HELPER',
        canViewMoney: false,
        canEditPlan: false,
        canManageTasks: true,
        canManageGuests: true,
        canInviteMembers: false,
        canManageMoney: false,
        createdAt: DateTime(2026, 7, 16),
        updatedAt: DateTime(2026, 7, 16),
      ),
  ];

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async => [
    if (!accepted)
      PlanInvite(
        id: 'invite-1',
        weddingPlanId: 'plan-1',
        token: 'invite-token',
        role: 'HELPER',
        status: 'PENDING',
        expiresAt: DateTime(2026, 7, 20),
        canViewMoney: false,
        canEditPlan: false,
        canManageTasks: true,
        canManageGuests: true,
        canManageProviders: false,
        canInviteMembers: false,
        canManageMoney: false,
        deliveryStatus: 'NOT_REQUESTED',
        phone: '+967777123456',
        name: 'خالد',
      ),
  ];

  @override
  Future<void> cancelPlanInvite({
    required String weddingPlanId,
    required String inviteId,
  }) async => throw cancelFailure;
}
