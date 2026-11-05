enum SyncState {
  online,
  offline,
  syncing,
  synced,
  hasPendingChanges,
  syncError,
}

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.state,
    required this.pendingCount,
    this.blockedCount = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncState state;
  final int pendingCount;
  final int blockedCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  int get unsyncedCount => pendingCount + blockedCount;
  bool get hasPendingChanges => unsyncedCount > 0;
  bool get isOffline => state == SyncState.offline;
  bool get isSyncing => state == SyncState.syncing;
}

/// One change kept on the phone (w41): what it is, when it was made, and
/// whether the server refused it.
class PendingChangeSummary {
  const PendingChangeSummary({
    required this.id,
    required this.entityType,
    required this.title,
    required this.createdAt,
    required this.blocked,
    this.reason,
  });

  /// The queue item, for discarding a refused change (D86).
  final String id;
  final String entityType;

  /// «مهمة: احجز القاعة», or the kind of change when it has no name.
  final String title;
  final DateTime createdAt;

  /// The server refused it; it waits for the person, not for the network.
  final bool blocked;
  final String? reason;
}

class SyncIssueSummary {
  const SyncIssueSummary({
    required this.entityLabel,
    required this.operationLabel,
    required this.message,
    required this.retryCount,
    required this.canRetry,
  });

  final String entityLabel;
  final String operationLabel;
  final String message;
  final int retryCount;
  final bool canRetry;
}
