import 'dart:async';

import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/push/notice_arrivals.dart';
import 'package:aarast_mobile/core/push/open_conversation.dart';
import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:aarast_mobile/core/push/push_system_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a push in front (the phone shows none by itself then)', () {
    Future<
      (
        PushNotificationsController,
        _FakePushGateway,
        _FakeSystemNotifications,
        OpenConversationRegistry,
        NoticeArrivals,
      )
    >
    setUp({PushNotificationTap? launchTap}) async {
      SharedPreferences.setMockInitialValues({
        pushPermissionRequestedPreferenceKey: true,
      });
      final preferences = await SharedPreferences.getInstance();
      final gateway = _FakePushGateway();
      final system = _FakeSystemNotifications(launchTap: launchTap);
      final conversations = OpenConversationRegistry();
      final arrivals = NoticeArrivals();
      final controller = PushNotificationsController(
        preferences: preferences,
        gateway: gateway,
        registrationApi: _FakePushRegistry(),
        systemNotifications: system,
        openConversations: conversations,
        noticeArrivals: arrivals,
      );
      addTearDown(controller.dispose);
      addTearDown(arrivals.close);
      await controller.initialize();
      return (controller, gateway, system, conversations, arrivals);
    }

    const chatPush = PushForegroundNotification(
      title: 'رسالة جديدة',
      message: 'وصلتك رسالة في اعّرست.',
      notificationId: 'n-1',
      type: 'CHAT_MESSAGE_RECEIVED',
      androidChannelId: 'aarast_messages',
      tag: 'aarast_chat_c-1',
      conversationId: 'c-1',
    );

    test('is the phone\'s own notification, not the in-app line too, and '
        'the inbox and the bell hear of it', () async {
      final (controller, gateway, system, _, arrivals) = await setUp();
      var toasts = 0;
      controller.foregroundNotifications.listen((_) => toasts++);
      var heard = 0;
      arrivals.stream.listen((_) => heard++);

      gateway.foreground.add(chatPush);
      await Future<void>.delayed(Duration.zero);

      expect(system.shown, [chatPush]);
      expect(toasts, 0, reason: 'one alert for one message');
      expect(heard, 1);
    });

    test('is not shown for the conversation the reader has open', () async {
      final (controller, gateway, system, conversations, arrivals) =
          await setUp();
      var toasts = 0;
      controller.foregroundNotifications.listen((_) => toasts++);
      var heard = 0;
      arrivals.stream.listen((_) => heard++);
      conversations.opened('c-1');

      gateway.foreground.add(chatPush);
      await Future<void>.delayed(Duration.zero);

      expect(system.shown, isEmpty);
      expect(toasts, 0);
      expect(heard, 1, reason: 'the count is still read again');

      conversations.closed('c-1');
      gateway.foreground.add(chatPush);
      await Future<void>.delayed(Duration.zero);
      expect(system.shown, [chatPush]);
    });

    test('with notifications not allowed shows no phone notification, only '
        'the in-app line', () async {
      final (controller, gateway, system, _, _) = await setUp();
      gateway.status = PushAuthorizationStatus.denied;
      var toasts = 0;
      controller.foregroundNotifications.listen((_) => toasts++);

      gateway.foreground.add(chatPush);
      await Future<void>.delayed(Duration.zero);

      expect(system.shown, isEmpty);
      expect(toasts, 1);
    });

    test('a tap on it opens its notice as a tap on any push does', () async {
      final (controller, _, system, _, _) = await setUp();

      system.tapsController.add(
        const PushNotificationTap(notificationId: 'n-1'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.claimNotificationsOpen()?.notificationId, 'n-1');
    });

    test(
      'one tapped after the app closed opens its notice at the start',
      () async {
        final (controller, _, _, _, _) = await setUp(
          launchTap: const PushNotificationTap(notificationId: 'n-9'),
        );

        expect(controller.claimNotificationsOpen()?.notificationId, 'n-9');
      },
    );

    test('signing out, or another account, empties the tray', () async {
      final (controller, _, system, _, _) = await setUp();
      await controller.bindAuthenticatedUser('user-a');
      expect(system.cancelled, 0);

      await controller.bindAuthenticatedUser('user-b');
      expect(
        system.cancelled,
        1,
        reason: 'user-a\'s notices are not user-b\'s',
      );

      controller.beginAccountTeardown('user-b');
      expect(system.cancelled, 2);
    });
  });

  test('the server answering again registers the phone again and reads the '
      'count once', () async {
    SharedPreferences.setMockInitialValues({
      pushPermissionRequestedPreferenceKey: true,
    });
    final preferences = await SharedPreferences.getInstance();
    final registry = _FakePushRegistry();
    final reachability = ServerReachability();
    final arrivals = NoticeArrivals();
    addTearDown(arrivals.close);
    final controller = PushNotificationsController(
      preferences: preferences,
      gateway: _FakePushGateway(),
      registrationApi: registry,
      noticeArrivals: arrivals,
      reachability: reachability,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.bindAuthenticatedUser('user-1');
    expect(registry.registeredFids, ['fid-1']);
    var heard = 0;
    arrivals.stream.listen((_) => heard++);

    reachability.noteFailure(
      ReachabilityFailure(
        cause: ReachabilityCause.noNetwork,
        at: DateTime(2026, 11, 26),
        path: '/api/v1/x',
      ),
    );
    reachability.noteReached();
    reachability.noteReached();
    await Future<void>.delayed(Duration.zero);

    expect(registry.registeredFids, ['fid-1', 'fid-1']);
    expect(heard, 1);
  });

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

  // RA-MO-357: a tap carries the id of the notice the push announced, and
  // only that: the notice's target is read from the notice, never the push.
  test('a notification tap carries the id of its notice, once', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final gateway = _FakePushGateway();
    final controller = PushNotificationsController(
      preferences: preferences,
      gateway: gateway,
      registrationApi: _FakePushRegistry(),
    );

    await controller.initialize();
    gateway.taps.add(const PushNotificationTap(notificationId: 'n-1'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.hasPendingNotificationsOpen, isTrue);
    expect(controller.claimNotificationsOpen()?.notificationId, 'n-1');
    expect(controller.claimNotificationsOpen(), isNull);
  });

  test(
    'a tap that names no notice still opens the inbox, and the last tap wins',
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
      gateway.taps.add(const PushNotificationTap());
      await Future<void>.delayed(Duration.zero);
      expect(controller.claimNotificationsOpen()?.notificationId, isNull);

      gateway.taps.add(const PushNotificationTap(notificationId: 'n-1'));
      gateway.taps.add(const PushNotificationTap(notificationId: 'n-2'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.claimNotificationsOpen()?.notificationId, 'n-2');
    },
  );

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

  // Startup: push is set up after the first frame, so the app's root may
  // listen, bind the account and ask for permission before it is ready.
  test('what was asked before push was set up is served once it is', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final gateway = _FakePushGateway();
    final registry = _FakePushRegistry();
    final controller = PushNotificationsController(
      preferences: preferences,
      gateway: gateway,
      registrationApi: registry,
    );
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);

    final received = controller.foregroundNotifications.first;
    await controller.bindAuthenticatedUser('user-1');
    await controller.requestPermissionOnFirstOpen();
    expect(gateway.permissionRequests, 0);
    expect(registry.registeredFids, isEmpty);

    await controller.initialize();
    expect(controller.isAvailable, isTrue);
    expect(notified, greaterThan(0), reason: 'the root reads it again');
    expect(gateway.permissionRequests, 1);
    expect(registry.registeredFids, ['fid-1']);

    gateway.foreground.add(
      const PushForegroundNotification(title: 'اعّرست', message: 'جديد'),
    );
    await expectLater(
      received,
      completion(
        isA<PushForegroundNotification>().having(
          (value) => value.message,
          'message',
          'جديد',
        ),
      ),
    );
  });

  test(
    '«are they off?» asked while push is being set up waits for it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final gateway = _FakePushGateway()
        ..status = PushAuthorizationStatus.denied;
      final controller = PushNotificationsController(
        preferences: preferences,
        gateway: gateway,
        registrationApi: _FakePushRegistry(),
      );
      addTearDown(controller.dispose);

      final setUp = controller.initialize();
      expect(await controller.isTurnedOff(), isTrue);
      await setUp;
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

class _FakeSystemNotifications implements PushSystemNotifications {
  _FakeSystemNotifications({this.launchTap});

  final PushNotificationTap? launchTap;
  final List<PushForegroundNotification> shown = [];
  final StreamController<PushNotificationTap> tapsController =
      StreamController<PushNotificationTap>.broadcast();
  int cancelled = 0;
  bool showFails = false;

  @override
  Stream<PushNotificationTap> get taps => tapsController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<PushNotificationTap?> consumeLaunchTap() async => launchTap;

  @override
  Future<bool> show(PushForegroundNotification notification) async {
    if (showFails) return false;
    shown.add(notification);
    return true;
  }

  @override
  Future<void> cancelAll() async => cancelled++;

  @override
  Future<Set<String>> blockedChannels() async => const {};
}

class _FakePushGateway implements PushMessagingGateway {
  _FakePushGateway({this.stallFirstRegistration = false});

  final bool stallFirstRegistration;
  final StreamController<void> tokens = StreamController<void>.broadcast();
  final StreamController<PushNotificationTap> taps =
      StreamController<PushNotificationTap>.broadcast();
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
  Stream<PushNotificationTap> get notificationTaps => taps.stream;

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      foreground.stream;

  @override
  Future<void> initialize() async {}

  PushAuthorizationStatus status = PushAuthorizationStatus.authorized;

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async => status;

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
  Future<PushNotificationTap?> consumeInitialNotificationTap() async => null;

  /// A phone that cannot say its version: «denied» stays the person's.
  int? sdkInt;

  @override
  Future<int?> androidSdkInt() async => sdkInt;

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
