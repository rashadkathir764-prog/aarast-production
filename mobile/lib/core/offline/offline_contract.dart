import 'dart:convert';
import 'dart:math';

import '../network/api_client.dart';
import 'cache_policy.dart';
import 'offline_sync_service.dart';

/// D85: the one contract every feature's data layer follows.
///
/// Reads: the server's answer is kept on the phone, and when the server is
/// out of reach the phone's copy is served; only a phone with no copy at
/// all reports the failure. Writes to the plan's own data are kept on the
/// phone first and sent when the server answers (the sync queue, C58).
/// What needs the other side right now ([OfflineWrites.serverOnly]) says
/// so with the measured cause instead of failing silently.
///
/// Feature data files call these instead of the API client directly; the
/// contract test keeps raw calls from growing back.
class OfflineReads {
  const OfflineReads(this._api, this._offline);

  final ApiClient _api;
  final OfflineSyncService? _offline;

  /// D87: how many times a phone's copy stood in for the server's answer
  /// since the app started. A screen that asked the server and saw this
  /// count rise meanwhile is showing an old copy, and says so; nothing
  /// else can tell a served copy from a fresh answer.
  static int copiesServed = 0;

  /// Called by every path that serves the phone's copy instead of the
  /// server's answer, inside this contract and in the data files that keep
  /// a queue of their own.
  static void noteCopyServed() => copiesServed++;

  /// A list the server returns as a JSON array (or under [itemsKey] in an
  /// object), kept in [table], scoped by [parentColumn]/[parentId].
  Future<List<Map<String, dynamic>>> list(
    String path, {
    required String table,
    String? parentColumn,
    String? parentId,
    String? itemsKey,
  }) async {
    try {
      final Object? raw = itemsKey == null
          ? await _api.getJsonList(path)
          : (await _api.getJson(path))[itemsKey];
      final items = _maps(raw);
      await _offline?.database.replaceCachedList(
        table: table,
        items: items,
        parentColumn: parentColumn,
        parentId: parentId,
      );
      return items;
    } on Object catch (error) {
      if (!await _servesCache(error)) rethrow;
      final cached = await cachedList(
        table,
        parentColumn: parentColumn,
        parentId: parentId,
      );
      // No copy on the phone: the failure is reported, never an empty list.
      if (cached.isEmpty) rethrow;
      noteCopyServed();
      return cached;
    }
  }

  /// One object kept in [table] under its own `id`.
  Future<Map<String, dynamic>> item(
    String path, {
    required String table,
    required String id,
  }) async {
    try {
      final json = await _api.getJson(path);
      await _offline?.database.saveCachedItem(table: table, json: json);
      return json;
    } on Object catch (error) {
      if (!await _servesCache(error)) rethrow;
      final cached = await cachedItem(table, id);
      if (cached == null) rethrow;
      noteCopyServed();
      return cached;
    }
  }

  /// One JSON object kept whole under [metaKey] (a screen's own payload
  /// that no table models).
  Future<Map<String, dynamic>> blob(
    String path, {
    required String metaKey,
  }) async {
    try {
      final json = await _api.getJson(path);
      await _offline?.database.setMeta(metaKey, jsonEncode(json));
      return json;
    } on Object catch (error) {
      if (!await _servesCache(error)) rethrow;
      final cached = await cachedBlob(metaKey);
      if (cached == null) rethrow;
      noteCopyServed();
      return cached;
    }
  }

  /// A JSON array kept whole under [metaKey]. With [wrapScalars] a list of
  /// plain values (days, ids) is kept as `{'value': …}` rows.
  Future<List<Map<String, dynamic>>> blobList(
    String path, {
    required String metaKey,
    String? itemsKey,
    bool wrapScalars = false,
  }) async {
    try {
      final Object? raw = itemsKey == null
          ? await _api.getJsonList(path)
          : (await _api.getJson(path))[itemsKey];
      final items = wrapScalars && raw is List
          ? [
              for (final value in raw) <String, dynamic>{'value': value},
            ]
          : _maps(raw);
      await _offline?.database.setMeta(metaKey, jsonEncode(items));
      return items;
    } on Object catch (error) {
      if (!await _servesCache(error)) rethrow;
      final cached = await cachedBlobList(metaKey);
      if (cached == null) rethrow;
      noteCopyServed();
      return cached;
    }
  }

  // --- the phone's copy alone, for screens that show it before asking ---

  Future<List<Map<String, dynamic>>> cachedList(
    String table, {
    String? parentColumn,
    String? parentId,
  }) async {
    final rows = await _offline?.database.readCachedList(
      table: table,
      parentColumn: parentColumn,
      parentId: parentId,
    );
    return rows ?? const [];
  }

  Future<Map<String, dynamic>?> cachedItem(String table, String id) =>
      _offline?.database.readCachedItem(table: table, id: id) ??
      Future.value(null);

  Future<Map<String, dynamic>?> cachedBlob(String metaKey) async {
    final raw = await _offline?.database.getMeta(metaKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      await _offline?.database.deleteMeta(metaKey);
      return null;
    }
  }

  /// Rewrites the phone's copy of a blob (a row kept on the phone joins the
  /// list the screens read).
  Future<void> putBlob(String metaKey, Map<String, dynamic> json) async {
    await _offline?.database.setMeta(metaKey, jsonEncode(json));
  }

  /// Rewrites one row of the phone's copy (dirty: it waits for its queued
  /// create to carry it).
  Future<void> putRow(String table, Map<String, dynamic> json) async {
    await _offline?.database.saveCachedItem(
      table: table,
      json: json,
      dirty: true,
    );
  }

  Future<List<Map<String, dynamic>>?> cachedBlobList(String metaKey) async {
    final raw = await _offline?.database.getMeta(metaKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? _maps(decoded) : null;
    } on FormatException {
      await _offline?.database.deleteMeta(metaKey);
      return null;
    }
  }

  /// A transport failure with a sync service to tell: the phone's copy is
  /// served and the failure is measured (D84), never swallowed.
  Future<bool> _servesCache(Object error) async {
    final offline = _offline;
    if (offline == null || !CachePolicy.shouldUseCache(error)) return false;
    await offline.noteNetworkFailure((error as ApiException).message);
    return true;
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// The create a queued row would be sent as, when it is edited before the
/// server named it: the same endpoint, the merged payload.
class PendingCreate {
  const PendingCreate({required this.endpoint, required this.payload});

  final String endpoint;
  final Map<String, dynamic> payload;
}

class OfflineWrites {
  const OfflineWrites(this._api, this._offline);

  final ApiClient _api;
  final OfflineSyncService? _offline;

  static final _random = Random();

  /// An id for a row made on the phone before the server named it.
  static String localId(String entity) =>
      'queued-$entity-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}';

  static bool isLocalId(String id) => id.startsWith('queued-');

  /// The plan's own data: sent now when the server answers; otherwise kept
  /// on the phone as [localJson] (dirty) and queued for the first answer.
  /// Returns the server's row, or [localJson] while it waits.
  Future<Map<String, dynamic>> queued({
    required String entityType,
    required String operation,
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> localJson,
    String? table,
    String? metaKey,
    String? planId,
    String? localEntityId,
    bool replacePendingForEntity = false,
    PendingCreate? pendingCreate,
  }) async {
    assert(table != null || metaKey != null, 'a table or a meta key');
    final database = _offline?.database;
    final id = localJson['id']?.toString() ?? '';
    // A row the server has not named yet only changes on the phone while
    // its create was never sent: the create carries the latest shape, and
    // deleting the row drops it. Once the create was sent the server may
    // have the row (its answer lost, or still on the wire), so the change
    // goes after the create as its own (RA-MO-30): never a second create
    // under a new request id, never a dropped create left on the server.
    if (database != null && id.isNotEmpty && isLocalId(id)) {
      if (operation == 'delete') {
        if (await database.discardUnsentLocalEntity(
          table: table ?? '',
          entityType: entityType,
          entityId: id,
        )) {
          await _offline?.refreshStatus();
          return localJson;
        }
      } else if (operation != 'create') {
        final create = pendingCreate;
        if (create == null) {
          throw StateError(
            '$entityType $operation on a queued row needs pendingCreate',
          );
        }
        if (await database.rewriteUnsentSyncItem(
          entityType: entityType,
          operation: 'create',
          localEntityId: id,
          planId: planId,
          endpoint: create.endpoint,
          payload: create.payload,
        )) {
          if (table != null) {
            await database.saveCachedItem(
              table: table,
              json: localJson,
              dirty: true,
            );
          } else if (metaKey != null) {
            await database.setMeta(metaKey, jsonEncode(localJson));
          }
          await _offline?.refreshStatus();
          return localJson;
        }
      }
      if (operation != 'create') {
        return _keepOnPhone(
          database: database,
          entityType: entityType,
          operation: operation,
          method: method,
          endpoint: endpoint,
          payload: payload,
          table: table,
          metaKey: metaKey,
          localJson: localJson,
          planId: planId,
          localEntityId: id,
          replacePendingForEntity: true,
        );
      }
    }
    try {
      final json = switch (method) {
        'POST' => await _api.postJson(endpoint, payload),
        'PATCH' => await _api.patchJson(endpoint, payload),
        'PUT' => await _api.putJson(endpoint, payload),
        'DELETE' => await _api.deleteJson(endpoint),
        _ => throw ArgumentError.value(method, 'method'),
      };
      final row = json.isEmpty ? localJson : json;
      if (operation == 'delete') {
        if (table != null) {
          await database?.discardLocalEntity(
            table: table,
            entityType: entityType,
            entityId: id,
          );
        } else if (metaKey != null) {
          await database?.deleteMeta(metaKey);
        }
      } else if (table != null) {
        await database?.saveCachedItem(table: table, json: row);
      } else if (metaKey != null) {
        await database?.setMeta(metaKey, jsonEncode(row));
      }
      return row;
    } on Object catch (error) {
      if (database == null || !CachePolicy.shouldQueueWrite(error)) rethrow;
      await _offline!.noteNetworkFailure((error as ApiException).message);
      return _keepOnPhone(
        database: database,
        entityType: entityType,
        operation: operation,
        method: method,
        endpoint: endpoint,
        payload: payload,
        table: table,
        metaKey: metaKey,
        localJson: localJson,
        planId: planId,
        localEntityId: localEntityId,
        replacePendingForEntity: replacePendingForEntity,
      );
    }
  }

  Future<Map<String, dynamic>> _keepOnPhone({
    required dynamic database,
    required String entityType,
    required String operation,
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String? table,
    required String? metaKey,
    required Map<String, dynamic> localJson,
    required String? planId,
    required String? localEntityId,
    required bool replacePendingForEntity,
  }) async {
    if (table != null) {
      await database.saveCachedItem(
        table: table,
        json: localJson,
        dirty: true,
        deletedLocally: operation == 'delete',
      );
    } else if (metaKey != null) {
      await database.setMeta(metaKey, jsonEncode(localJson));
    }
    // RA-MO-31: an edit replaces the waiting edit of the same row, so it
    // carries that edit's fields too (the newest value wins); a second,
    // partial edit (an answer) never drops the first one (a name). Under a
    // new request id: the waiting one may be on the server already.
    final sentPayload = method == 'PATCH' && replacePendingForEntity
        ? <String, dynamic>{
            for (final waiting in [
              ...await database.pendingSyncItems(),
              ...await database.blockedSyncItems(),
            ])
              if (waiting.entityType == entityType &&
                  waiting.operation == operation &&
                  waiting.localEntityId == localEntityId)
                ...waiting.payload,
            ...payload,
          }
        : payload;
    await database.enqueueSync(
      entityType: entityType,
      operation: operation,
      endpoint: endpoint,
      method: method,
      payload: sentPayload,
      planId: planId,
      localEntityId: localEntityId,
      replacePendingForEntity: replacePendingForEntity,
    );
    await _offline?.refreshStatus();
    return localJson;
  }

  /// Needs the other side now (a code, an invite, a message, a request to
  /// a provider): when the server is out of reach the failure names the
  /// measured cause and why it cannot wait on the phone.
  Future<Map<String, dynamic>> serverOnly({
    required String reason,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? clientRequestId,
  }) async {
    try {
      if (clientRequestId != null) {
        // G38: a resend of the same request is answered with the first
        // answer, never a second effect.
        return await _api.mutateJson(
          path,
          body ?? const {},
          method: method,
          clientRequestId: clientRequestId,
        );
      }
      return switch (method) {
        'GET' => await _api.getJson(path),
        'POST' => await _api.postJson(path, body ?? const {}),
        'PATCH' => await _api.patchJson(path, body ?? const {}),
        'PUT' => await _api.putJson(path, body ?? const {}),
        'DELETE' => await _api.deleteJson(path),
        _ => throw ArgumentError.value(method, 'method'),
      };
    } on ApiException catch (error) {
      if (!error.isNetworkFailure) rethrow;
      await _offline?.noteNetworkFailure(error.message);
      throw ApiException(
        '${error.message} $reason',
        isNetworkFailure: true,
        transportCause: error.transportCause,
        statusCode: error.statusCode,
        serverCode: error.serverCode,
      );
    }
  }
}
