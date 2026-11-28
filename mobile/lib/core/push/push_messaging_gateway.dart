import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'firebase_push_config.dart';

enum PushAuthorizationStatus { authorized, denied, notDetermined }

class PushForegroundNotification {
  const PushForegroundNotification({
    required this.title,
    required this.message,
    this.notificationId,
    this.type,
    this.androidChannelId,
    this.tag,
    this.conversationId,
  });

  final String title;
  final String message;

  /// The notice the push announces; a tap on the phone's notification
  /// opens it as a tap on a background push does.
  final String? notificationId;

  /// The notice's type (`CHAT_MESSAGE_RECEIVED`…), for its channel when the
  /// push named none.
  final String? type;

  /// The phone channel the server chose (`aarast_messages`…).
  final String? androidChannelId;

  /// The server's tag: the messages of one conversation share one, so a
  /// second one replaces the first instead of stacking.
  final String? tag;

  /// The conversation a chat message belongs to, read from its tag; the
  /// reader who has it open is not shown a notification for it.
  final String? conversationId;
}

/// The server's channel of a push type when the push names none, as
/// `push-notification.policy.ts` maps them; the messages' channel otherwise.
String pushAndroidChannelFor(String? type) {
  switch (type?.toUpperCase()) {
    case 'TASK_ASSIGNED' ||
        'TASK_DUE_SOON' ||
        'TASK_OVERDUE' ||
        'WEDDING_COUNTDOWN':
      return 'aarast_tasks';
    case 'PAYMENT_SCHEDULE_DUE_SOON' ||
        'PAYMENT_SCHEDULE_OVERDUE' ||
        'LOAN_REPAYMENT_DUE_SOON' ||
        'LOAN_REPAYMENT_OVERDUE' ||
        'BUDGET_CATEGORY_EXCEEDED' ||
        'FUNDING_EXPECTED':
      return 'aarast_money';
    default:
      return 'aarast_messages';
  }
}

const _chatTagPrefix = 'aarast_chat_';

/// The conversation of a chat push: the server's `conversationId` when it
/// sends one, else the id in the tag it gives one conversation's messages.
String? pushConversationId(Map<String, dynamic> data, String? tag) {
  final named = data['conversationId']?.toString().trim();
  if (named != null && named.isNotEmpty) return named;
  final key = tag?.trim();
  if (key == null || !key.startsWith(_chatTagPrefix)) return null;
  final id = key.substring(_chatTagPrefix.length);
  return id.isEmpty ? null : id;
}

/// A tap on a notification of the phone's tray. A push carries the id of
/// the notice it announces (never its words or its target), so the app opens
/// that notice through the inbox's own guards; [notificationId] is null when
/// the push named none.
class PushNotificationTap {
  const PushNotificationTap({this.notificationId});

  final String? notificationId;
}

/// RA-MO-359: this phone cannot receive push: it has no Google services (a
/// Huawei phone), so no registration can be made. The gateway's
/// [PushMessagingGateway.initialize] throws it; the controller keeps it as
/// «push does not work here» for the home's card.
class PushUnavailableOnThisPhone implements Exception {
  const PushUnavailableOnThisPhone();

  @override
  String toString() => 'PushUnavailableOnThisPhone';
}

/// Whether the phone has Google services, asked of the Android side
/// (`MainActivity.kt`): Firebase starts on any phone, but registering for
/// push needs them.
abstract final class PlayServicesCheck {
  static const _channel = MethodChannel('aarast/push_support');

  static Future<bool> available() async =>
      await _channel.invokeMethod<bool>('googleServicesAvailable') ?? false;

  /// The phone's Android version (`Build.VERSION.SDK_INT`), asked of the
  /// same channel.
  static Future<int?> sdkInt() => _channel.invokeMethod<int>('sdkInt');

  /// Opens this app's notification settings in the phone, where the person
  /// turns back on what they turned off; false when it would not open.
  static Future<bool> openNotificationSettings() async =>
      await _channel.invokeMethod<bool>('openNotificationSettings') ?? false;

  /// Opens one of the app's channels in the phone's settings.
  static Future<bool> openChannelSettings(String channelId) async =>
      await _channel.invokeMethod<bool>('openChannelSettings', {
        'channelId': channelId,
      }) ??
      false;
}

abstract interface class PushMessagingGateway {
  bool get isAvailable;

  Stream<void> get tokenChanges;

  Stream<PushNotificationTap> get notificationTaps;

  Stream<PushForegroundNotification> get foregroundNotifications;

  Future<void> initialize();

  /// What the push plugin reports. From Android 13 it reports «denied»
  /// before the app ever asked (it knows only granted or not); the
  /// controller tells the two apart with [androidSdkInt] and its own record
  /// of having asked.
  Future<PushAuthorizationStatus> authorizationStatus();

  Future<PushAuthorizationStatus> requestPermission();

  /// The phone's Android version; null when it is not Android or cannot
  /// be read.
  Future<int?> androidSdkInt();

  Future<String> ensureRegistrationAndGetInstallationId();

  Future<PushNotificationTap?> consumeInitialNotificationTap();
}

@pragma('vm:entry-point')
Future<void> aarastFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

class FirebasePushMessagingGateway implements PushMessagingGateway {
  FirebaseMessaging? _messaging;
  FirebaseInstallations? _installations;
  bool _initialized = false;

  @override
  bool get isAvailable =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      FirebasePushConfig.isConfigured;

  @override
  Stream<void> get tokenChanges {
    final messaging = _messaging;
    if (messaging == null) return const Stream<void>.empty();
    return messaging.onTokenRefresh.map((_) {});
  }

  @override
  Stream<PushNotificationTap> get notificationTaps => _initialized
      ? FirebaseMessaging.onMessageOpenedApp.map(_tapFromMessage)
      : const Stream<PushNotificationTap>.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications {
    if (!_initialized) return const Stream<PushForegroundNotification>.empty();
    return FirebaseMessaging.onMessage
        .map(_foregroundNotificationFromMessage)
        .where((notification) => notification != null)
        .map((notification) => notification!);
  }

  Future<FirebaseApp>? _firebase;

  /// Starts Firebase without waiting for it, so the app's start runs it
  /// beside the offline database's open; [initialize] waits for the same
  /// start. A failure is not lost: [initialize] meets it and the controller
  /// logs it.
  void prepare() {
    if (!isAvailable || _firebase != null) return;
    final firebase = Firebase.initializeApp();
    // Listened to here so a failure before [initialize] is not an uncaught
    // error of the start; [initialize] awaits the same future.
    firebase.ignore();
    _firebase = firebase;
  }

  @override
  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;
    if (!await PlayServicesCheck.available()) {
      throw const PushUnavailableOnThisPhone();
    }
    prepare();
    await _firebase;
    FirebaseMessaging.onBackgroundMessage(
      aarastFirebaseMessagingBackgroundHandler,
    );
    _messaging = FirebaseMessaging.instance;
    _installations = FirebaseInstallations.instance;
    _initialized = true;
  }

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async {
    final messaging = _messaging;
    if (messaging == null) return PushAuthorizationStatus.denied;
    return _mapAuthorization(
      (await messaging.getNotificationSettings()).authorizationStatus,
    );
  }

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return PushAuthorizationStatus.denied;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _mapAuthorization(settings.authorizationStatus);
  }

  @override
  Future<int?> androidSdkInt() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await PlayServicesCheck.sdkInt();
    } on Object {
      return null;
    }
  }

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async {
    final messaging = _messaging;
    final installations = _installations;
    if (messaging == null || installations == null) {
      throw StateError('Firebase push is not initialized');
    }
    await messaging.setAutoInitEnabled(true);
    // FCM registration associates the installation with Messaging. The token
    // itself is deliberately not persisted; the backend addresses the FID.
    await messaging.getToken();
    return installations.getId();
  }

  @override
  Future<PushNotificationTap?> consumeInitialNotificationTap() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    final message = await messaging.getInitialMessage();
    return message == null ? null : _tapFromMessage(message);
  }

  PushNotificationTap _tapFromMessage(RemoteMessage message) {
    final id = message.data['notificationId']?.toString().trim();
    return PushNotificationTap(
      notificationId: id == null || id.isEmpty ? null : id,
    );
  }

  PushAuthorizationStatus _mapAuthorization(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushAuthorizationStatus.authorized,
      AuthorizationStatus.notDetermined =>
        PushAuthorizationStatus.notDetermined,
      AuthorizationStatus.denied => PushAuthorizationStatus.denied,
    };
  }

  PushForegroundNotification? _foregroundNotificationFromMessage(
    RemoteMessage message,
  ) {
    final notification = message.notification;
    final rawTitle = notification?.title ?? message.data['title']?.toString();
    final rawMessage = notification?.body ?? message.data['body']?.toString();
    final title = rawTitle?.trim() ?? '';
    final body = rawMessage?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return null;
    final id = message.data['notificationId']?.toString().trim();
    final android = notification?.android;
    final tag = android?.tag?.trim().isNotEmpty == true
        ? android!.tag!.trim()
        : message.collapseKey?.trim();
    return PushForegroundNotification(
      title: title.isEmpty ? 'تنبيه جديد' : title,
      message: body.isEmpty ? 'لديك تحديث جديد في اعّرست.' : body,
      notificationId: id == null || id.isEmpty ? null : id,
      type: message.data['type']?.toString(),
      androidChannelId: android?.channelId,
      tag: tag == null || tag.isEmpty ? null : tag,
      conversationId: pushConversationId(message.data, tag),
    );
  }
}
