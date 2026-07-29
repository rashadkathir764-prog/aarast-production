import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';
import '../models/plan_access_permissions.dart';

class SharingApi {
  const SharingApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    final json = await _apiClient.getJson(
      '/api/v1/wedding-plans/$weddingPlanId/permissions/me',
    );
    return PlanAccessPermissions.fromJson(json);
  }

  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    try {
      final items = await _getJsonMapList(
        '/api/v1/wedding-plans/$weddingPlanId/members',
      );
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedPlanMembers,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(SharedMember.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.readCachedList(
        table: OfflineTables.cachedPlanMembers,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached.isEmpty) rethrow;
      return cached.map(SharedMember.fromJson).toList();
    }
  }

  Future<SharedUserLookup> lookupUserByPhone(
    String weddingPlanId,
    String phone,
  ) async {
    final normalizedPhone = _normalizePhone(phone);
    final json = await _apiClient.getJson(
      Uri(
        path: '/api/v1/users/lookup',
        queryParameters: {
          'weddingPlanId': weddingPlanId,
          'phone': normalizedPhone,
        },
      ).toString(),
    );
    return SharedUserLookup.fromJson(json);
  }

  Future<SharedMember> createSharedMember({
    required String weddingPlanId,
    String? userId,
    String? phone,
    required String role,
    required bool canViewMoney,
    required bool canManageTasks,
    required bool canManageMoney,
  }) async {
    final normalizedPhone = _normalizeOptionalPhone(phone);
    final payload = {
      if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
      'role': role,
      'canViewMoney': canViewMoney || canManageMoney,
      'canManageTasks': canManageTasks,
      'canManageMoney': canManageMoney,
    };
    if (normalizedPhone != null) {
      payload['phone'] = normalizedPhone;
    }
    final json = await _apiClient.postJson(
      '/api/v1/wedding-plans/$weddingPlanId/members',
      payload,
    );
    return SharedMember.fromJson(json);
  }

  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    final items = await _getJsonMapList(
      '/api/v1/wedding-plans/$weddingPlanId/invites',
    );
    return items.map(PlanInvite.fromJson).toList();
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
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final json = await _apiClient
        .postJson('/api/v1/wedding-plans/$weddingPlanId/invites', {
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
        });
    return PlanInvite.fromJson(json);
  }

  Future<void> cancelPlanInvite({
    required String weddingPlanId,
    required String inviteId,
  }) async {
    await _apiClient.deleteJson(
      '/api/v1/wedding-plans/$weddingPlanId/invites/$inviteId',
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
    final json = await _apiClient.postJson(
      '/api/v1/wedding-plans/$weddingPlanId/invites/$inviteId/reissue',
      {
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
    final json = await _apiClient.getJson('/api/v1/invites/$token');
    return _currentUserInviteFromJson(json);
  }

  Future<List<PlanInvite>> getMyInvites() async {
    final items = await _getJsonMapList('/api/v1/invites/mine');
    return items.map(_currentUserInviteFromJson).toList();
  }

  Future<AcceptedPlanInvite> acceptInvite(String token) async {
    final json = await _apiClient.postJson(
      '/api/v1/invites/$token/accept',
      const {},
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
    final json = await _apiClient.postJson(
      '/api/v1/invites/$token/decline',
      const {},
    );
    return PlanInvite.fromJson(json);
  }

  Future<SharedMember> updateSharedMember(
    String weddingPlanId,
    String id,
    Map<String, dynamic> data,
  ) async {
    final json = await _apiClient.patchJson(
      '/api/v1/wedding-plans/$weddingPlanId/members/$id',
      data,
    );
    return SharedMember.fromJson(json);
  }

  Future<void> deleteSharedMember(String weddingPlanId, String id) async {
    await _apiClient.deleteJson(
      '/api/v1/wedding-plans/$weddingPlanId/members/$id',
    );
  }

  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async {
    const key = 'shared_wedding_plans';
    try {
      final items = await _getJsonMapList('/api/v1/shared/wedding-plans');
      await _offline?.database.setMeta(key, jsonEncode(items));
      return items.map(SharedWeddingPlan.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                SharedWeddingPlan.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  PlanInvite _currentUserInviteFromJson(Map<String, dynamic> json) {
    final invite = PlanInvite.fromJson(json);
    if (invite.isAccepted && invite.contextKey == null) {
      throw const FormatException(
        'Accepted current-user invite must include contextKey',
      );
    }
    return invite;
  }

  String _normalizePhone(String phone) {
    try {
      return normalizeYemeniPhone(phone);
    } on FormatException {
      throw const ApiException('رقم الهاتف غير صحيح');
    }
  }

  String? _normalizeOptionalPhone(String? phone) {
    try {
      return normalizeOptionalYemeniPhone(phone);
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
