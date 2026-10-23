import 'dart:convert';

import 'offline_tables.dart';

const unknownSyncQueuePlanOwnershipError = 'LOCAL_QUEUE_PLAN_OWNERSHIP_UNKNOWN';
const invalidSyncQueuePlanScopeError = 'LOCAL_QUEUE_PLAN_SCOPE_INVALID';

bool isSyncQueueOwnershipQuarantineError(Object? error) =>
    error == unknownSyncQueuePlanOwnershipError ||
    error == invalidSyncQueuePlanScopeError;

int _lastSyncQueueMicros = 0;

/// Returns a process-monotonic timestamp even on platforms whose wall-clock
/// resolution is coarser than a microsecond. Queue ids and ordering must never
/// collide when dependent offline writes are enqueued in the same clock tick.
DateTime nextSyncQueueTimestamp() {
  final now = DateTime.now();
  var micros = now.microsecondsSinceEpoch;
  if (micros <= _lastSyncQueueMicros) micros = _lastSyncQueueMicros + 1;
  _lastSyncQueueMicros = micros;
  return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: now.isUtc);
}

String syncQueueIdFor(DateTime timestamp) =>
    'sync-${timestamp.microsecondsSinceEpoch}';

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.endpoint,
    required this.method,
    required this.payloadJson,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.planId,
    this.localEntityId,
    this.lastError,
  });

  factory SyncQueueItem.fromRow(Map<String, Object?> row) {
    return SyncQueueItem(
      id: row['id'].toString(),
      entityType: row['entityType'].toString(),
      operation: row['operation'].toString(),
      endpoint: row['endpoint'].toString(),
      method: row['method'].toString(),
      payloadJson: row['payloadJson'].toString(),
      status: row['status']?.toString() ?? queued,
      retryCount: _intOrZero(row['retryCount']),
      lastError: row['lastError']?.toString(),
      planId: _nonEmptyString(row['planId']),
      localEntityId: row['localEntityId']?.toString(),
      createdAt: _dateOrNow(row['createdAt']),
      updatedAt: _dateOrNow(row['updatedAt']),
    );
  }

  static const queued = 'queued';
  static const failed = 'failed';
  static const synced = 'synced';

  /// Permanently rejected by the server (validation error) or exhausted its
  /// retry budget — excluded from automatic replay so the app never spins
  /// forever on an unfixable item. Manual retry can re-queue it.
  static const blocked = 'blocked';

  /// Transient failures are retried at most this many times automatically.
  static const maxAutoRetries = 5;

  final String id;
  final String entityType;
  final String operation;
  final String endpoint;
  final String method;
  final String payloadJson;
  final String status;
  final int retryCount;
  final String? lastError;
  final String? planId;
  final String? localEntityId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> get payload {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return const {};
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'entityType': entityType,
      'operation': operation,
      'endpoint': endpoint,
      'method': method,
      'payloadJson': payloadJson,
      'status': status,
      'retryCount': retryCount,
      'lastError': lastError,
      'planId': planId,
      'localEntityId': localEntityId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

String? normalizeSyncQueuePlanId({
  required String entityType,
  required String? planId,
}) {
  final normalized = _nonEmptyString(planId);
  final isPlanScoped = OfflineTables.planScopedQueueEntityTypes.contains(
    entityType,
  );
  if (isPlanScoped && normalized == null) {
    throw ArgumentError.value(
      planId,
      'planId',
      'is required for plan-scoped queue entity "$entityType"',
    );
  }
  if (!isPlanScoped && normalized != null) {
    throw ArgumentError.value(
      planId,
      'planId',
      'must be null for account-scoped queue entity "$entityType"',
    );
  }
  return normalized;
}

/// Reads ownership from legacy queue payloads without consulting endpoints,
/// cached rows, or local entity ids. A row is attributable only when a
/// top-level `planId` or `weddingPlanId` is a non-empty JSON string. If both
/// fields exist they must agree exactly; otherwise ownership is ambiguous and
/// the caller must quarantine the row.
String? trustedLegacyQueuePlanId(Object? payloadJson) {
  final decoded = _decodeQueuePayloadMap(payloadJson);
  if (decoded == null) return null;
  return _trustedTopLevelPlanId(decoded);
}

/// Final replay integrity check for schema-v7 rows.
///
/// The explicit queue [planId] remains authoritative. When the payload also
/// carries a top-level `planId` or `weddingPlanId`, it must be a valid string
/// and agree with that authority. Nested values and endpoints are deliberately
/// ignored and are never used to infer ownership.
bool hasInvalidRuntimeSyncQueuePlanOwnership({
  required String? planId,
  required Object? payloadJson,
}) {
  final decoded = _decodeQueuePayloadMap(payloadJson);
  if (decoded == null) return true;

  final hasPlanId = decoded.containsKey('planId');
  final hasWeddingPlanId = decoded.containsKey('weddingPlanId');
  if (!hasPlanId && !hasWeddingPlanId) return false;

  final payloadPlanId = _trustedTopLevelPlanId(decoded);
  if (payloadPlanId == null) return true;
  return payloadPlanId != _nonEmptyString(planId);
}

Map<Object?, Object?>? _decodeQueuePayloadMap(Object? payloadJson) {
  if (payloadJson is! String || payloadJson.trim().isEmpty) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(payloadJson);
  } on FormatException {
    return null;
  }
  return decoded is Map ? decoded : null;
}

String? _trustedTopLevelPlanId(Map<Object?, Object?> decoded) {
  final hasPlanId = decoded.containsKey('planId');
  final hasWeddingPlanId = decoded.containsKey('weddingPlanId');
  if (!hasPlanId && !hasWeddingPlanId) return null;

  final planId = hasPlanId ? _strictJsonId(decoded['planId']) : null;
  final weddingPlanId = hasWeddingPlanId
      ? _strictJsonId(decoded['weddingPlanId'])
      : null;
  if ((hasPlanId && planId == null) ||
      (hasWeddingPlanId && weddingPlanId == null)) {
    return null;
  }
  if (planId != null && weddingPlanId != null && planId != weddingPlanId) {
    return null;
  }
  return planId ?? weddingPlanId;
}

String? _strictJsonId(Object? value) {
  if (value is! String) return null;
  return _nonEmptyString(value);
}

String? _nonEmptyString(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateOrNow(Object? value) {
  if (value == null) return DateTime.now();
  return DateTime.tryParse(value.toString()) ?? DateTime.now();
}

/// A device-local id that never repeats in this process, even when several
/// records are made in the same clock tick (a contacts import, say).
String nextLocalId(String prefix) =>
    '$prefix-${nextSyncQueueTimestamp().microsecondsSinceEpoch}';
