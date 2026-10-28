import '../../../core/network/api_client.dart';
import '../models/rafd.dart';

/// D66: the rafd book (`/wedding-plans/:id/rafd`), the plan owner's only.
class RafdApi {
  const RafdApi(this._apiClient);

  final ApiClient _apiClient;

  String _base(String weddingPlanId) =>
      '/api/v1/wedding-plans/$weddingPlanId/rafd';

  Future<RafdBook> list(String weddingPlanId) async {
    return RafdBook.fromJson(await _apiClient.getJson(_base(weddingPlanId)));
  }

  /// Sends entries written on the phone; each is recorded once by its
  /// `clientId`, so a batch sent again after a lost answer doubles nothing.
  Future<void> sendBatch(String weddingPlanId, List<RafdEntry> entries) async {
    await _apiClient.postJson('${_base(weddingPlanId)}/batch', {
      'entries': [for (final entry in entries) entry.toOutboxJson()],
    });
  }

  /// e10: these were sent their thanks from the phone's WhatsApp.
  Future<void> markThanked(String weddingPlanId, List<String> entryIds) async {
    await _apiClient.postJson('${_base(weddingPlanId)}/thanks', {
      'entryIds': entryIds,
    });
  }

  Future<void> remove(String weddingPlanId, String entryId) async {
    await _apiClient.deleteJson('${_base(weddingPlanId)}/$entryId');
  }
}
