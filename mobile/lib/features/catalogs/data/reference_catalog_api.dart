import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/reference_catalog.dart';

const _catalogVersionMetaKey = 'aarast.catalog.bootstrap.version.v1';
const _catalogPayloadMetaKey = 'aarast.catalog.bootstrap.payload.v1';

class ReferenceCatalogApi {
  const ReferenceCatalogApi(this._apiClient, this._offline);

  final ApiClient _apiClient;
  final OfflineSyncService _offline;

  Future<ReferenceCatalogBootstrap?> load() async {
    final cached = await _readCached();
    final knownVersion = await _offline.database.getMeta(
      _catalogVersionMetaKey,
    );
    final versionQuery = knownVersion == null || knownVersion.trim().isEmpty
        ? ''
        : '?version=${Uri.encodeQueryComponent(knownVersion)}';
    try {
      final response = await _apiClient.getJson(
        '/api/v1/catalogs/bootstrap$versionQuery',
      );
      if (response['unchanged'] == true) return cached;
      final bootstrap = ReferenceCatalogBootstrap.fromJson(response);
      if (bootstrap.version.isEmpty) return cached;
      await _offline.database.setMeta(
        _catalogPayloadMetaKey,
        jsonEncode(response),
      );
      await _offline.database.setMeta(
        _catalogVersionMetaKey,
        bootstrap.version,
      );
      return bootstrap;
    } on Object catch (error) {
      if (cached != null && CachePolicy.shouldUseCache(error)) {
        if (error is ApiException) {
          await _offline.noteNetworkFailure(error.message);
        }
        return cached;
      }
      rethrow;
    }
  }

  Future<ReferenceCatalogBootstrap?> _readCached() async {
    final raw = await _offline.database.getMeta(_catalogPayloadMetaKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? ReferenceCatalogBootstrap.fromJson(
              Map<String, dynamic>.from(decoded),
            )
          : null;
    } on FormatException {
      await _offline.database.deleteMeta(_catalogPayloadMetaKey);
      await _offline.database.deleteMeta(_catalogVersionMetaKey);
      return null;
    }
  }
}
