import 'dart:convert';

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
      localEntityId: row['localEntityId']?.toString(),
      createdAt: _dateOrNow(row['createdAt']),
      updatedAt: _dateOrNow(row['updatedAt']),
    );
  }

  static const queued = 'queued';
  static const failed = 'failed';
  static const synced = 'synced';

  final String id;
  final String entityType;
  final String operation;
  final String endpoint;
  final String method;
  final String payloadJson;
  final String status;
  final int retryCount;
  final String? lastError;
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
      'localEntityId': localEntityId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

int _intOrZero(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateOrNow(Object? value) {
  if (value == null) return DateTime.now();
  return DateTime.tryParse(value.toString()) ?? DateTime.now();
}
