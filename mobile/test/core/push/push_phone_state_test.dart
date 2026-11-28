import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:aarast_mobile/core/push/push_system_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/plugin_like_push_gateway.dart';

// The settings page's banner says what the phone does with the alerts, as
// the real plugin reports it: on Android 13 «denied» before the app ever
// asked is a question still to ask, not alerts turned off.

Future<PushNotificationsController> _controller(
  PluginLikePushGateway gateway, {
  bool askedBefore = false,
  Future<bool> Function()? openSettings,
}) async {
  SharedPreferences.setMockInitialValues({
    if (askedBefore) pushPermissionRequestedPreferenceKey: true,
  });
  final push = PushNotificationsController(
    preferences: await SharedPreferences.getInstance(),
    gateway: gateway,
    registrationApi: RecordingPushRegistry(),
    openPhoneNotificationSettings: openSettings ?? () async => true,
  );
  await push.initialize();
  return push;
}

void main() {
  test('Android 13, never asked: not asked, and one tap asks the phone', () async {
    final gateway = PluginLikePushGateway();
    final push = await _controller(gateway);

    expect(await push.phoneState(), PushPhoneState.notAsked);
    expect(await push.askFromSettings(), PushPhoneState.on);
    expect(gateway.permissionRequests, 1);
  });

  test('Android 13, asked and refused: off, and only the phone turns them on', () async {
    final gateway = PluginLikePushGateway(grantsWhenAsked: false);
    final push = await _controller(gateway);

    expect(await push.askFromSettings(), PushPhoneState.off);
    // Asking again from the page asks nothing: the app asks once.
    expect(await push.askFromSettings(), PushPhoneState.off);
    expect(gateway.permissionRequests, 1);
  });

  test('below Android 13 they are on until the person turns them off', () async {
    expect(
      await (await _controller(PluginLikePushGateway(sdkInt: 30))).phoneState(),
      PushPhoneState.on,
    );
    expect(
      await (await _controller(
        PluginLikePushGateway(sdkInt: 30, granted: false),
      )).phoneState(),
      PushPhoneState.off,
    );
  });

  test('a phone with no Google services has no phone alerts at all', () async {
    final push = await _controller(
      PluginLikePushGateway(noGoogleServices: true, granted: true),
    );
    expect(await push.phoneState(), PushPhoneState.unavailable);
  });

  test('a channel turned off in the phone is named, not taken for «on»', () async {
    SharedPreferences.setMockInitialValues({});
    final system = _BlockingSystem({'aarast_messages'});
    final push = PushNotificationsController(
      preferences: await SharedPreferences.getInstance(),
      gateway: PluginLikePushGateway(granted: true),
      registrationApi: RecordingPushRegistry(),
      systemNotifications: system,
    );
    await push.initialize();

    expect(await push.phoneState(), PushPhoneState.channelsOff);
    expect(push.blockedChannels, {'aarast_messages'});

    system.blocked = {};
    expect(await push.phoneState(), PushPhoneState.on);
  });

  test('allowed but not registered with the server is «not linked»', () async {
    SharedPreferences.setMockInitialValues({});
    final push = PushNotificationsController(
      preferences: await SharedPreferences.getInstance(),
      gateway: PluginLikePushGateway(granted: true),
      registrationApi: _RefusingRegistry(),
    );
    await push.initialize();
    await push.bindAuthenticatedUser('user-1');
    expect(await push.phoneState(), PushPhoneState.notLinked);
  });

  test('opening the phone\'s settings says whether they opened', () async {
    var opened = 0;
    final push = await _controller(
      PluginLikePushGateway(granted: false),
      askedBefore: true,
      openSettings: () async {
        opened += 1;
        return true;
      },
    );
    expect(await push.openPhoneSettings(), isTrue);
    expect(opened, 1);

    final failing = await _controller(
      PluginLikePushGateway(granted: false),
      openSettings: () async => throw StateError('no settings app'),
    );
    expect(await failing.openPhoneSettings(), isFalse);
  });
}

class _BlockingSystem extends NoPushSystemNotifications {
  _BlockingSystem(this.blocked);

  Set<String> blocked;

  @override
  Future<Set<String>> blockedChannels() async => blocked;
}

class _RefusingRegistry implements PushInstallationRegistry {
  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {
    throw StateError('server unreachable');
  }

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {}
}