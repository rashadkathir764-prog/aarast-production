import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_messaging_gateway.dart';

/// The phone's own notifications for a push that arrives while the app is
/// open. Firebase shows a push itself only while the app is away; in front
/// it hands the push to the app, which shows it here on the same channel
/// and under the same tag, so a later push of the same conversation
/// replaces it instead of stacking. A tap is a tap on any push: it opens
/// the notice it names.
abstract interface class PushSystemNotifications {
  /// Taps on the notifications shown here, while the app runs.
  Stream<PushNotificationTap> get taps;

  Future<void> initialize();

  /// The tap that opened the app from a notification shown here, once.
  Future<PushNotificationTap?> consumeLaunchTap();

  /// Shows [notification]; false when it could not be shown.
  Future<bool> show(PushForegroundNotification notification);

  /// Removes every notification of the app from the phone's tray (an
  /// account signing out takes its notices with it).
  Future<void> cancelAll();

  /// The app's channels the person turned off in the phone's settings
  /// (importance «none»), while the app's notifications as a whole stay on:
  /// a push on one of them never shows. Empty when none, or unknown.
  Future<Set<String>> blockedChannels();
}

/// The app's channels (`AarastNotificationChannels.kt`), as the settings
/// page names a turned-off one.
const pushChannelIds = ['aarast_messages', 'aarast_tasks', 'aarast_money'];

/// No phone notifications: a test, or a platform without them.
class NoPushSystemNotifications implements PushSystemNotifications {
  const NoPushSystemNotifications();

  @override
  Stream<PushNotificationTap> get taps =>
      const Stream<PushNotificationTap>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<PushNotificationTap?> consumeLaunchTap() async => null;

  @override
  Future<bool> show(PushForegroundNotification notification) async => false;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<Set<String>> blockedChannels() async => const {};
}

/// The names the channels were made with (`AarastNotificationChannels.kt`),
/// so a channel this plugin makes first reads the same in the settings.
const _channelNames = {
  'aarast_messages': 'رسائل',
  'aarast_tasks': 'مهام وتذكيرات',
  'aarast_money': 'المال',
};

/// flutter_local_notifications on Android.
class LocalPushSystemNotifications implements PushSystemNotifications {
  LocalPushSystemNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<PushNotificationTap>.broadcast();
  Future<bool>? _ready;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<PushNotificationTap> get taps => _taps.stream;

  @override
  Future<void> initialize() async {
    await _initialized();
  }

  Future<bool> _initialized() {
    if (!_supported) return Future.value(false);
    return _ready ??= () async {
      try {
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_aarast'),
          ),
          onDidReceiveNotificationResponse: (response) {
            if (!_taps.isClosed) _taps.add(_tapOf(response.payload));
          },
        );
        return true;
      } on Object {
        _ready = null;
        return false;
      }
    }();
  }

  @override
  Future<PushNotificationTap?> consumeLaunchTap() async {
    if (!await _initialized()) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return _tapOf(details.notificationResponse?.payload);
    } on Object {
      return null;
    }
  }

  @override
  Future<Set<String>> blockedChannels() async {
    if (!await _initialized()) return const {};
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final channels = await android?.getNotificationChannels() ?? const [];
      return {
        for (final channel in channels)
          if (_channelNames.containsKey(channel.id) &&
              channel.importance == Importance.none)
            channel.id,
      };
    } on Object {
      return const {};
    }
  }

  @override
  Future<bool> show(PushForegroundNotification notification) async {
    if (!await _initialized()) return false;
    final channelId = _channelNames.containsKey(notification.androidChannelId)
        ? notification.androidChannelId!
        : pushAndroidChannelFor(notification.type);
    // A channel the person turned off shows nothing, though the plugin
    // reports the notice shown: the in-app line says it instead.
    if ((await blockedChannels()).contains(channelId)) return false;
    final tag = notification.tag;
    try {
      await _plugin.show(
        // Firebase shows a push as (its tag, 0): the same pair replaces the
        // one it showed while the app was away.
        id: tag != null ? 0 : _idOf(notification.notificationId),
        title: notification.title,
        body: notification.message,
        payload: notification.notificationId,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelNames[channelId]!,
            icon: 'ic_stat_aarast',
            color: const Color(0xFF4C7180),
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
            tag: tag,
            category: channelId == 'aarast_messages'
                ? AndroidNotificationCategory.message
                : AndroidNotificationCategory.reminder,
          ),
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
    } on Object {
      // The tray is the phone's; nothing in the app waits on it.
    }
  }

  static PushNotificationTap _tapOf(String? payload) {
    final id = payload?.trim();
    return PushNotificationTap(
      notificationId: id == null || id.isEmpty ? null : id,
    );
  }

  /// A notice without a tag (none today) still gets its own place.
  static int _idOf(String? notificationId) =>
      (notificationId ?? '').hashCode & 0x7fffffff;
}
