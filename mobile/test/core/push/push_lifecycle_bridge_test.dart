import 'dart:async';

import 'package:aarast_mobile/core/push/push_lifecycle_bridge.dart';
import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('null to null does not duplicate binding or navigation', (
    tester,
  ) async {
    final push = await _createPushController();
    final router = _RecordingRouter();
    addTearDown(push.close);
    addTearDown(router.dispose);

    await _pumpBridge(tester, push: push, router: router, userId: null);
    await _pumpBridge(tester, push: push, router: router, userId: null);

    expect(push.boundUserIds, isEmpty);
    expect(router.goCalls, isEmpty);
    // A first visit is not asked for notifications before an account.
    expect(push.permissionRequests, 0);
  });

  testWidgets('null to user-A binds user-A once', (tester) async {
    final push = await _createPushController();
    final router = _RecordingRouter();
    addTearDown(push.close);
    addTearDown(router.dispose);

    await _pumpBridge(tester, push: push, router: router, userId: null);
    await _pumpBridge(tester, push: push, router: router, userId: 'user-A');

    expect(push.boundUserIds, ['user-A']);
    // Asked once the account exists, and only once.
    expect(push.permissionRequests, 1);
    await _pumpBridge(tester, push: push, router: router, userId: 'user-A');
    expect(push.permissionRequests, 1);
  });

  testWidgets('user-A to null unbinds once', (tester) async {
    final push = await _createPushController();
    final router = _RecordingRouter();
    addTearDown(push.close);
    addTearDown(router.dispose);

    await _pumpBridge(tester, push: push, router: router, userId: 'user-A');
    await _pumpBridge(tester, push: push, router: router, userId: null);

    expect(push.boundUserIds, ['user-A', null]);
  });

  testWidgets('user-A to user-B replaces binding once', (tester) async {
    final push = await _createPushController();
    final router = _RecordingRouter();
    addTearDown(push.close);
    addTearDown(router.dispose);

    await _pumpBridge(tester, push: push, router: router, userId: 'user-A');
    await _pumpBridge(tester, push: push, router: router, userId: 'user-B');

    expect(push.boundUserIds, ['user-A', 'user-B']);
  });

  testWidgets('pending tap before auth opens the inbox once after user-A', (
    tester,
  ) async {
    final push = await _createPushController()
      ..markNotificationsOpenPending();
    final router = _RecordingRouter();
    addTearDown(push.close);
    addTearDown(router.dispose);

    await _pumpBridge(tester, push: push, router: router, userId: null);
    expect(push.notificationsOpenClaims, 0);
    expect(router.goCalls, isEmpty);

    await _pumpBridge(tester, push: push, router: router, userId: 'user-A');

    expect(push.notificationsOpenClaims, 1);
    expect(router.goCalls, ['/notifications']);
  });

  testWidgets('resume while user-A refreshes the existing binding once', (
    tester,
  ) async {
    final push = await _createPushController();
    final router = _RecordingRouter();
    addTearDown(push.close);
    addTearDown(router.dispose);

    await _pumpBridge(tester, push: push, router: router, userId: 'user-A');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(push.registrationRefreshes, 1);
  });

  testWidgets('dispose cancels the foreground subscription once', (
    tester,
  ) async {
    var foregroundCancellations = 0;
    final foreground = StreamController<PushForegroundNotification>.broadcast(
      onCancel: () => foregroundCancellations += 1,
    );
    final push = await _createPushController(foreground: foreground);
    final router = _RecordingRouter();
    addTearDown(push.close);
    addTearDown(router.dispose);

    await _pumpBridge(tester, push: push, router: router, userId: 'user-A');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(foregroundCancellations, 1);
  });
}

Future<void> _pumpBridge(
  WidgetTester tester, {
  required _FakePushController push,
  required _RecordingRouter router,
  required String? userId,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<PushNotificationsController>.value(
      value: push,
      child: MaterialApp(
        home: AarastPushLifecycleBridge(
          router: router,
          authenticatedUserId: userId,
          child: const SizedBox(key: Key('push-bridge-child')),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<_FakePushController> _createPushController({
  StreamController<PushForegroundNotification>? foreground,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return _FakePushController(
    preferences,
    foreground ?? StreamController<PushForegroundNotification>.broadcast(),
  );
}

class _FakePushController extends PushNotificationsController {
  _FakePushController(SharedPreferences preferences, this._foreground)
    : super(
        preferences: preferences,
        gateway: const _UnavailablePushGateway(),
        registrationApi: const _NoopPushRegistry(),
      );

  final StreamController<PushForegroundNotification> _foreground;
  final List<String?> boundUserIds = [];
  int permissionRequests = 0;
  int registrationRefreshes = 0;
  int notificationsOpenClaims = 0;
  bool _notificationsOpenPending = false;

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      _foreground.stream;

  @override
  bool get hasPendingNotificationsOpen => _notificationsOpenPending;

  @override
  Future<void> requestPermissionOnFirstOpen() async {
    permissionRequests += 1;
  }

  @override
  Future<void> bindAuthenticatedUser(String? userId) async {
    boundUserIds.add(userId);
  }

  @override
  Future<void> refreshCurrentRegistration() async {
    registrationRefreshes += 1;
  }

  @override
  bool claimNotificationsOpen() {
    if (!_notificationsOpenPending) return false;
    notificationsOpenClaims += 1;
    _notificationsOpenPending = false;
    notifyListeners();
    return true;
  }

  void markNotificationsOpenPending() {
    _notificationsOpenPending = true;
    notifyListeners();
  }

  Future<void> close() async {
    dispose();
    await _foreground.close();
  }
}

class _RecordingRouter implements GoRouter {
  final List<String> goCalls = [];

  @override
  void go(String location, {Object? extra}) {
    goCalls.add(location);
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailablePushGateway implements PushMessagingGateway {
  const _UnavailablePushGateway();

  @override
  bool get isAvailable => false;

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      const Stream<PushForegroundNotification>.empty();

  @override
  Stream<void> get notificationTaps => const Stream<void>.empty();

  @override
  Stream<void> get tokenChanges => const Stream<void>.empty();

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.denied;

  @override
  Future<bool> consumeInitialNotificationTap() async => false;

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async => '';

  @override
  Future<void> initialize() async {}

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.denied;
}

class _NoopPushRegistry implements PushInstallationRegistry {
  const _NoopPushRegistry();

  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {}

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {}
}
