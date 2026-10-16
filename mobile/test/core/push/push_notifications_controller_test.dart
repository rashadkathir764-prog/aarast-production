import 'dart:async';

import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'requests notification permission once then registers signed-in user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final gateway = _FakePushGateway();
      final registry = _FakePushRegistry();
      final controller = PushNotificationsController(
        preferences: preferences,
        gateway: gateway,
        registrationApi: registry,
      );

      await controller.initialize();
      await controller.requestPermissionOnFirstOpen();
      await controller.requestPermissionOnFirstOpen();
      await controller.bindAuthenticatedUser('user-1');

      expect(gateway.permissionRequests, 1);
      expect(preferences.getBool(pushPermissionRequestedPreferenceKey), isTrue);
      expect(registry.registeredFids, ['fid-1']);
    },
  );

  test('notification taps only request opening the neutral inbox', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final gateway = _FakePushGateway();
    final controller = PushNotificationsController(
      preferences: preferences,
      gateway: gateway,
      registrationApi: _FakePushRegistry(),
    );

    await controller.initialize();
    gateway.taps.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(controller.hasPendingNotificationsOpen, isTrue);
    expect(controller.claimNotificationsOpen(), isTrue);
    expect(controller.claimNotificationsOpen(), isFalse);
  });

  test(
    'foreground push remains available to the app-wide top receipt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final gateway = _FakePushGateway();
      final controller = PushNotificationsController(
        preferences: preferences,
        gateway: gateway,
        registrationApi: _FakePushRegistry(),
      );

      await controller.initialize();
      final received = controller.foregroundNotifications.first;
      gateway.foreground.add(
        const PushForegroundNotification(
          title: 'اعّرست',
          message: 'لديك تحديث جديد.',
        ),
      );

      await expectLater(
        received,
        completion(
          isA<PushForegroundNotification>()
              .having((value) => value.title, 'title', 'اعّرست')
              .having((value) => value.message, 'message', 'لديك تحديث جديد.'),
        ),
      );
    },
  );

  test('lifecycle refresh revalidates the current device binding', () async {
    SharedPreferences.setMockInitialValues({
      pushPermissionRequestedPreferenceKey: true,
    });
    final preferences = await SharedPreferences.getInstance();
    final gateway = _FakePushGateway();
    final registry = _FakePushRegistry();
    final controller = PushNotificationsController(
      preferences: preferences,
      gateway: gateway,
      registrationApi: registry,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.bindAuthenticatedUser('user-1');
    await controller.refreshCurrentRegistration();

    expect(registry.registeredFids, ['fid-1', 'fid-1']);
  });

  test(
    'an old logout cannot delete a registration created for a new login',
    () async {
      SharedPreferences.setMockInitialValues({
        pushPermissionRequestedPreferenceKey: true,
      });
      final preferences = await SharedPreferences.getInstance();
      final gateway = _FakePushGateway();
      final registry = _FakePushRegistry();
      final controller = PushNotificationsController(
        preferences: preferences,
        gateway: gateway,
        registrationApi: registry,
      );

      await controller.initialize();
      await controller.bindAuthenticatedUser('user-a');
      final unregister = controller.unregisterAccount('user-a');
      await registry.unregisterStarted.future;
      final bindNewUser = controller.bindAuthenticatedUser('user-b');
      registry.finishUnregister.complete();
      await unregister;
      await bindNewUser;

      expect(registry.registeredFids, ['fid-1', 'fid-1']);
    },
  );

  test(
    'a stalled registration cannot starve logout or the next account',
    () async {
      SharedPreferences.setMockInitialValues({
        pushPermissionRequestedPreferenceKey: true,
      });
      final preferences = await SharedPreferences.getInstance();
      final gateway = _FakePushGateway(stallFirstRegistration: true);
      final registry = _FakePushRegistry();
      final controller = PushNotificationsController(
        preferences: preferences,
        gateway: gateway,
        registrationApi: registry,
      );
      addTearDown(() {
        gateway.releaseStalledRegistration();
        controller.dispose();
      });

      await controller.initialize();
      final oldBinding = controller.bindAuthenticatedUser('user-a');
      await gateway.registrationStarted.future;

      final lease = controller.beginAccountTeardown('user-a');
      expect(lease, isNotNull);
      await expectLater(
        controller
            .clearLocalRegistration(lease!)
            .timeout(const Duration(milliseconds: 50)),
        completes,
      );

      await expectLater(
        controller
            .bindAuthenticatedUser('user-b')
            .timeout(const Duration(milliseconds: 50)),
        completes,
      );
      expect(registry.registeredFids, ['fid-new']);

      gateway.releaseStalledRegistration();
      await oldBinding;
      expect(registry.registeredFids, ['fid-new']);
    },
  );
}

class _FakePushGateway implements PushMessagingGateway {
  _FakePushGateway({this.stallFirstRegistration = false});

  final bool stallFirstRegistration;
  final StreamController<void> tokens = StreamController<void>.broadcast();
  final StreamController<void> taps = StreamController<void>.broadcast();
  final StreamController<PushForegroundNotification> foreground =
      StreamController<PushForegroundNotification>.broadcast();
  final Completer<void> registrationStarted = Completer<void>();
  final Completer<void> _registrationRelease = Completer<void>();
  int permissionRequests = 0;
  int registrationAttempts = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<void> get tokenChanges => tokens.stream;

  @override
  Stream<void> get notificationTaps => taps.stream;

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      foreground.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.authorized;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    permissionRequests += 1;
    return PushAuthorizationStatus.authorized;
  }

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async {
    registrationAttempts += 1;
    if (stallFirstRegistration && registrationAttempts == 1) {
      if (!registrationStarted.isCompleted) registrationStarted.complete();
      await _registrationRelease.future;
      return 'fid-old';
    }
    return stallFirstRegistration ? 'fid-new' : 'fid-1';
  }

  @override
  Future<bool> consumeInitialNotificationTap() async => false;

  void releaseStalledRegistration() {
    if (!_registrationRelease.isCompleted) {
      _registrationRelease.complete();
    }
  }
}

class _FakePushRegistry implements PushInstallationRegistry {
  final List<String> registeredFids = [];
  final Completer<void> unregisterStarted = Completer<void>();
  final Completer<void> finishUnregister = Completer<void>();

  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {
    registeredFids.add(fid);
  }

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {
    if (!unregisterStarted.isCompleted) unregisterStarted.complete();
    await finishUnregister.future;
  }
}
