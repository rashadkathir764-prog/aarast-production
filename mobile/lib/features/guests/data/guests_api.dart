import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../models/guest.dart';

class GuestsApi {
  const GuestsApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  /// Reads keep the last server copy on this (encrypted) device, so the guest
  /// list still opens without a connection; changes still need one.
  Future<List<Guest>> getGuests(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _cachedGuests(weddingPlanId);
    }
    try {
      final items = (await _apiClient.getJsonList(
        '/api/v1/wedding-plans/$weddingPlanId/guests',
      )).whereType<Map>().map((item) => Map<String, dynamic>.from(item));
      final list = items.toList();
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedGuests,
        items: list,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return list.map(Guest.fromJson).toList();
    } on Object catch (error) {
      if (!await _canReadOffline(error)) rethrow;
      final cached = await _cachedGuests(weddingPlanId);
      // No saved copy: report the failure instead of an empty guest list.
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return GuestSummary.fromGuests(
        weddingPlanId: weddingPlanId,
        guests: localGuests ?? await _cachedGuests(weddingPlanId),
        groups: localGroups ?? const [],
      );
    }
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$weddingPlanId/guests/summary',
      );
      return GuestSummary.fromJson(json);
    } on Object catch (error) {
      if (!await _canReadOffline(error)) rethrow;
      return GuestSummary.fromGuests(
        weddingPlanId: weddingPlanId,
        guests: localGuests ?? await _cachedGuests(weddingPlanId),
        groups: localGroups ?? await _cachedGroups(weddingPlanId),
      );
    }
  }

  Future<List<GuestGroup>> getGroups(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) return const [];
    try {
      final list = (await _apiClient.getJsonList(
        '/api/v1/wedding-plans/$weddingPlanId/guest-groups',
      )).whereType<Map>().map((item) => Map<String, dynamic>.from(item));
      final items = list.toList();
      await _offline?.database.setMeta(
        _groupsCacheKey(weddingPlanId),
        jsonEncode(items),
      );
      return items.map(GuestGroup.fromJson).toList();
    } on Object catch (error) {
      if (!await _canReadOffline(error)) rethrow;
      return _cachedGroups(weddingPlanId);
    }
  }

  /// A network failure with a device cache to fall back on.
  Future<bool> _canReadOffline(Object error) async {
    final offline = _offline;
    if (!CachePolicy.shouldUseCache(error) || offline == null) return false;
    await offline.noteNetworkFailure((error as ApiException).message);
    return true;
  }

  String _groupsCacheKey(String weddingPlanId) => 'guest-groups:$weddingPlanId';

  Future<List<GuestGroup>> _cachedGroups(String weddingPlanId) async {
    final raw = await _offline?.database.getMeta(
      _groupsCacheKey(weddingPlanId),
    );
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) GuestGroup.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<GuestGroup> createGroup({
    required String weddingPlanId,
    required String name,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/wedding-plans/$weddingPlanId/guest-groups',
      {'name': name.trim()},
    );
    return GuestGroup.fromJson(json);
  }

  Future<GuestGroup> renameGroup(GuestGroup group, String name) async {
    final json = await _apiClient.patchJson(
      '/api/v1/guest-groups/${group.id}',
      {'name': name.trim()},
    );
    return GuestGroup.fromJson(json);
  }

  /// The server keeps the group's guests and only clears their group.
  Future<void> deleteGroup(GuestGroup group) async {
    await _apiClient.deleteJson('/api/v1/guest-groups/${group.id}');
  }

  Future<Guest> createGuest({
    required String weddingPlanId,
    required String name,
    String? phone,
    String? groupId,
    required String side,
    required String status,
    String? attendanceStatus,
    required int seatsCount,
    int? companionsCount,
    String? notes,
  }) async {
    final normalizedPhone = _normalizeOptionalPhone(phone);
    final normalizedGroupId = groupId?.trim();
    final payload = {
      'name': name.trim(),
      'side': side,
      'status': status,
      'seatsCount': seatsCount,
    };
    if (normalizedGroupId != null && normalizedGroupId.isNotEmpty) {
      payload['groupId'] = normalizedGroupId;
    }
    final normalizedAttendanceStatus = attendanceStatus?.trim();
    if (normalizedAttendanceStatus != null &&
        normalizedAttendanceStatus.isNotEmpty) {
      payload['attendanceStatus'] = normalizedAttendanceStatus;
    }
    if (companionsCount != null) {
      payload['companionsCount'] = companionsCount;
    }
    final normalizedNotes = notes?.trim();
    if (normalizedNotes != null && normalizedNotes.isNotEmpty) {
      payload['notes'] = normalizedNotes;
    }
    if (normalizedPhone != null) {
      payload['phone'] = normalizedPhone;
    }
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _createLocalGuest(weddingPlanId: weddingPlanId, payload: payload);
    }
    final json = await _apiClient.postJson(
      '/api/v1/wedding-plans/$weddingPlanId/guests',
      payload,
    );
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: json,
    );
    return Guest.fromJson(json);
  }

  /// e03 / w28: many guests in one go, at most 200 per call. The server
  /// takes them all or none, so duplicates are left out before calling.
  Future<List<Guest>> createGuestsBulk({
    required String weddingPlanId,
    required List<({String name, String? phone})> people,
    String? groupId,
  }) async {
    final normalizedGroupId = groupId?.trim();
    List<Map<String, dynamic>> payloads(
      List<({String name, String? phone})> chunk,
    ) => [
      for (final person in chunk)
        {
          'name': person.name.trim(),
          'side': 'OTHER',
          'status': 'INVITED',
          'seatsCount': 1,
          if (normalizedGroupId != null && normalizedGroupId.isNotEmpty)
            'groupId': normalizedGroupId,
          'phone': ?_normalizeOptionalPhone(person.phone),
        },
    ];
    final created = <Guest>[];
    if (_isLocalGuestPlanId(weddingPlanId)) {
      for (final payload in payloads(people)) {
        created.add(
          await _createLocalGuest(
            weddingPlanId: weddingPlanId,
            payload: payload,
          ),
        );
      }
      return created;
    }
    for (var start = 0; start < people.length; start += 200) {
      final end = start + 200 > people.length ? people.length : start + 200;
      final json = await _apiClient.postJson(
        '/api/v1/wedding-plans/$weddingPlanId/guests/bulk',
        {'items': payloads(people.sublist(start, end))},
      );
      for (final item in json['created'] as List? ?? const []) {
        final guestJson = Map<String, dynamic>.from(item as Map);
        await _offline?.database.saveCachedItem(
          table: OfflineTables.cachedGuests,
          json: guestJson,
        );
        created.add(Guest.fromJson(guestJson));
      }
    }
    return created;
  }

  Future<Guest> updateGuest({
    required String id,
    String? name,
    String? phone,
    String? groupId,
    String? side,
    String? status,
    String? attendanceStatus,
    int? seatsCount,
    int? companionsCount,
    String? notes,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) {
      payload['name'] = name.trim();
    }
    if (phone != null) {
      payload['phone'] = _normalizeOptionalPhone(phone);
    }
    if (groupId != null) {
      payload['groupId'] = groupId.trim().isEmpty ? null : groupId.trim();
    }
    if (side != null) {
      payload['side'] = side;
    }
    if (status != null) {
      payload['status'] = status;
    }
    if (attendanceStatus != null) {
      payload['attendanceStatus'] = attendanceStatus;
    }
    if (seatsCount != null) {
      payload['seatsCount'] = seatsCount;
    }
    if (companionsCount != null) {
      payload['companionsCount'] = companionsCount;
    }
    if (notes != null) {
      payload['notes'] = notes.trim();
    }
    if (id.startsWith('local-guest-')) {
      return _updateLocalGuest(id: id, payload: payload);
    }
    final json = await _apiClient.patchJson('/api/v1/guests/$id', payload);
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: json,
    );
    return Guest.fromJson(json);
  }

  Future<void> deleteGuest(String id) async {
    if (id.startsWith('local-guest-')) {
      await _deleteLocalGuest(id);
      return;
    }
    await _apiClient.deleteJson('/api/v1/guests/$id');
    await _offline?.database.discardLocalEntity(
      table: OfflineTables.cachedGuests,
      entityType: 'guest',
      entityId: id,
    );
  }

  /// A new personal RSVP link for the guest and the WhatsApp text that
  /// carries it (V1 checklist 4.7). The previous link stops working.
  Future<GuestInvitationLink> createInvitationLink(String guestId) async {
    final json = await _apiClient.postJson(
      '/api/v1/guests/$guestId/invitation-link',
      const {},
    );
    return GuestInvitationLink(
      url: json['url']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }

  String? _normalizeOptionalPhone(String? phone) {
    try {
      return PhoneNumberUtils.normalizeOptional(phone);
    } on FormatException {
      throw const ApiException('أدخل رقم جوال صحيح.');
    }
  }

  Future<List<Guest>> _cachedGuests(String weddingPlanId) async {
    final cached = await _offline?.database.readCachedList(
      table: OfflineTables.cachedGuests,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return (cached ?? const <Map<String, dynamic>>[])
        .map(Guest.fromJson)
        .toList();
  }

  Future<Guest> _createLocalGuest({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localJson = {
      'id': nextLocalId('local-guest'),
      'weddingPlanId': weddingPlanId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Guest.fromJson(localJson);
  }

  Future<Guest> _updateLocalGuest({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedGuests,
      id: id,
    );
    final now = DateTime.now();
    final localJson = {
      ...?cached,
      ...payload,
      'id': id,
      'weddingPlanId': cached?['weddingPlanId'] ?? 'local-guest-plan',
      'createdAt': cached?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Guest.fromJson(localJson);
  }

  Future<void> _deleteLocalGuest(String id) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedGuests,
      id: id,
    );
    if (cached == null) return;
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: cached,
      dirty: true,
      deletedLocally: true,
    );
    await _offline?.refreshStatus();
  }

  bool _isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }
}
