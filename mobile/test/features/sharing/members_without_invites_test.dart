import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-194 (batch 5): the participants and the invites were read as one.
// The invites are for who may invite; the server answers a helper 404 for
// them, and that answer failed the whole read: a helper got no participants
// at all, so no name stood on any task and «أنا» could not be saved.
void main() {
  test(
    'a reader who may not see the invites still gets the participants',
    () async {
      for (final status in [403, 404]) {
        final provider = SharingProvider(_Api(invitesStatus: status));

        await provider.loadMembers('plan-1');

        expect(provider.members.single.user?.name, 'صالح', reason: '$status');
        expect(provider.invites, isEmpty);
        expect(provider.errorMessage, isNull);
      }
    },
  );

  test('any other failure of the invites is still a failed read', () async {
    final provider = SharingProvider(_Api(invitesStatus: 500));

    await provider.loadMembers('plan-1');

    expect(provider.members, isEmpty);
    expect(provider.errorMessage, isNotNull);
  });
}

class _Api extends SharingApi {
  _Api({required this.invitesStatus})
    : super(ApiClient(tokenProvider: () async => null));

  final int invitesStatus;

  @override
  Future<List<SharedMember>> cachedSharedMembers(String weddingPlanId) async =>
      const [];

  @override
  Future<List<PlanInvite>?> cachedPlanInvites(String weddingPlanId) async =>
      null;

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async => [
    SharedMember(
      id: 'member-1',
      weddingPlanId: 'plan-1',
      userId: 'user-1',
      user: const SharedMemberUser(
        id: 'user-1',
        name: 'صالح',
        phone: '+967771554220',
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
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async =>
      throw ApiException('الخطة غير موجودة', statusCode: invitesStatus);
}
