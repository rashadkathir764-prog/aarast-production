import 'dart:async';

import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:dio/dio.dart';

/// The server's registration of the phone, recorded.
class RecordingPushRegistry implements PushInstallationRegistry {
  final List<String> registered = [];

  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {
    registered.add(fid);
  }

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {}
}

/// The push gateway as firebase_messaging behaves on a real phone, so tests
/// stop hiding what it does. On Android 13 (API 33) and later the plugin
/// knows only «granted» or «not granted» (`checkPermissions()` answers 0 or
/// 1, never «not determined»): before the app ever asked it reports
/// [PushAuthorizationStatus.denied]. Below 13 notifications are on until
/// the person turns them off.
class PluginLikePushGateway implements PushMessagingGateway {
  /// [granted]: the permission as it stands; by default what the phone
  /// starts with (on below 13, not granted from 13 on).
  PluginLikePushGateway({
    this.sdkInt = 33,
    this.grantsWhenAsked = true,
    bool? granted,
    this.noGoogleServices = false,
  }) : _granted = granted ?? (sdkInt ?? 0) < 33;

  /// The phone's Android version; null for one that cannot say.
  final int? sdkInt;

  /// What the person answers the phone's question.
  bool grantsWhenAsked;

  /// A Huawei phone: push cannot be set up.
  final bool noGoogleServices;

  bool _granted;
  int permissionRequests = 0;
  int registrations = 0;

  final foreground = StreamController<PushForegroundNotification>.broadcast();
  final taps = StreamController<PushNotificationTap>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Stream<void> get tokenChanges => const Stream<void>.empty();

  @override
  Stream<PushNotificationTap> get notificationTaps => taps.stream;

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      foreground.stream;

  @override
  Future<void> initialize() async {
    if (noGoogleServices) throw const PushUnavailableOnThisPhone();
  }

  /// Never «not determined», as the plugin on Android.
  @override
  Future<PushAuthorizationStatus> authorizationStatus() async => _granted
      ? PushAuthorizationStatus.authorized
      : PushAuthorizationStatus.denied;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    permissionRequests += 1;
    // Below 13 there is no question: the phone answers what is set.
    if ((sdkInt ?? 0) >= 33) _granted = grantsWhenAsked;
    return authorizationStatus();
  }

  @override
  Future<int?> androidSdkInt() async => sdkInt;

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async {
    registrations += 1;
    return 'fid-1';
  }

  @override
  Future<PushNotificationTap?> consumeInitialNotificationTap() async => null;

  Future<void> close() async {
    await foreground.close();
    await taps.close();
  }
}
