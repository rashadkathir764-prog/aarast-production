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
  bool noGoogleServices = false,
  // The app asked once and the person said no: from Android 13 only that
  // makes «denied» notifications turned off.
  bool askedBefore = true,
  bool settingsOpen = true,
  bool signedIn = false,
}) async {
  _settingsOpened = 0;
  SharedPreferences.setMockInitialValues({
    if (askedBefore) pushPermissionRequestedPreferenceKey: true,
  });
  final stored = await SharedPreferences.getInstance();
  final preferences = DevicePreferences(stored);
  final gateway = _Gateway(status, afterAsking, noGoogleServices);
  final push = PushNotificationsController(
    preferences: stored,
    gateway: gateway,
    registrationApi: _Registry(),
    openPhoneNotificationSettings: () async {
      _settingsOpened += 1;
      return settingsOpen;
    },
  );
  await push.initialize();
  if (signedIn) await push.bindAuthenticatedUser('user-1');
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

  // RA-MO-359: a phone with no Google services (Huawei) registers nothing,
  // and the permission is no help: the card says it, and does not send the
  // reader to settings that cannot fix it.
  testWidgets('a phone with no Google services says alerts stay in the app', (
    tester,
  ) async {
    await _pump(
      tester,
      status: PushAuthorizationStatus.authorized,
      noGoogleServices: true,
    );

    expect(find.byKey(const ValueKey('push-off-card')), findsOneWidget);
    expect(find.text('تنبيهات الجوال ما تشتغل هنا'), findsOneWidget);
    expect(find.textContaining('جوالك ما يدعم تنبيهات الجوال'), findsOneWidget);
    expect(find.textContaining('داخل اعّرست'), findsOneWidget);
    expect(find.byKey(const ValueKey('push-off-open')), findsNothing);
    expect(find.text('التنبيهات مقفلة'), findsNothing);
    // «لاحقًا» puts it away like the other card.
    expect(find.byKey(const ValueKey('push-off-later')), findsOneWidget);
  });

  // The plugin says «denied» on Android 13 before the app ever asked: that
  // phone was not turned off, it was never asked, and the card told it to
  // open its settings.
  testWidgets('an Android 13 phone never asked is not told they are off', (
    tester,
  ) async {
    await _pump(tester, askedBefore: false);

    expect(find.byKey(const ValueKey('push-off-card')), findsNothing);
    expect(find.text('التنبيهات مقفلة'), findsNothing);
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

  // Turned off by the person, they come back on in the phone's settings
  // only: the button used to ask again, which a phone refused twice (or
  // below Android 13) never shows, so nothing happened.
  testWidgets('«افتح الإعدادات» opens the phone\'s settings, and coming back '
      'with them on puts the card away', (tester) async {
    final (_, gateway) = await _pump(tester, signedIn: true);
    final registeredWhileOff = gateway.registered;

    await tester.tap(find.text('افتح الإعدادات'));
    await tester.pumpAndSettle();

    expect(_settingsOpened, 1);
    expect(gateway.asked, 0, reason: 'the phone is not asked again');
    expect(find.byKey(const ValueKey('push-off-card')), findsOneWidget);

    // Turned on there, then back to the app.
    gateway.status = PushAuthorizationStatus.authorized;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-off-card')), findsNothing);
    expect(find.text('انفتحت التنبيهات.'), findsOneWidget);
    expect(
      gateway.registered,
      greaterThan(registeredWhileOff),
      reason: 'registered again',
    );
  });

  testWidgets('back from the settings still off, the card stays', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('افتح الإعدادات'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('push-off-card')), findsOneWidget);
    expect(find.text('انفتحت التنبيهات.'), findsNothing);
  });

  testWidgets('a phone that will not open its settings is told the way', (
    tester,
  ) async {
    await _pump(tester, settingsOpen: false);
    await tester.tap(find.text('افتح الإعدادات'));
    await tester.pumpAndSettle();

    expect(find.textContaining('من إعدادات الجوال › التطبيقات'), findsOneWidget);
  });
}

int _settingsOpened = 0;

class _Gateway implements PushMessagingGateway {
  _Gateway(this.status, this.afterAsking, [this.noGoogleServices = false]);

  PushAuthorizationStatus status;
  int registered = 0;
  final PushAuthorizationStatus afterAsking;
  final bool noGoogleServices;
  int asked = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<void> get tokenChanges => const Stream.empty();

  @override
  Stream<PushNotificationTap> get notificationTaps =>
      const Stream<PushNotificationTap>.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      const Stream.empty();

  @override
  Future<void> initialize() async {
    if (noGoogleServices) throw const PushUnavailableOnThisPhone();
  }

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async => status;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    asked += 1;
    return afterAsking;
  }

  /// An Android 13 phone: «denied» is the plugin's word for «not granted».
  @override
  Future<int?> androidSdkInt() async => 33;

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async {
    registered += 1;
    return 'fid-1';
  }

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
