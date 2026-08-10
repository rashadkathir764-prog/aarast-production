import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_push_config.dart';

enum PushAuthorizationStatus { authorized, denied, notDetermined }

class PushForegroundNotification {
  const PushForegroundNotification({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

abstract interface class PushMessagingGateway {
  bool get isAvailable;

  Stream<void> get tokenChanges;

  Stream<void> get notificationTaps;

  Stream<PushForegroundNotification> get foregroundNotifications;

  Future<void> initialize();

  Future<PushAuthorizationStatus> authorizationStatus();

  Future<PushAuthorizationStatus> requestPermission();

  Future<String> ensureRegistrationAndGetInstallationId();

  Future<bool> consumeInitialNotificationTap();
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
  Stream<void> get notificationTaps => _initialized
      ? FirebaseMessaging.onMessageOpenedApp.map((_) {})
      : const Stream<void>.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications {
    if (!_initialized) return const Stream<PushForegroundNotification>.empty();
    return FirebaseMessaging.onMessage
        .map(_foregroundNotificationFromMessage)
        .where((notification) => notification != null)
        .map((notification) => notification!);
  }

  @override
  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;
    await Firebase.initializeApp();
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
  Future<bool> consumeInitialNotificationTap() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    return await messaging.getInitialMessage() != null;
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
    return PushForegroundNotification(
      title: title.isEmpty ? 'إشعار جديد' : title,
      message: body.isEmpty ? 'لديك تحديث جديد في أعرست.' : body,
    );
  }
}
