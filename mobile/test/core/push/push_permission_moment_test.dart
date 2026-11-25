import 'package:aarast_mobile/core/push/push_lifecycle_bridge.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/plugin_like_push_gateway.dart';

// RA-MO-360: the phone's «اسمح بالإشعارات» question came the moment the
// account was made, before the person had a reason to say yes. It now comes
// at the first reminder set or the first plan made, after one line that says
// what the alerts are for.
//
// The gateway here is the plugin as it is on a phone: on Android 13 and
// later it reports «denied» before the app ever asked. The fakes before
// reported «not determined», a state the plugin never gives on Android, and
// hid that no sheet, no question and no registration ever happened.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(PushNotificationsController, PluginLikePushGateway, _Registry)>
  controller({
    int? sdkInt = 33,
    bool? granted,
    bool grantsWhenAsked = true,
    bool alreadyAsked = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (alreadyAsked) pushPermissionRequestedPreferenceKey: true,
    });
    final preferences = await SharedPreferences.getInstance();
    final gateway = PluginLikePushGateway(
      sdkInt: sdkInt,
      granted: granted,
      grantsWhenAsked: grantsWhenAsked,
    );
    final registry = _Registry();
    final push = PushNotificationsController(
      preferences: preferences,
      gateway: gateway,
      registrationApi: registry,
    );
    addTearDown(push.dispose);
    addTearDown(gateway.close);
    await push.initialize();
    await push.bindAuthenticatedUser('user-1');
    return (push, gateway, registry);
  }

  group('the moment', () {
    test(
      'an account just made is not asked: only the moment explains',
      () async {
        final (push, gateway, registry) = await controller();

        expect(push.hasPendingPermissionExplanation, isFalse);
        expect(gateway.permissionRequests, 0);
        expect(registry.registered, isEmpty);

        await push.permissionMomentReached();

        expect(
          push.hasPendingPermissionExplanation,
          isTrue,
          reason:
              'Android 13 reports «denied» before the app asked: that is a '
              'question still to ask, not notifications turned off',
        );
        expect(
          gateway.permissionRequests,
          0,
          reason: 'the phone asks only after the explanation is accepted',
        );
      },
    );

    test('the question is asked, and the grant registers the phone', () async {
      final (push, gateway, registry) = await controller();
      await push.permissionMomentReached();
      expect(push.claimPermissionExplanation(), isTrue);

      await push.requestPermissionOnFirstOpen();

      expect(gateway.permissionRequests, 1);
      expect(registry.registered, ['fid-1']);
      expect(push.registeredFid, 'fid-1');
    });

    test('a refusal at the phone registers nothing, and is not '
        'explained again', () async {
      final (push, gateway, registry) = await controller(
        grantsWhenAsked: false,
      );
      await push.permissionMomentReached();
      push.claimPermissionExplanation();
      await push.requestPermissionOnFirstOpen();

      expect(gateway.permissionRequests, 1);
      expect(registry.registered, isEmpty);
      // Asked once: «denied» is now the person's answer.
      expect(await push.isTurnedOff(), isTrue);
      await push.permissionMomentReached();
      expect(push.hasPendingPermissionExplanation, isFalse);
    });

    test(
      'the explanation is claimed once, and offered once a session',
      () async {
        final (push, _, _) = await controller();
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
      },
    );

    test('a person who said yes already is not asked again', () async {
      final (push, _, _) = await controller(alreadyAsked: true);
      await push.permissionMomentReached();
      expect(push.hasPendingPermissionExplanation, isFalse);
    });

    test('notifications already on need no explanation, and register '
        'with the account', () async {
      final (push, _, registry) = await controller(granted: true);
      await push.permissionMomentReached();
      expect(push.hasPendingPermissionExplanation, isFalse);
      expect(registry.registered, ['fid-1']);
    });

    test('below Android 13 «denied» is the person\'s own: they were turned '
        'off, and no sheet asks again', () async {
      final (push, _, _) = await controller(sdkInt: 32, granted: false);
      await push.permissionMomentReached();
      expect(push.hasPendingPermissionExplanation, isFalse);
      expect(await push.isTurnedOff(), isTrue);
    });

    test('an Android 13 phone never asked is not «turned off»', () async {
      final (push, _, _) = await controller();
      expect(await push.isTurnedOff(), isFalse);
    });

    test(
      'a phone that cannot say its version keeps «denied» as it is',
      () async {
        final (push, _, _) = await controller(sdkInt: null, granted: false);
        await push.permissionMomentReached();
        expect(push.hasPendingPermissionExplanation, isFalse);
      },
    );

    test('with no account there is nothing to ask for', () async {
      final (push, _, _) = await controller();
      await push.bindAuthenticatedUser(null);
      await push.permissionMomentReached();
      expect(push.hasPendingPermissionExplanation, isFalse);
    });

    test('a phone that cannot have push is not explained to', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final gateway = PluginLikePushGateway(noGoogleServices: true);
      addTearDown(gateway.close);
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
    Future<(PushNotificationsController, PluginLikePushGateway, _Registry)>
    pump(WidgetTester tester) async {
      final (push, gateway, registry) = (await tester.runAsync(controller))!;
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
      return (push, gateway, registry);
    }

    testWidgets(
      'one line says what the alerts are for; «اسمح» asks the phone, and '
      'the grant registers it',
      (tester) async {
        final (push, gateway, registry) = await pump(tester);
        expect(
          find.byKey(const ValueKey('push-permission-sheet')),
          findsNothing,
        );
        expect(gateway.permissionRequests, 0);

        await tester.runAsync(push.permissionMomentReached);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('push-permission-sheet')),
          findsOneWidget,
        );
        expect(find.textContaining('مواعيد الدفعات'), findsOneWidget);
        expect(gateway.permissionRequests, 0);

        await tester.tap(find.byKey(const ValueKey('push-permission-allow')));
        await tester.pumpAndSettle();
        // The registration runs after the phone's answer, off the frame.
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }

        expect(gateway.permissionRequests, 1);
        expect(registry.registered, ['fid-1']);
        expect(
          find.byKey(const ValueKey('push-permission-sheet')),
          findsNothing,
        );
      },
    );

    testWidgets('a provider is told of his decision and requests', (
      tester,
    ) async {
      final (push, _, _) = await pump(tester);

      await tester.runAsync(
        () =>
            push.permissionMomentReached(reason: PushPermissionReason.provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('نخبرك بكل جديد'), findsOneWidget);
      expect(find.textContaining('قرار مراجعة طلبك'), findsOneWidget);
      expect(find.textContaining('مواعيد الدفعات'), findsNothing);
    });

    testWidgets('a participant is told of the tasks given to them', (
      tester,
    ) async {
      final (push, _, _) = await pump(tester);

      await tester.runAsync(
        () => push.permissionMomentReached(
          reason: PushPermissionReason.participant,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نخبرك بما يخصّك'), findsOneWidget);
      expect(find.textContaining('المهام المسندة إليك'), findsOneWidget);
    });

    testWidgets('«لاحقًا» asks nothing of the phone', (tester) async {
      final (push, gateway, registry) = await pump(tester);

      await tester.runAsync(push.permissionMomentReached);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('push-permission-later')));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 0);
      expect(registry.registered, isEmpty);
      expect(find.byKey(const ValueKey('push-permission-sheet')), findsNothing);
    });

    testWidgets(
      'signing in alone asks nothing, no sheet and no phone question',
      (tester) async {
        final (_, gateway, _) = await pump(tester);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('push-permission-sheet')),
          findsNothing,
        );
        expect(gateway.permissionRequests, 0);
      },
    );
  });
}

class _Registry implements PushInstallationRegistry {
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
