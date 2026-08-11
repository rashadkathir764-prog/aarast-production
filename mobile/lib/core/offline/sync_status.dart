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
