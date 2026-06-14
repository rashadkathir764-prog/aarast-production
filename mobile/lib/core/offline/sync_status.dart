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
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncState state;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get hasPendingChanges => pendingCount > 0;
  bool get isOffline => state == SyncState.offline;
  bool get isSyncing => state == SyncState.syncing;
}
