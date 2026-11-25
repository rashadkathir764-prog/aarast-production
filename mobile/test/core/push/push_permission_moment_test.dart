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

// RA-MO-360: the phone's «اسمح بالإشعارات» question came the moment the
// account was made, before the person had a reason to say yes. It now comes
// at the first reminder set or the first plan made, after one line that says
// what the alerts are for.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(PushNotificationsController, _Gateway)> controller({
    PushAuthorizationStatus status = PushAuthorizationStatus.notDetermined,
    bool alreadyAsked = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (alreadyAsked) pushPermissionRequestedPreferenceKey: true,
    });
    final preferences = await SharedPreferences.getInstance();
    final gateway = _Gateway()..status = status;
    final push = PushNotificationsController(
      preferences: preferences,
      gateway: gateway,
      registrationApi: _Registry(),
    );
    addTearDown(push.dispose);
    await push.initialize();
    await push.bindAuthenticatedUser('user-1');
    return (push, gateway);
  }

  group('the moment', () {
    test('an account just made is not asked: only the moment explains', () async {
      final (push, gateway) = await controller();

      expect(push.hasPendingPermissionExplanation, isFalse);
      expect(gateway.permissionRequests, 0);

      await push.permissionMomentReached();

      expect(push.hasPendingPermissionExplanation, isTrue);
      expect(
        gateway.permissionRequests,
        0,
        reason: 'the phone asks only after the explanation is accepted',
      );
    });

    test('the explanation is claimed once, and offered once a session', () async {
      final (push, _) = await controller();
      await push.permissionMomentReached();

      expect(push.claimPermissionExplanation(), isTrue);
      expect(push.claimPermissionExplanation(), isFalse);
      expect(push.hasPendingPermissionExplanation, isFalse);

      await push.permissionMomentReached();
      expect(
        push.hasPendingPermissionExplanation,
        isFalse,
        reason: 'a second reminder does not nag in the same session',
      );
    });

    test('a person who said yes already is not asked again', () async {
      final (push, _) = await controller(alreadyAsked: true);
      await push.permissionMomentReached();
      expect(push.hasPendingPermissionExplanation, isFalse);
    });

    test('notifications already on or turned off need no explanation', () async {
      for (final status in [
        PushAuthorizationStatus.authorized,
        PushAuthorizationStatus.denied,
      ]) {
        final (push, _) = await controller(status: status);
        await push.permissionMomentReached();
        expect(push.hasPendingPermissionExplanation, isFalse, reason: '$status');
      }
    });

    test('with no account there is nothing to ask for', () async {
      final (push, _) = await controller();
      await push.bindAuthenticatedUser(null);
      await push.permissionMomentReached();
      expect(push.hasPendingPermissionExplanation, isFalse);
    });

    test('a phone that cannot have push is not explained to', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final gateway = _Gateway()..noGoogleServices = true;
      final push = PushNotificationsController(
        preferences: preferences,
        gateway: gateway,
        registrationApi: _Registry(),
      );
      addTearDown(push.dispose);
      await push.initialize();
      await push.bindAuthenticatedUser('user-1');

      await push.permissionMomentReached();

      expect(push.hasPendingPermissionExplanation, isFalse);
    });
  });

  group('the sheet', () {
    Future<(PushNotificationsController, _Gateway)> pump(
      WidgetTester tester,
    ) async {
      final (push, gateway) = (await tester.runAsync(controller))!;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<PushNotificationsController>.value(
          value: push,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => AarastPushLifecycleBridge(
              router: router,
              authenticatedUserId: 'user-1',
              child: child!,
            ),
          ),
        ),
      );
      await tester.pump();
      return (push, gateway);
    }

    testWidgets('one line says what the alerts are for; «اسمح» asks the phone', (
      tester,
    ) async {
      final (push, gateway) = await pump(tester);
      expect(find.byKey(const ValueKey('push-permission-sheet')), findsNothing);
      expect(gateway.permissionRequests, 0);

      await tester.runAsync(push.permissionMomentReached);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('push-permission-sheet')), findsOneWidget);
      expect(find.textContaining('مواعيد الدفعات'), findsOneWidget);
      expect(gateway.permissionRequests, 0);

      await tester.tap(find.byKey(const ValueKey('push-permission-allow')));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 1);
      expect(find.byKey(const ValueKey('push-permission-sheet')), findsNothing);
    });

    testWidgets('«لاحقًا» asks nothing of the phone', (tester) async {
      final (push, gateway) = await pump(tester);

      await tester.runAsync(push.permissionMomentReached);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('push-permission-later')));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 0);
      expect(find.byKey(const ValueKey('push-permission-sheet')), findsNothing);
    });

    testWidgets('signing in alone asks nothing, no sheet and no phone question', (
      tester,
    ) async {
      final (_, gateway) = await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('push-permission-sheet')), findsNothing);
      expect(gateway.permissionRequests, 0);
    });
  });
}

class _Gateway implements PushMessagingGateway {
  PushAuthorizationStatus status = PushAuthorizationStatus.notDetermined;
  bool noGoogleServices = false;
  int permissionRequests = 0;

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
  Future<PushAuthorizationStatus> authorizationStatus() async => status;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    permissionRequests += 1;
    status = PushAuthorizationStatus.authorized;
    return status;
  }

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async => 'fid-1';

  @override
  Future<PushNotificationTap?> consumeInitialNotificationTap() async => null;
}

class _Registry implements PushInstallationRegistry {
  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {}

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {}
}
