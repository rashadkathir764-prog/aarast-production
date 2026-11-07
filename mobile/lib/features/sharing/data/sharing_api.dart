import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';
import '../models/plan_access_permissions.dart';
import '../models/contribution_history.dart';

/// Who shares the plan, their rights and invites.
///
/// D85: rights, members, invites, the shared plans and the history are the
/// phone's copy when the server is out of reach. An invite, a right, a
/// removal and leaving reach another person, so they need the server now
/// and say so (D81).
class SharingApi {
  SharingApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineReads _reads;
  final OfflineWrites _writes;

  static const _reachesSomeone = 'هذا يوصل لشخص ثاني، فيحتاج الخادم.';

  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    return PlanAccessPermissions.fromJson(
      await _reads.blob(
        '/api/v1/wedding-plans/$weddingPlanId/permissions/me',
        metaKey: 'plan-permissions:$weddingPlanId',
      ),
    );
  }

  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    final items = await _reads.list(
      '/api/v1/wedding-plans/$weddingPlanId/members',
      table: OfflineTables.cachedPlanMembers,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return items.map(SharedMember.fromJson).toList();
  }

  /// The phone's copy of the members alone.
  Future<List<SharedMember>> cachedSharedMembers(String weddingPlanId) async {
    final rows = await _reads.cachedList(
      OfflineTables.cachedPlanMembers,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return rows.map(SharedMember.fromJson).toList();
  }

  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    final items = await _reads.blobList(
      '/api/v1/wedding-plans/$weddingPlanId/invites',
      metaKey: 'plan-invites:$weddingPlanId',
    );
    return items.map(PlanInvite.fromJson).toList();
  }

  /// The phone's copy of the invites alone, or null before the first answer.
  Future<List<PlanInvite>?> cachedPlanInvites(String weddingPlanId) async {
    final items = await _reads.cachedBlobList('plan-invites:$weddingPlanId');
    return items?.map(PlanInvite.fromJson).toList();
  }

  Future<PlanInvite> createPlanInvite({
    required String weddingPlanId,
    required String phone,
    String? name,
    required String role,
    required bool canViewMoney,
    required bool canEditPlan,
    required bool canManageTasks,
    required bool canManageGuests,
    required bool canManageProviders,
    required bool canInviteMembers,
    required bool canManageMoney,
    required bool receiveNotifications,
    int expiresInDays = 7,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final json = await _writes.serverOnly(
      reason: 'الدعوة تُرسل من رقم اعّرست، فتحتاج الخادم.',
      method: 'POST',
      path: '/api/v1/wedding-plans/$weddingPlanId/invites',
      body: {
        'phone': normalizedPhone,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'role': role,
        'canViewMoney': canViewMoney || canManageMoney,
        'canEditPlan': canEditPlan,
        'canManageTasks': canManageTasks,
        'canManageGuests': canManageGuests,
        'canManageProviders': canManageProviders,
        'canInviteMembers': canInviteMembers,
        'canManageMoney': canManageMoney,
        'receiveNotifications': receiveNotifications,
        'expiresInDays': expiresInDays,
      },
    );
    return PlanInvite.fromJson(json);
  }

  Future<void> cancelPlanInvite({
    required String weddingPlanId,
    required String inviteId,
  }) async {
    await _writes.serverOnly(
      reason: _reachesSomeone,
      method: 'DELETE',
      path: '/api/v1/wedding-plans/$weddingPlanId/invites/$inviteId',
    );
  }

  Future<PlanInvite> reissuePlanInvite({
    required String weddingPlanId,
    required String inviteId,
    String? role,
    bool? canViewMoney,
    bool? canEditPlan,
    bool? canManageTasks,
    bool? canManageGuests,
    bool? canManageProviders,
    bool? canInviteMembers,
    bool? canManageMoney,
    bool? receiveNotifications,
  }) async {
    final json = await _writes.serverOnly(
      reason: 'التذكير يُرسل من رقم اعّرست، فيحتاج الخادم.',
      method: 'POST',
      path: '/api/v1/wedding-plans/$weddingPlanId/invites/$inviteId/reissue',
      body: {
        'role': ?role,
        'canViewMoney': ?canViewMoney,
        'canEditPlan': ?canEditPlan,
        'canManageTasks': ?canManageTasks,
        'canManageGuests': ?canManageGuests,
        'canManageProviders': ?canManageProviders,
        'canInviteMembers': ?canInviteMembers,
        'canManageMoney': ?canManageMoney,
        'receiveNotifications': ?receiveNotifications,
      },
    );
    return PlanInvite.fromJson(json);
  }

  Future<PlanInvite> getInvite(String token) async {
    final json = await _writes.serverOnly(
      reason: 'الدعوة تُقرأ من الخادم.',
      method: 'GET',
      path: '/api/v1/invites/$token',
    );
    return _currentUserInviteFromJson(json);
  }

  Future<List<PlanInvite>> getMyInvites() async {
    final items = await _reads.blobList(
      '/api/v1/invites/mine',
      metaKey: 'my-invites',
    );
    return items.map(_currentUserInviteFromJson).toList();
  }

  Future<AcceptedPlanInvite> acceptInvite(String token) async {
    final json = await _writes.serverOnly(
      reason: 'القبول يسجّلك في الخطة عند الخادم.',
      method: 'POST',
      path: '/api/v1/invites/$token/accept',
    );
    final invite = PlanInvite.fromJson(
      Map<String, dynamic>.from(json['invite'] as Map),
    );
    final rawContextKey = json['contextKey'];
    if (rawContextKey is! String ||
        rawContextKey.isEmpty ||
        rawContextKey.trim() != rawContextKey) {
      throw const FormatException(
        'Accepted invite response must include a canonical contextKey',
      );
    }
    if (rawContextKey != 'plan:${invite.weddingPlanId}:contributor') {
      throw const FormatException(
        'Accepted invite contextKey does not match the invited plan',
      );
    }
    return AcceptedPlanInvite(
      invite: invite,
      member: SharedMember.fromJson(
        Map<String, dynamic>.from(json['member'] as Map),
      ),
      contextKey: rawContextKey,
    );
  }

  Future<PlanInvite> declineInvite(String token) async {
    final json = await _writes.serverOnly(
      reason: _reachesSomeone,
      method: 'POST',
      path: '/api/v1/invites/$token/decline',
    );
    return PlanInvite.fromJson(json);
  }

  Future<SharedMember> updateSharedMember(
    String weddingPlanId,
    String id,
    Map<String, dynamic> data,
  ) async {
    final json = await _writes.serverOnly(
      reason: _reachesSomeone,
      method: 'PATCH',
      path: '/api/v1/wedding-plans/$weddingPlanId/members/$id',
      body: data,
    );
    return SharedMember.fromJson(json);
  }

  Future<void> deleteSharedMember(String weddingPlanId, String id) async {
    await _writes.serverOnly(
      reason: _reachesSomeone,
      method: 'DELETE',
      path: '/api/v1/wedding-plans/$weddingPlanId/members/$id',
    );
  }

  /// Leaves the authenticated member's current plan membership.
  ///
  /// This is deliberately the server's: callers retain [clientRequestId]
  /// for a user-triggered retry after an ambiguous response, rather than
  /// placing a membership removal in the planning offline queue.
  Future<void> leaveCurrentPlan({
    required String weddingPlanId,
    required String expectedMemberId,
    required int expectedAuthorityVersion,
    required String clientRequestId,
  }) async {
    await _writes.serverOnly(
      reason: 'الخروج من الخطة يُسجَّل عند الخادم.',
      method: 'DELETE',
      path: '/api/v1/wedding-plans/$weddingPlanId/members/me',
      body: {
        'expectedMemberId': expectedMemberId,
        'expectedAuthorityVersion': expectedAuthorityVersion,
      },
      clientRequestId: clientRequestId,
    );
  }

  /// One page of the plan's frozen history. The owner may narrow it to one
  /// participant with [contributorUserId]; a participant always gets their
  /// own. [section] is `TASKS`, `GUESTS`, `MONEY`, `PROVIDERS`, ...
  Future<ContributionHistoryResponse> getContributionHistory(
    String weddingPlanId, {
    int limit = 100,
    int offset = 0,
    String? section,
    String? contributorUserId,
  }) async {
    final path = Uri(
      path: '/api/v1/wedding-plans/$weddingPlanId/contributions',
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
        'section': ?section,
        'contributorUserId': ?contributorUserId,
      },
    ).toString();
    return ContributionHistoryResponse.fromJson(
      await _reads.blob(path, metaKey: 'contributions:$path'),
    );
  }

  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async {
    final items = await _reads.blobList(
      '/api/v1/shared/wedding-plans',
      metaKey: 'shared_wedding_plans',
    );
    return items.map(SharedWeddingPlan.fromJson).toList();
  }

  PlanInvite _currentUserInviteFromJson(Map<String, dynamic> json) {
    return PlanInvite.fromJson(json);
  }

  String _normalizePhone(String phone) {
    try {
      return normalizeYemeniPhone(phone);
    } on FormatException {
      throw const ApiException('رقم الهاتف غير صحيح');
    }
  }
}

class AcceptedPlanInvite {
  const AcceptedPlanInvite({
    required this.invite,
    required this.member,
    required this.contextKey,
  });

  final PlanInvite invite;
  final SharedMember member;
  final String contextKey;
}
