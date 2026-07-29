import '../../../core/config/app_feature_flags.dart';
import '../../../core/offline/sync_status.dart';
import 'aarast_notification.dart';

enum NotificationOfflineReleaseReadinessState {
  pushDisabled,
  ready,
  offlinePendingSync,
  offline,
  syncError,
  loading,
  blockedByError,
}

class NotificationOfflineReleaseReadiness {
  const NotificationOfflineReleaseReadiness({
    this.pushNotificationsEnabled = false,
    this.offlineSyncEnabled = true,
    this.syncStatus,
    this.notificationCount,
    this.unreadCount,
    this.notificationPermissionRequested = false,
    this.isLoading = false,
    this.errorMessage,
  });

  factory NotificationOfflineReleaseReadiness.fromSources({
    AppFeatureFlags featureFlags = AppFeatureFlags.defaults,
    SyncStatusSnapshot? syncStatus,
    List<AarastNotification>? notifications,
    int? unreadCount,
    bool notificationPermissionRequested = false,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return NotificationOfflineReleaseReadiness(
      pushNotificationsEnabled: featureFlags.enablePushNotifications,
      offlineSyncEnabled: featureFlags.enableOfflineSync,
      syncStatus: syncStatus,
      notificationCount: notifications?.length,
      unreadCount: unreadCount,
      notificationPermissionRequested: notificationPermissionRequested,
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }

  const factory NotificationOfflineReleaseReadiness.empty() =
      NotificationOfflineReleaseReadiness;

  final bool pushNotificationsEnabled;
  final bool offlineSyncEnabled;
  final SyncStatusSnapshot? syncStatus;
  final int? notificationCount;
  final int? unreadCount;
  final bool notificationPermissionRequested;
  final bool isLoading;
  final String? errorMessage;

  int? get pendingSyncCount => syncStatus?.pendingCount;

  bool get hasPendingSync => (pendingSyncCount ?? 0) > 0;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get shouldRequestNotificationPermission =>
      pushNotificationsEnabled && !notificationPermissionRequested;

  NotificationOfflineReleaseReadinessState get state {
    if (isLoading) {
      return NotificationOfflineReleaseReadinessState.loading;
    }
    if (hasError) {
      return NotificationOfflineReleaseReadinessState.blockedByError;
    }
    if (syncStatus?.state == SyncState.syncError) {
      return NotificationOfflineReleaseReadinessState.syncError;
    }
    if (syncStatus?.isOffline == true) {
      return NotificationOfflineReleaseReadinessState.offline;
    }
    if (hasPendingSync) {
      return NotificationOfflineReleaseReadinessState.offlinePendingSync;
    }
    if (!pushNotificationsEnabled) {
      return NotificationOfflineReleaseReadinessState.pushDisabled;
    }
    return NotificationOfflineReleaseReadinessState.ready;
  }
}
