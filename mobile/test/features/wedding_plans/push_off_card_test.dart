import 'dart:async';

import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/push_off_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// w39: the phone has the app's notifications off.

final _now = DateTime(2026, 10, 24, 12);

Future<(DevicePreferences, _Gateway)> _pump(
  WidgetTester tester, {
  PushAuthorizationStatus status = PushAuthorizationStatus.denied,
  PushAuthorizationStatus afterAsking = PushAuthorizationStatus.denied,
}) async {
  SharedPreferences.setMockInitialValues({});
  final stored = await SharedPreferences.getInstance();
  final preferences = DevicePreferences(stored);
  final gateway = _Gateway(status, afterAsking);
  final push = PushNotificationsController(
    preferences: stored,
    gateway: gateway,
    registrationApi: _Registry(),
  );
  await push.initialize();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DevicePreferences>.value(value: preferences),
        ChangeNotifierProvider<PushNotificationsController>.value(value: push),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: PushOffCard(now: _now)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (preferences, gateway);
}

void main() {
  testWidgets('notifications turned off on the phone are named', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('التنبيهات مقفلة'), findsOneWidget);
    expect(find.text('افتح الإعدادات'), findsOneWidget);
    expect(find.textContaining('أقساط'), findsNothing);
  });

  testWidgets('allowed notifications show nothing', (tester) async {
    await _pump(tester, status: PushAuthorizationStatus.authorized);

    expect(find.byKey(const ValueKey('push-off-card')), findsNothing);
  });

  testWidgets('«لاحقًا» puts the card away for a week', (tester) async {
    final (preferences, _) = await _pump(tester);

    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-off-card')), findsNothing);
    expect(
      preferences.pushCardHiddenUntil,
      _now.add(DevicePreferences.pushCardPause),
    );
  });

  testWidgets('asking again turns them on and the card goes', (tester) async {
    final (_, gateway) = await _pump(
      tester,
      afterAsking: PushAuthorizationStatus.authorized,
    );

    await tester.tap(find.text('افتح الإعدادات'));
    await tester.pumpAndSettle();

    expect(gateway.asked, 1);
    expect(find.byKey(const ValueKey('push-off-card')), findsNothing);
  });
}

class _Gateway implements PushMessagingGateway {
  _Gateway(this.status, this.afterAsking);

  final PushAuthorizationStatus status;
  final PushAuthorizationStatus afterAsking;
  int asked = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<void> get tokenChanges => const Stream.empty();

  @override
  Stream<void> get notificationTaps => const Stream.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async => status;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    asked += 1;
    return afterAsking;
  }

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async => 'fid-1';

  @override
  Future<bool> consumeInitialNotificationTap() async => false;
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
