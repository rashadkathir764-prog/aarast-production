import 'dart:async';

import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-359: a phone with no Google services (Huawei) took push as
// available on any Android and failed in silence: the failure was logged
// only, the «التنبيهات مقفلة» card never showed (the permission is granted),
// and «ذكّرني» never rang. The controller now knows push cannot work here.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(PushNotificationsController, _Gateway)> controller({
    bool noGoogleServices = false,
    bool registrationFails = false,
    _Registry? registry,
  }) async {
    registry ??= _Registry();
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final gateway = _Gateway()
      ..noGoogleServices = noGoogleServices
      ..registrationFails = registrationFails;
    final push = PushNotificationsController(
      preferences: preferences,
      gateway: gateway,
      registrationApi: registry,
    );
    addTearDown(push.dispose);
    return (push, gateway);
  }

  test('a phone without Google services is known to have no push', () async {
    final (push, _) = await controller(noGoogleServices: true);
    var told = 0;
    push.addListener(() => told++);
    expect(push.unavailableOnThisPhone, isFalse);

    await push.initialize();

    expect(push.unavailableOnThisPhone, isTrue);
    expect(push.isAvailable, isFalse);
    expect(told, greaterThan(0), reason: 'the home card is told');
  });

  // A registration with Google fails without a network on any phone
  // («SERVICE_NOT_AVAILABLE»): it used to be read as «no push on this
  // phone», and a phone with Google services was told so while offline.
  test('a registration that fails is «not linked yet», not «no push here», '
      'and a later success links it', () async {
    final (push, gateway) = await controller(registrationFails: true);
    await push.initialize();
    await push.bindAuthenticatedUser('user-1');
    expect(push.unavailableOnThisPhone, isFalse);
    expect(await push.phoneState(), PushPhoneState.notLinked);

    gateway.registrationFails = false;
    await push.refreshCurrentRegistration();
    expect(await push.phoneState(), PushPhoneState.on);
  });

  test(
    'a server that refuses the registration is not «no push here»',
    () async {
      final (push, _) = await controller(registry: _Registry()..refuses = true);
      await push.initialize();
      // The phone registered with Google; only the server said no.
      await push.bindAuthenticatedUser('user-1');
      expect(push.unavailableOnThisPhone, isFalse);
      // Allowed is not enough: the server does not know this phone.
      expect(await push.phoneState(), PushPhoneState.notLinked);
    },
  );

  test(
    'the Google services check asks the phone and takes its answer',
    () async {
      const channel = MethodChannel('aarast/push_support');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      for (final present in [true, false]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'googleServicesAvailable');
          return present;
        });
        expect(await PlayServicesCheck.available(), present);
      }
    },
  );
}

class _Gateway implements PushMessagingGateway {
  bool noGoogleServices = false;
  bool registrationFails = false;

  @override
  bool get isAvailable => true;

  @override
  Stream<void> get tokenChanges => const Stream<void>.empty();

  @override
  Stream<PushNotificationTap> get notificationTaps =>
      const Stream<PushNotificationTap>.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      const Stream<PushForegroundNotification>.empty();

  @override
  Future<void> initialize() async {
    if (noGoogleServices) throw const PushUnavailableOnThisPhone();
  }

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.authorized;

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.authorized;

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async {
    if (registrationFails) throw StateError('SERVICE_NOT_AVAILABLE');
    return 'fid-1';
  }

  @override
  Future<PushNotificationTap?> consumeInitialNotificationTap() async => null;

  @override
  Future<int?> androidSdkInt() async => 33;
}

class _Registry implements PushInstallationRegistry {
  bool refuses = false;

  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {
    if (refuses) throw StateError('server refused');
  }

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {}
}
