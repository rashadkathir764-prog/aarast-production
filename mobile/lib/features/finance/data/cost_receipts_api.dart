import '../../../core/network/api_client.dart';
import '../models/cost_receipt.dart';

/// Receipt photos kept with a cost (V1 checklist 4.4). Online only, outside
/// the offline money ledger: each photo is private and opened through a
/// short-lived signed URL, so there is nothing to queue or replay.
class CostReceiptsApi {
  const CostReceiptsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CostReceipt>> list(String costId) async {
    final json = await _apiClient.getJsonList('/api/v1/costs/$costId/receipts');
    return json
        .whereType<Map>()
        .map((item) => CostReceipt.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<CostReceipt> add(String costId, {required String attachmentRef}) async {
    final json = await _apiClient.postJson('/api/v1/costs/$costId/receipts', {
      'attachmentRef': attachmentRef,
    });
    return CostReceipt.fromJson(json);
  }

  Future<void> delete(String costId, String receiptId) async {
    await _apiClient.deleteJson('/api/v1/costs/$costId/receipts/$receiptId');
  }
}
