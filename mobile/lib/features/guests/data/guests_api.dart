import '../../../core/network/api_client.dart';
import '../models/guest.dart';

class GuestsApi {
  const GuestsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Guest>> getGuests(String weddingPlanId) async {
    final list = await _apiClient.getJsonList(
      '/wedding-plans/$weddingPlanId/guests',
    );
    return list
        .whereType<Map>()
        .map((item) => Guest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Guest> createGuest({
    required String weddingPlanId,
    required String name,
    String? phone,
    required String side,
    required String status,
    required int seatsCount,
    String? notes,
  }) async {
    final json = await _apiClient
        .postJson('/wedding-plans/$weddingPlanId/guests', {
          'name': name.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          'side': side,
          'status': status,
          'seatsCount': seatsCount,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        });
    return Guest.fromJson(json);
  }

  Future<Guest> updateGuest({
    required String id,
    String? name,
    String? phone,
    String? side,
    String? status,
    int? seatsCount,
    String? notes,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) {
      payload['name'] = name.trim();
    }
    if (phone != null) {
      payload['phone'] = phone.trim();
    }
    if (side != null) {
      payload['side'] = side;
    }
    if (status != null) {
      payload['status'] = status;
    }
    if (seatsCount != null) {
      payload['seatsCount'] = seatsCount;
    }
    if (notes != null) {
      payload['notes'] = notes.trim();
    }
    final json = await _apiClient.patchJson('/guests/$id', payload);
    return Guest.fromJson(json);
  }

  Future<void> deleteGuest(String id) async {
    await _apiClient.deleteJson('/guests/$id');
  }
}
