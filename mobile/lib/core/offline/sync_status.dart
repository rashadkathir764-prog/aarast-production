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
