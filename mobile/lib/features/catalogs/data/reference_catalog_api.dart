import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/reference_catalog.dart';

const _catalogVersionMetaKey = 'aarast.catalog.bootstrap.version.v1';
const _catalogPayloadMetaKey = 'aarast.catalog.bootstrap.payload.v1';

/// The reference catalog (money items, provider kinds), versioned.
///
/// D85: the last complete payload is the phone's copy; an unchanged
/// version keeps it, and a server out of reach serves it.
class ReferenceCatalogApi {
  ReferenceCatalogApi(ApiClient apiClient, this._offline)
    : _writes = OfflineWrites(apiClient, _offline);

  final OfflineSyncService _offline;
  final OfflineWrites _writes;

  Future<ReferenceCatalogBootstrap?> load() async {
    final cached = await _readCached();
    final knownVersion = await _offline.database.getMeta(
      _catalogVersionMetaKey,
    );
    final versionQuery = knownVersion == null || knownVersion.trim().isEmpty
        ? ''
        : '?version=${Uri.encodeQueryComponent(knownVersion)}';
    try {
      // The version query makes this read its own: the copy is kept only
      // when the server says the catalog changed.
      final response = await _writes.serverOnly(
        reason: 'الكتالوج يتحدّث من الخادم.',
        method: 'GET',
        path: '/api/v1/catalogs/bootstrap$versionQuery',
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
      if (cached != null && CachePolicy.shouldUseCache(error)) return cached;
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
