import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/cost_receipt.dart';

/// Receipt photos kept with a cost (V1 checklist 4.4).
///
/// D85: the list is the phone's copy when the server is out of reach; the
/// photos themselves are private and opened through short-lived signed
/// links, so adding or removing one is the server's say and says so.
class CostReceiptsApi {
  CostReceiptsApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineReads _reads;
  final OfflineWrites _writes;

  Future<List<CostReceipt>> list(String costId) async {
    final json = await _reads.blobList(
      '/api/v1/costs/$costId/receipts',
      metaKey: 'cost-receipts:$costId',
    );
    return json.map(CostReceipt.fromJson).toList();
  }

  /// Keeps a receipt with the cost, or with one of its payments.
  Future<CostReceipt> add(
    String costId, {
    required String attachmentRef,
    String? costPaymentId,
  }) async {
    final json = await _writes.serverOnly(
      reason: 'الصورة تُحفظ عند الخادم.',
      method: 'POST',
      path: '/api/v1/costs/$costId/receipts',
      body: {
        'attachmentRef': attachmentRef,
        'costPaymentId': ?costPaymentId,
      },
    );
    return CostReceipt.fromJson(json);
  }

  Future<void> delete(String costId, String receiptId) async {
    await _writes.serverOnly(
      reason: 'الصورة عند الخادم.',
      method: 'DELETE',
      path: '/api/v1/costs/$costId/receipts/$receiptId',
    );
  }
}
