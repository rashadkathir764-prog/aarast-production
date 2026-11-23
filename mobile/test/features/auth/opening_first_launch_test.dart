// The opening (2.01, 2026-11-23): the fireworks are the welcome of the first
// open on a phone; every later open is the night alone and goes on the
// moment the account is known, with no wait of its own.

import 'dart:async';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/splash_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingServerRepository extends AuthRepository {
  _PendingServerRepository(super.apiClient, super.authStorage);

  final Completer<SafeUser> answer = Completer<SafeUser>();

  @override
  SafeUser? readCachedUser() => null;

  @override
  Future<String?> readAccessToken() async => 'token-without-account-read';

  @override
  Future<SafeUser> me() => answer.future;
}

Future<Widget> _opening({
  required bool celebratedBefore,
  AuthRepository Function(ApiClient, AuthStorage)? repository,
  void Function(DevicePreferences, AuthController)? capture,
}) async {
  SharedPreferences.setMockInitialValues({
    if (celebratedBefore) 'aarast_opening_celebrated': true,
  });
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final controller = AuthController(
    (repository ?? AuthRepository.new)(apiClient, authStorage),
  );
  unawaited(controller.restoreSession());
  final device = DevicePreferences(preferences);
  capture?.call(device, controller);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const Scaffold(body: Text('welcome')),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider<GuestOnboardingStorage>.value(
        value: GuestOnboardingStorage(preferences),
      ),
      ChangeNotifierProvider<DevicePreferences>.value(value: device),
      ChangeNotifierProvider<AuthController>.value(value: controller),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('the first open is the fireworks, and remembered', (
    tester,
  ) async {
    late DevicePreferences device;
    await tester.pumpWidget(
      await _opening(
        celebratedBefore: false,
        capture: (preferences, _) => device = preferences,
      ),
    );

    expect(find.byType(JourneyCelebrationSky), findsOneWidget);
    // It begins as the launch drew it: the name, at its size, at the centre.
    final name = find.byType(JourneyWordmark);
    expect(tester.widget<JourneyWordmark>(name).size, JourneyLaunchMark.size);
    expect(
      tester.getCenter(name).dy,
      moreOrLessEquals(
        tester.view.physicalSize.height / tester.view.devicePixelRatio / 2,
        epsilon: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('welcome'), findsNothing, reason: 'the 900ms play');

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('welcome'), findsOneWidget);
    expect(device.openingCelebrated, isTrue);
  });

  testWidgets('a later open is the night alone and goes straight in', (
    tester,
  ) async {
    await tester.pumpWidget(await _opening(celebratedBefore: true));

    expect(find.byType(JourneyCelebrationSky), findsNothing);
    expect(find.byKey(const ValueKey('opening-night')), findsOneWidget);
    // The launch's name stays as the phone drew it until the page opens.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('opening-night')),
        matching: find.byType(JourneyLaunchMark),
      ),
      findsOneWidget,
    );

    // No play and no poll: the frame after the account is known.
    await tester.pump();
    await tester.pump();
    expect(find.text('welcome'), findsOneWidget);
  });

  testWidgets('a later open waits for the account by hearing it, not polling', (
    tester,
  ) async {
    late _PendingServerRepository pending;
    await tester.pumpWidget(
      await _opening(
        celebratedBefore: true,
        repository: (api, storage) =>
            pending = _PendingServerRepository(api, storage),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('home'), findsNothing);
    expect(find.byKey(const ValueKey('opening-night')), findsOneWidget);

    pending.answer.complete(
      const SafeUser(id: 'u', name: 'U', role: 'USER', status: 'ACTIVE'),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
