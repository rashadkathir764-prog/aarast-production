import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/models/notification_offline_release_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationOfflineReleaseReadiness', () {
    test('defaults to push disabled without requesting permission', () {
      const readiness = NotificationOfflineReleaseReadiness.empty();

      expect(
        readiness.state,
        NotificationOfflineReleaseReadinessState.pushDisabled,
      );
      expect(readiness.pushNotificationsEnabled, isFalse);
      expect(readiness.shouldRequestNotificationPermission, isFalse);
      expect(readiness.notificationCount, isNull);
      expect(readiness.unreadCount, isNull);
    });

    test(
      'keeps in-app notification counts source-backed while push is disabled',
      () {
        final readiness = NotificationOfflineReleaseReadiness.fromSources(
          notifications: [
            _notification(read: false),
            _notification(read: true),
          ],
          unreadCount: 1,
        );

        expect(
          readiness.state,
          NotificationOfflineReleaseReadinessState.pushDisabled,
        );
        expect(readiness.notificationCount, 2);
        expect(readiness.unreadCount, 1);
        expect(readiness.shouldRequestNotificationPermission, isFalse);
      },
    );

    test('blocks accidental notification permission requests', () {
      const readiness = NotificationOfflineReleaseReadiness(
        notificationPermissionRequested: true,
      );

      expect(
        readiness.state,
        NotificationOfflineReleaseReadinessState.permissionRequestBlocked,
      );
      expect(readiness.shouldRequestNotificationPermission, isFalse);
    });

    test('represents pending offline sync before release readiness', () {
      final readiness = NotificationOfflineReleaseReadiness.fromSources(
        syncStatus: SyncStatusSnapshot(
          state: SyncState.hasPendingChanges,
          pendingCount: 3,
        ),
      );

      expect(
        readiness.state,
        NotificationOfflineReleaseReadinessState.offlinePendingSync,
      );
      expect(readiness.pendingSyncCount, 3);
    });

    test('can become ready only when push flag is explicitly enabled', () {
      final readiness = NotificationOfflineReleaseReadiness.fromSources(
        featureFlags: _pushNotificationsEnabled,
        syncStatus: SyncStatusSnapshot(
          state: SyncState.synced,
          pendingCount: 0,
        ),
      );

      expect(readiness.state, NotificationOfflineReleaseReadinessState.ready);
      expect(readiness.pushNotificationsEnabled, isTrue);
      expect(readiness.shouldRequestNotificationPermission, isFalse);
    });
  });
}

const _pushNotificationsEnabled = AppFeatureFlags(
  enableGuestFirstOnboarding: false,
  enableOfflineSync: true,
  enablePushNotifications: true,
);

AarastNotification _notification({required bool read}) {
  return AarastNotification(
    id: read ? 'read' : 'unread',
    userId: 'user-1',
    type: 'TASK',
    title: 'تنبيه',
    body: 'نص التنبيه',
    readAt: read ? DateTime(2026, 1, 2) : null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}
