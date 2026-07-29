import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/yemen_administrative_area.dart';

class YemenAdministrativeApi {
  const YemenAdministrativeApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<YemenGovernorate>> getGovernorates() async {
    try {
      final items = await _getList('/api/v1/governorates');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedGovernorates,
        items: items,
      );
      return items.map(YemenGovernorate.fromJson).toList(growable: false);
    } on Object catch (error) {
      final cached = await _cachedList(
        error,
        table: OfflineTables.cachedGovernorates,
      );
      if (cached != null) {
        return cached.map(YemenGovernorate.fromJson).toList(growable: false);
      }
      rethrow;
    }
  }

  Future<List<YemenDistrict>> getDistricts(String governorateId) async {
    try {
      final items = await _getList(
        '/api/v1/governorates/$governorateId/districts',
      );
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedDistricts,
        items: items,
        parentColumn: 'governorateId',
        parentId: governorateId,
      );
      return items.map(YemenDistrict.fromJson).toList(growable: false);
    } on Object catch (error) {
      final cached = await _cachedList(
        error,
        table: OfflineTables.cachedDistricts,
        parentColumn: 'governorateId',
        parentId: governorateId,
      );
      if (cached != null) {
        return cached.map(YemenDistrict.fromJson).toList(growable: false);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await _apiClient.getJsonList(path);
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>?> _cachedList(
    Object error, {
    required String table,
    String? parentColumn,
    String? parentId,
  }) async {
    final offline = _offline;
    if (!CachePolicy.shouldUseCache(error) || offline == null) return null;
    await offline.noteNetworkFailure((error as ApiException).message);
    final cached = await offline.database.readCachedList(
      table: table,
      parentColumn: parentColumn,
      parentId: parentId,
    );
    return cached.isEmpty ? null : cached;
  }
}
