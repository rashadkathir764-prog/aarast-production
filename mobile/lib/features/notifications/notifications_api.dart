// Owner-controlled public API. Cross-feature consumers import this library.
export 'data/notifications_api.dart' show NotificationsApi;
export 'models/aarast_notification.dart' show AarastNotification;
export 'providers/notifications_provider.dart'
    show NoticeLookup, NoticeLookupOutcome, NotificationsProvider;
export 'screens/notifications_screen.dart' show NotificationsScreen;
export 'utils/notice_open_lines.dart'
    show noticeGoneLine, noticeUnreachableLine;
export 'utils/notification_line.dart' show notificationLine;
export 'utils/notification_route_policy.dart'
    show isSafeNotificationRouteTarget, resolveNotificationRouteTarget;
