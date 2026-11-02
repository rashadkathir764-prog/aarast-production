import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/auth/screens/splash_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('first launch without token opens onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dependencies = await _authDependencies();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/welcome',
          builder: (context, state) =>
              const Scaffold(body: Text('guest-onboarding-opened')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('dashboard-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      _withAuthDependencies(
        dependencies,
        MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('guest-onboarding-opened'), findsOneWidget);
    expect(find.text('dashboard-opened'), findsNothing);
  });

  testWidgets('login route still opens the existing login screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final dependencies = await _authDependencies();
    final router = AppRouter.create();

    await tester.pumpWidget(
      _withAuthDependencies(
        dependencies,
        MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(AppRouter.login);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });

  testWidgets('/onboarding redirects to smart welcome gateway', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dependencies = await _authDependencies();
    final router = AppRouter.create();

    await tester.pumpWidget(
      _withAuthDependencies(
        dependencies,
        MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(AppRouter.onboarding);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRouter.welcome);
    expect(find.byType(SmartWelcomeScreen), findsOneWidget);
    // D75: the door that opens for anyone.
    expect(find.text('أهلًا فيك، من وين نبدأ؟'), findsOneWidget);
    expect(find.byKey(const ValueKey('door-plan')), findsOneWidget);
  });

  testWidgets('returning guest with local plan opens dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final dependencies = await _authDependencies();
    await dependencies.guestStorage.saveDraft(
      GuestOnboardingDraft(
        guestPlanId: 'guest-plan-startup',
        planName: 'خطة زفاف صنعاء',
        createdAt: DateTime.utc(2026, 6, 19),
        isGuestPlan: true,
        needsSync: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.groom,
        governorate: 'صنعاء',
        city: 'صنعاء',
        district: null,
        neighborhood: null,
        street: null,
        addressNote: null,
        weddingDate: DateTime.utc(2026, 12, 19),
        weddingDateUnknown: false,
        priorities: const ['budget'],
        currency: 'YER',
        estimatedBudget: '1000000',
        selectedCategoryKeys: const ['hall'],
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) =>
              const Scaffold(body: Text('guest-onboarding-opened')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('dashboard-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      _withAuthDependencies(
        dependencies,
        MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('dashboard-opened'), findsOneWidget);
    expect(find.text('guest-onboarding-opened'), findsNothing);
  });
}

Future<_AuthDependencies> _authDependencies() async {
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final guestStorage = GuestOnboardingStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final repository = AuthRepository(apiClient, authStorage);
  final controller = AuthController(repository)..restoreSession();
  return _AuthDependencies(
    authStorage: authStorage,
    guestStorage: guestStorage,
    apiClient: apiClient,
    repository: repository,
    controller: controller,
  );
}

Widget _withAuthDependencies(_AuthDependencies dependencies, Widget child) {
  return MultiProvider(
    providers: [
      Provider<AuthStorage>.value(value: dependencies.authStorage),
      Provider<GuestOnboardingStorage>.value(value: dependencies.guestStorage),
      Provider<ApiClient>.value(value: dependencies.apiClient),
      Provider<AuthRepository>.value(value: dependencies.repository),
      ChangeNotifierProvider<AuthController>.value(
        value: dependencies.controller,
      ),
    ],
    child: child,
  );
}

class _AuthDependencies {
  const _AuthDependencies({
    required this.authStorage,
    required this.guestStorage,
    required this.apiClient,
    required this.repository,
    required this.controller,
  });

  final AuthStorage authStorage;
  final GuestOnboardingStorage guestStorage;
  final ApiClient apiClient;
  final AuthRepository repository;
  final AuthController controller;
}
