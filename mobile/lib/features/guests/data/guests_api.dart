import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../models/guest.dart';

class GuestsApi {
  const GuestsApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<Guest>> getGuests(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _cachedGuests(weddingPlanId);
    }
    final list = await _apiClient.getJsonList(
      '/api/v1/wedding-plans/$weddingPlanId/guests',
    );
    return list
        .whereType<Map>()
        .map((item) => Guest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
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
    final json = await _apiClient.getJson(
      '/api/v1/wedding-plans/$weddingPlanId/guests/summary',
    );
    return GuestSummary.fromJson(json);
  }

  Future<List<GuestGroup>> getGroups(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) return const [];
    final list = await _apiClient.getJsonList(
      '/api/v1/wedding-plans/$weddingPlanId/guest-groups',
    );
    return list
        .whereType<Map>()
        .map((item) => GuestGroup.fromJson(Map<String, dynamic>.from(item)))
        .toList();
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
    return Guest.fromJson(json);
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
    return Guest.fromJson(json);
  }

  Future<void> deleteGuest(String id) async {
    if (id.startsWith('local-guest-')) {
      await _deleteLocalGuest(id);
      return;
    }
    await _apiClient.deleteJson('/api/v1/guests/$id');
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
      'id': 'local-guest-${now.microsecondsSinceEpoch}',
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
