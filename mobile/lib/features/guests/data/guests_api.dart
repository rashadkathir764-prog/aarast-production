import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/utils/text_limits.dart';
import '../models/guest.dart';

/// The plan's guests, groups and invitation card.
///
/// D85: every read keeps the server's answer on the phone and serves it
/// when the server is out of reach; every change to a guest, a group or
/// the card is kept on the phone first and sent when the server answers.
/// The invitation link is the server's (it issues it), so it says so.
/// A plan kept on the phone without an account (`local-guest-plan`) never
/// talks to the server at all.
class GuestsApi {
  GuestsApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _offline = offline,
      _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineSyncService? _offline;
  final OfflineReads _reads;
  final OfflineWrites _writes;

  static const _side = 'OTHER';

  Future<List<Guest>> getGuests(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return cachedGuests(weddingPlanId);
    }
    final items = await _reads.list(
      '/api/v1/wedding-plans/$weddingPlanId/guests',
      table: OfflineTables.cachedGuests,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return items.map(Guest.fromJson).toList();
  }

  /// The phone's copy alone (D85: shown before the server is asked).
  Future<List<Guest>> cachedGuests(String weddingPlanId) async {
    final rows = await _reads.cachedList(
      OfflineTables.cachedGuests,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return rows.map(Guest.fromJson).toList();
  }

  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return GuestSummary.fromGuests(
        weddingPlanId: weddingPlanId,
        guests: localGuests ?? await cachedGuests(weddingPlanId),
        groups: localGroups ?? const [],
      );
    }
    try {
      return GuestSummary.fromJson(
        await _reads.blob(
          '/api/v1/wedding-plans/$weddingPlanId/guests/summary',
          metaKey: 'guest-summary:$weddingPlanId',
        ),
      );
    } on Object catch (error) {
      // No summary kept yet: the phone counts its own copy.
      if (!CachePolicy.shouldUseCache(error)) rethrow;
      OfflineReads.noteCopyServed();
      return GuestSummary.fromGuests(
        weddingPlanId: weddingPlanId,
        guests: localGuests ?? await cachedGuests(weddingPlanId),
        groups: localGroups ?? await cachedGroups(weddingPlanId),
      );
    }
  }

  Future<List<GuestGroup>> getGroups(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) return const [];
    try {
      final items = await _reads.list(
        '/api/v1/wedding-plans/$weddingPlanId/guest-groups',
        table: OfflineTables.cachedGuestGroups,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(GuestGroup.fromJson).toList();
    } on Object catch (error) {
      // A plan may have no groups at all: an empty copy is still the copy.
      if (!CachePolicy.shouldUseCache(error)) rethrow;
      OfflineReads.noteCopyServed();
      return cachedGroups(weddingPlanId);
    }
  }

  Future<List<GuestGroup>> cachedGroups(String weddingPlanId) async {
    final rows = await _reads.cachedList(
      OfflineTables.cachedGuestGroups,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return rows.map(GuestGroup.fromJson).toList();
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
    List<String>? eventIds,
  }) async {
    final payload = _createPayload(
      name: name,
      phone: phone,
      groupId: groupId,
      side: side,
      status: status,
      attendanceStatus: attendanceStatus,
      seatsCount: seatsCount,
      companionsCount: companionsCount,
      notes: notes,
      eventIds: eventIds,
    );
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _createLocalGuest(weddingPlanId: weddingPlanId, payload: payload);
    }
    return _queuedCreate(weddingPlanId, payload);
  }

  /// e03 / w28: many guests in one go. Each is kept on the phone and sent
  /// on its own, so a list added without the server still lands whole.
  Future<List<Guest>> createGuestsBulk({
    required String weddingPlanId,
    required List<({String name, String? phone})> people,
    String? groupId,
  }) async {
    final normalizedGroupId = groupId?.trim();
    final created = <Guest>[];
    for (final person in people) {
      final payload = {
        'name': person.name.trim(),
        'side': _side,
        'status': 'INVITED',
        'seatsCount': 1,
        if (normalizedGroupId != null && normalizedGroupId.isNotEmpty)
          'groupId': normalizedGroupId,
        'phone': ?_normalizeOptionalPhone(person.phone),
      };
      created.add(
        _isLocalGuestPlanId(weddingPlanId)
            ? await _createLocalGuest(
                weddingPlanId: weddingPlanId,
                payload: payload,
              )
            : await _queuedCreate(weddingPlanId, payload),
      );
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
    List<String>? eventIds,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (phone != null) payload['phone'] = _normalizeOptionalPhone(phone);
    if (groupId != null) {
      payload['groupId'] = groupId.trim().isEmpty ? null : groupId.trim();
    }
    if (side != null) payload['side'] = side;
    if (status != null) payload['status'] = status;
    if (attendanceStatus != null) {
      payload['attendanceStatus'] = attendanceStatus;
    }
    if (seatsCount != null) payload['seatsCount'] = seatsCount;
    if (companionsCount != null) payload['companionsCount'] = companionsCount;
    if (notes != null) payload['notes'] = notes.trim();
    // D83: a list replaces the guest's events; null leaves them.
    if (eventIds != null) payload['eventIds'] = eventIds;
    if (id.startsWith('local-guest-')) {
      return _updateLocalGuest(id: id, payload: payload);
    }
    final cached =
        await _reads.cachedItem(OfflineTables.cachedGuests, id) ?? {'id': id};
    final localJson = {
      ...cached,
      ...payload,
      if (eventIds != null) 'events': _eventRows(eventIds),
      'id': id,
      'updatedAt': DateTime.now().toIso8601String(),
    }..remove('eventIds');
    final planId = cached['weddingPlanId']?.toString();
    final json = await _writes.queued(
      entityType: 'guest',
      operation: 'update',
      method: 'PATCH',
      endpoint: '/api/v1/guests/$id',
      payload: payload,
      table: OfflineTables.cachedGuests,
      localJson: localJson,
      planId: planId,
      localEntityId: id,
      replacePendingForEntity: true,
      pendingCreate: planId == null
          ? null
          : PendingCreate(
              endpoint: '/api/v1/wedding-plans/$planId/guests',
              payload: _createPayloadFromRow(localJson),
            ),
    );
    return Guest.fromJson(json);
  }

  Future<void> deleteGuest(String id) async {
    if (id.startsWith('local-guest-')) {
      await _deleteLocalGuest(id);
      return;
    }
    final cached =
        await _reads.cachedItem(OfflineTables.cachedGuests, id) ?? {'id': id};
    await _writes.queued(
      entityType: 'guest',
      operation: 'delete',
      method: 'DELETE',
      endpoint: '/api/v1/guests/$id',
      payload: const {},
      table: OfflineTables.cachedGuests,
      localJson: cached,
      planId: cached['weddingPlanId']?.toString(),
      localEntityId: id,
      replacePendingForEntity: true,
    );
  }

  /// A new personal RSVP link for the guest and the WhatsApp text that
  /// carries it (V1 checklist 4.7). The server issues both (D83), so it
  /// cannot wait on the phone.
  Future<GuestInvitationLink> createInvitationLink(
    String guestId, {
    bool reminder = false,
  }) async {
    final json = await _writes.serverOnly(
      reason: 'الرابط يصدره الخادم، فما ينفع بدونه.',
      method: 'POST',
      path: '/api/v1/guests/$guestId/invitation-link',
      body: {if (reminder) 'reminder': true},
    );
    return GuestInvitationLink(
      url: json['url']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }

  Future<GuestGroup> createGroup({
    required String weddingPlanId,
    required String name,
  }) async {
    final localId = OfflineWrites.localId('guest-group');
    final now = DateTime.now().toIso8601String();
    final json = await _writes.queued(
      entityType: 'guest_group',
      operation: 'create',
      method: 'POST',
      endpoint: '/api/v1/wedding-plans/$weddingPlanId/guest-groups',
      payload: {'name': name.trim()},
      table: OfflineTables.cachedGuestGroups,
      localJson: {
        'id': localId,
        'weddingPlanId': weddingPlanId,
        'name': name.trim(),
        'sortOrder': 0,
        'editable': true,
        'createdAt': now,
        'updatedAt': now,
      },
      planId: weddingPlanId,
      localEntityId: localId,
    );
    return GuestGroup.fromJson(json);
  }

  Future<GuestGroup> renameGroup(GuestGroup group, String name) async {
    final cached =
        await _reads.cachedItem(OfflineTables.cachedGuestGroups, group.id) ??
        {'id': group.id, 'weddingPlanId': group.weddingPlanId};
    final localJson = {
      ...cached,
      'name': name.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final json = await _writes.queued(
      entityType: 'guest_group',
      operation: 'update',
      method: 'PATCH',
      endpoint: '/api/v1/guest-groups/${group.id}',
      payload: {'name': name.trim()},
      table: OfflineTables.cachedGuestGroups,
      localJson: localJson,
      planId: group.weddingPlanId,
      localEntityId: group.id,
      replacePendingForEntity: true,
      pendingCreate: PendingCreate(
        endpoint: '/api/v1/wedding-plans/${group.weddingPlanId}/guest-groups',
        payload: {'name': name.trim()},
      ),
    );
    return GuestGroup.fromJson(json);
  }

  /// The server keeps the group's guests and only clears their group.
  Future<void> deleteGroup(GuestGroup group) async {
    await _writes.queued(
      entityType: 'guest_group',
      operation: 'delete',
      method: 'DELETE',
      endpoint: '/api/v1/guest-groups/${group.id}',
      payload: const {},
      table: OfflineTables.cachedGuestGroups,
      localJson: {'id': group.id, 'weddingPlanId': group.weddingPlanId},
      planId: group.weddingPlanId,
      localEntityId: group.id,
      replacePendingForEntity: true,
    );
  }

  /// D83: the plan's invitation card as the account keeps it.
  Future<InvitationCard> getInvitationCard(String weddingPlanId) async {
    return InvitationCard.fromJson(
      await _reads.blob(
        '/api/v1/wedding-plans/$weddingPlanId/guests/invitation-card',
        metaKey: _cardKey(weddingPlanId),
      ),
    );
  }

  /// D83: writes the card. Only the given keys change; an empty string
  /// clears that field. Kept on the phone and sent when the server answers.
  Future<InvitationCard> setInvitationCard(
    String weddingPlanId,
    Map<String, String?> changes,
  ) async {
    final payload = {
      for (final entry in changes.entries) entry.key: entry.value ?? '',
    };
    final cached = await _reads.cachedBlob(_cardKey(weddingPlanId)) ?? {};
    final localJson = {
      ...cached,
      for (final entry in changes.entries)
        entry.key: (entry.value ?? '').isEmpty ? null : entry.value,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final json = await _writes.queued(
      entityType: 'guest_invitation_card',
      operation: 'update',
      method: 'PUT',
      endpoint: '/api/v1/wedding-plans/$weddingPlanId/guests/invitation-card',
      payload: payload,
      metaKey: _cardKey(weddingPlanId),
      localJson: localJson,
      planId: weddingPlanId,
      localEntityId: 'card:$weddingPlanId',
      replacePendingForEntity: true,
    );
    return InvitationCard.fromJson(json);
  }

  // --- the phone's own rows ----------------------------------------------

  Future<Guest> _queuedCreate(
    String weddingPlanId,
    Map<String, dynamic> payload,
  ) async {
    final localId = OfflineWrites.localId('guest');
    final now = DateTime.now().toIso8601String();
    final eventIds = payload['eventIds'];
    final localJson = {
      'id': localId,
      'weddingPlanId': weddingPlanId,
      ...payload,
      'invitationStatus': 'NOT_SENT',
      'attendanceStatus': payload['attendanceStatus'] ?? 'PENDING',
      'companionsCount': payload['companionsCount'] ?? 0,
      'editable': true,
      'events': _eventRows(
        eventIds is List ? eventIds.cast<String>() : const [],
      ),
      'createdAt': now,
      'updatedAt': now,
    }..remove('eventIds');
    final json = await _writes.queued(
      entityType: 'guest',
      operation: 'create',
      method: 'POST',
      endpoint: '/api/v1/wedding-plans/$weddingPlanId/guests',
      payload: payload,
      table: OfflineTables.cachedGuests,
      localJson: localJson,
      planId: weddingPlanId,
      localEntityId: localId,
    );
    return Guest.fromJson(json);
  }

  Map<String, dynamic> _createPayload({
    required String name,
    String? phone,
    String? groupId,
    required String side,
    required String status,
    String? attendanceStatus,
    required int seatsCount,
    int? companionsCount,
    String? notes,
    List<String>? eventIds,
  }) {
    final normalizedPhone = _normalizeOptionalPhone(phone);
    final normalizedGroupId = groupId?.trim();
    final normalizedAttendanceStatus = attendanceStatus?.trim();
    final normalizedNotes = notes?.trim();
    return {
      // RA-BE-15: a name picked from the contacts is set from code and can
      // pass the field's limit; it is cut to the server's GUEST_NAME_MAX.
      'name': clipToCharacters(name.trim(), 120),
      'side': side,
      'status': status,
      'seatsCount': seatsCount,
      if (normalizedGroupId != null && normalizedGroupId.isNotEmpty)
        'groupId': normalizedGroupId,
      if (normalizedAttendanceStatus != null &&
          normalizedAttendanceStatus.isNotEmpty)
        'attendanceStatus': normalizedAttendanceStatus,
      'companionsCount': ?companionsCount,
      if (normalizedNotes != null && normalizedNotes.isNotEmpty)
        'notes': normalizedNotes,
      'phone': ?normalizedPhone,
      // D83: the plan's events beyond the wedding; absent means none.
      if (eventIds != null && eventIds.isNotEmpty) 'eventIds': eventIds,
    };
  }

  /// The create a queued guest is sent as after it was edited on the phone.
  static Map<String, dynamic> _createPayloadFromRow(Map<String, dynamic> row) {
    final events = row['events'];
    final eventIds = [
      if (events is List)
        for (final item in events)
          if (item is Map && item['planEventId'] != null)
            item['planEventId'].toString(),
    ];
    return {
      'name': row['name'],
      'side': row['side'] ?? _side,
      'status': row['status'] ?? 'INVITED',
      'seatsCount': row['seatsCount'] ?? 1,
      if (row['groupId'] != null) 'groupId': row['groupId'],
      if (row['attendanceStatus'] != null)
        'attendanceStatus': row['attendanceStatus'],
      if (row['companionsCount'] != null)
        'companionsCount': row['companionsCount'],
      if ((row['notes']?.toString() ?? '').isNotEmpty) 'notes': row['notes'],
      if (row['phone'] != null) 'phone': row['phone'],
      if (eventIds.isNotEmpty) 'eventIds': eventIds,
    };
  }

  static List<Map<String, dynamic>> _eventRows(List<String> eventIds) => [
    for (final id in eventIds)
      {'planEventId': id, 'attendanceStatus': 'PENDING', 'companionsCount': 0},
  ];

  String _cardKey(String weddingPlanId) => 'invitation-card:$weddingPlanId';

  String? _normalizeOptionalPhone(String? phone) {
    try {
      return PhoneNumberUtils.normalizeOptional(phone);
    } on FormatException {
      throw const ApiException('أدخل رقم جوال صحيح.');
    }
  }

  // --- a plan kept on the phone without an account ------------------------

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
