import 'dart:async';

import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
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

      expect(gateway.localDeleteCount, 0);
      expect(registry.registeredFids, ['fid-1', 'fid-1']);
    },
  );
}

class _FakePushGateway implements PushMessagingGateway {
  final StreamController<void> installations =
      StreamController<void>.broadcast();
  final StreamController<void> tokens = StreamController<void>.broadcast();
  final StreamController<void> taps = StreamController<void>.broadcast();
  int permissionRequests = 0;
  int localDeleteCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<void> get installationChanges => installations.stream;

  @override
  Stream<void> get tokenChanges => tokens.stream;

  @override
  Stream<void> get notificationTaps => taps.stream;

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
  Future<String> ensureRegistrationAndGetInstallationId() async => 'fid-1';

  @override
  Future<void> deleteLocalRegistration() async {
    localDeleteCount += 1;
  }

  @override
  Future<bool> consumeInitialNotificationTap() async => false;
}

class _FakePushRegistry implements PushInstallationRegistry {
  final List<String> registeredFids = [];
  final Completer<void> unregisterStarted = Completer<void>();
  final Completer<void> finishUnregister = Completer<void>();

  @override
  Future<void> registerAndroid(String fid) async {
    registeredFids.add(fid);
  }

  @override
  Future<void> unregisterAndroid(String fid) async {
    if (!unregisterStarted.isCompleted) unregisterStarted.complete();
    await finishUnregister.future;
  }
}
