import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/yemen_administrative_area.dart';

/// Yemen's governorates, districts and localities.
///
/// D85: every list is the phone's copy when the server is out of reach.
class YemenAdministrativeApi {
  YemenAdministrativeApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline);

  final OfflineReads _reads;

  Future<List<YemenGovernorate>> getGovernorates() async {
    final items = await _reads.list(
      '/api/v1/governorates',
      table: OfflineTables.cachedGovernorates,
    );
    return items.map(YemenGovernorate.fromJson).toList(growable: false);
  }

  Future<List<YemenDistrict>> getDistricts(String governorateId) async {
    final items = await _reads.list(
      '/api/v1/governorates/$governorateId/districts',
      table: OfflineTables.cachedDistricts,
      parentColumn: 'governorateId',
      parentId: governorateId,
    );
    return items.map(YemenDistrict.fromJson).toList(growable: false);
  }

  Future<List<YemenLocality>> getLocalities(String districtId) async {
    final items = await _reads.blobList(
      '/api/v1/districts/$districtId/localities',
      metaKey: 'aarast.geo.localities.v1.$districtId',
    );
    return items.map(YemenLocality.fromJson).toList(growable: false);
  }
}
