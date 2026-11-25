import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/local_plan_id.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/offline/sync_queue.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/utils/app_clock.dart';
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

  /// RA-MO-344: the guest's fields the server checks an edit against (the
  /// server's list in GuestsService.update).
  static const _checkableGuestFields = {
    'name',
    'phone',
    'groupId',
    'side',
    'status',
    'invitationStatus',
    'attendanceStatus',
    'seatsCount',
    'companionsCount',
    'notes',
  };

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
  ///
  /// A guest the server refuses (its number already on the list, the plan
  /// full) does not stop the others, nor make the ones already added look
  /// lost: the import said «ما قدرنا نضيف الضيوف» over guests it had added,
  /// and adding again added them twice. Each refused one is returned with the
  /// reason, so only those are tried again.
  Future<
    ({
      List<Guest> created,
      List<({String name, String? phone})> refused,
      String? reason,
    })
  >
  createGuestsBulk({
    required String weddingPlanId,
    required List<({String name, String? phone})> people,
    String? groupId,
  }) async {
    final normalizedGroupId = groupId?.trim();
    final created = <Guest>[];
    final refused = <({String name, String? phone})>[];
    String? reason;
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
      try {
        created.add(
          _isLocalGuestPlanId(weddingPlanId)
              ? await _createLocalGuest(
                  weddingPlanId: weddingPlanId,
                  payload: payload,
                )
              : await _queuedCreate(weddingPlanId, payload),
        );
      } on ApiException catch (error) {
        refused.add(person);
        reason ??= error.message;
      }
    }
    return (created: created, refused: refused, reason: reason);
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
    List<({String planEventId, String attendanceStatus, int companionsCount})>?
    eventReplies,
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
    // D116: the owner records the guest's answer to events beyond the
    // wedding, as the wedding's own is recorded with its status.
    final replies = [
      for (final reply in eventReplies ?? const [])
        {
          'planEventId': reply.planEventId,
          'attendanceStatus': reply.attendanceStatus,
          'companionsCount': reply.attendanceStatus == 'CONFIRMED'
              ? reply.companionsCount
              : 0,
        },
    ];
    if (replies.isNotEmpty) payload['eventReplies'] = replies;
    if (id.startsWith('local-guest-')) {
      return _updateLocalGuest(id: id, payload: payload);
    }
    final cached =
        await _reads.cachedItem(OfflineTables.cachedGuests, id) ?? {'id': id};
    final events = eventIds != null
        ? _eventRows(eventIds, cached['events'])
        : cached['events'];
    final localJson =
        {
            ...cached,
            ...payload,
            if (eventIds != null || replies.isNotEmpty)
              'events': replies.isEmpty
                  ? events
                  : _eventRowsWithReplies(events, replies),
            'id': id,
            'updatedAt': appNow().toIso8601String(),
          }
          ..remove('eventIds')
          ..remove('eventReplies');
    // RA-MO-344: what the edit was made from, for the fields it changes.
    final read = await _writes.lastRead(
      entityType: 'guest',
      table: OfflineTables.cachedGuests,
      id: id,
      fields: payload.keys.where(_checkableGuestFields.contains),
    );
    if (read != null) payload['expected'] = read;
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
    // RA-MO-344: what the delete was made from, as an edit's.
    final read = await _writes.lastRead(
      entityType: 'guest',
      table: OfflineTables.cachedGuests,
      id: id,
      fields: _checkableGuestFields,
    );
    await _writes.queued(
      entityType: 'guest',
      operation: 'delete',
      method: 'DELETE',
      endpoint: '/api/v1/guests/$id',
      payload: {'expected': ?read},
      table: OfflineTables.cachedGuests,
      localJson: cached,
      planId: cached['weddingPlanId']?.toString(),
      localEntityId: id,
      replacePendingForEntity: true,
    );
  }

  /// D116: prepares one send to one guest: the server's WhatsApp text and
  /// the guest's own link, which stays the same on every send. [kind] null:
  /// what the guest is due; [planEventId]: an invitation of its own for that
  /// occasion. Nothing counts as sent until [settleInvitationSend].
  Future<GuestInvitationLink> createInvitationLink(
    String guestId, {
    bool reminder = false,
    String? kind,
    String? planEventId,
    String? channel,
  }) async {
    final json = await _writes.serverOnly(
      reason: 'الدعوة تحتاج نت عشان تتجهّز.',
      method: 'POST',
      path: '/api/v1/guests/$guestId/invitation-link',
      body: {
        if (reminder) 'reminder': true,
        'kind': ?kind,
        'planEventId': ?planEventId,
        'channel': ?channel,
      },
    );
    return GuestInvitationLink.fromJson(json);
  }

  /// D116: what the person says happened to a prepared send. Only the
  /// person can say it was sent; opening WhatsApp is not sending.
  Future<void> settleInvitationSend(
    String sendId, {
    required bool sent,
    String? channel,
  }) async {
    await _writes.serverOnly(
      reason: 'تسجيل الإرسال يحتاج نت.',
      method: 'POST',
      path: '/api/v1/guests/invitation-sends/$sendId/settle',
      body: {'sent': sent, 'channel': ?channel},
      clientRequestId: 'settle-$sendId-$sent',
    );
  }

  /// D116: a new link for the guest (one sent to a wrong number); the old
  /// one stops opening.
  Future<String> replaceInvitationLink(String guestId) async {
    final json = await _writes.serverOnly(
      reason: 'الرابط الجديد يحتاج نت.',
      method: 'POST',
      path: '/api/v1/guests/$guestId/invitation-link/replace',
    );
    return json['url']?.toString() ?? '';
  }

  Future<GuestGroup> createGroup({
    required String weddingPlanId,
    required String name,
  }) async {
    final localId = OfflineWrites.localId('guest-group');
    final now = appNow().toIso8601String();
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
      'updatedAt': appNow().toIso8601String(),
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
    final localJson = localInvitationCard(cached, changes, appNow());
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
    final now = appNow().toIso8601String();
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

  /// The guest's event rows on the phone after [eventIds]: an event kept
  /// keeps its reply (it was reset to «ما رد» on every edit of the list until
  /// the server answered), a new one waits for its reply.
  static List<Map<String, dynamic>> _eventRows(
    List<String> eventIds, [
    Object? current,
  ]) {
    final kept = <String, Map<String, dynamic>>{
      if (current is List)
        for (final row in current)
          if (row is Map && row['planEventId'] != null)
            row['planEventId'].toString(): Map<String, dynamic>.from(row),
    };
    return [
      for (final id in eventIds)
        kept[id] ??
            {
              'planEventId': id,
              'attendanceStatus': 'PENDING',
              'companionsCount': 0,
            },
    ];
  }

  /// D116: the phone's copy of the guest's event rows after the owner
  /// recorded [replies] (the version answered is the event's, unknown here).
  static List<Map<String, dynamic>> _eventRowsWithReplies(
    Object? current,
    List<Map<String, dynamic>> replies,
  ) {
    final byEvent = {
      for (final reply in replies) reply['planEventId'].toString(): reply,
    };
    return [
      if (current is List)
        for (final row in current)
          if (row is Map)
            {
              ...Map<String, dynamic>.from(row),
              ...?byEvent[row['planEventId']?.toString()],
            },
    ];
  }

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
    final now = appNow();
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
    final now = appNow();
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

  // D25 of the closing round: the offline layer's one rule.
  bool _isLocalGuestPlanId(String? planId) => isLocalPlanId(planId);
}

/// The card as the phone keeps it while [changes] wait for the server. 6a:
/// the server's signed read belongs to the photo it was made for, so a
/// changed or cleared photo drops it; the new photo has none until the
/// server answers.
Map<String, dynamic> localInvitationCard(
  Map<String, dynamic> cached,
  Map<String, String?> changes,
  DateTime now,
) {
  return {
    ...cached,
    if (changes.containsKey('photoUrl')) 'photoReadUrl': null,
    for (final entry in changes.entries)
      entry.key: (entry.value ?? '').isEmpty ? null : entry.value,
    'updatedAt': now.toIso8601String(),
  };
}
