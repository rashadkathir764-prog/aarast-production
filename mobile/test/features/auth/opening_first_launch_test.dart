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
import '../../support/app_route_table.dart';

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

const _knownUser = SafeUser(
  id: 'known',
  name: 'Known',
  role: 'USER',
  status: 'ACTIVE',
);

/// A phone that holds an account: its token and the account read last.
class _KnownAccountRepository extends AuthRepository {
  _KnownAccountRepository(super.apiClient, super.authStorage);

  final Completer<SafeUser> answer = Completer<SafeUser>();

  @override
  SafeUser? readCachedUser() => _knownUser;

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  Future<SafeUser> me() => answer.future;
}

/// Stands for AarastPushLifecycleBridge and AarastAuthFlowRedirector: above
/// the navigator, it sends the app somewhere once the account is known.
class _ElsewhereFirst extends StatefulWidget {
  const _ElsewhereFirst({
    required this.router,
    required this.to,
    required this.child,
  });

  final GoRouter router;
  final String to;
  final Widget child;

  @override
  State<_ElsewhereFirst> createState() => _ElsewhereFirstState();
}

class _ElsewhereFirstState extends State<_ElsewhereFirst> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>(
      (auth) => auth.status,
    );
    if (status != AuthStatus.checking && !_sent) {
      _sent = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.router.go(widget.to),
      );
    }
    return widget.child;
  }
}

Future<Widget> _opening({
  required bool celebratedBefore,
  AuthRepository Function(ApiClient, AuthStorage)? repository,
  void Function(DevicePreferences, AuthController)? capture,
  String? elsewhere,
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
        path: appRoute('/welcome'),
        builder: (context, state) => const Scaffold(body: Text('welcome')),
      ),
      GoRoute(
        path: appRoute('/home'),
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/elsewhere',
        builder: (context, state) => const Scaffold(body: Text('elsewhere')),
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
    child: MaterialApp.router(
      routerConfig: router,
      builder: elsewhere == null
          ? null
          : (context, child) =>
                _ElsewhereFirst(router: router, to: elsewhere, child: child!),
    ),
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

  testWidgets('an account the phone already holds is not a first open, '
      'even on the first run of an update that never marked one', (
    tester,
  ) async {
    // D123: a known account opens at once. The update adds the «seen» mark,
    // so without this every existing user got the 900ms welcome once.
    late DevicePreferences device;
    late _KnownAccountRepository known;
    await tester.pumpWidget(
      await _opening(
        celebratedBefore: false,
        repository: (api, storage) =>
            known = _KnownAccountRepository(api, storage),
        capture: (preferences, _) => device = preferences,
      ),
    );

    expect(find.byType(JourneyCelebrationSky), findsNothing);
    await tester.pump();
    await tester.pump();
    expect(find.text('home'), findsOneWidget);
    expect(device.openingCelebrated, isTrue, reason: 'never a first open now');
    known.answer.complete(_knownUser);
    await tester.pumpAndSettle();
  });

  testWidgets('a later open never overrides a place the app chose first', (
    tester,
  ) async {
    // A notification tapped cold, or a sign-out sending to «تسجيل الدخول»:
    // the opening goes on only from itself, never over another choice.
    await tester.pumpWidget(
      await _opening(celebratedBefore: true, elsewhere: '/elsewhere'),
    );
    await tester.pumpAndSettle();
    expect(find.text('elsewhere'), findsOneWidget);
    expect(find.text('welcome'), findsNothing);
  });
}
