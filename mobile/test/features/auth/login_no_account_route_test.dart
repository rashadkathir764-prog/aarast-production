import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D75: «ما عندك حساب؟ ابدأ من هنا» never loses what the person came for: a
// provider page goes to the provider's own sign-up and back, and a plan on
// this phone is saved with a number instead of starting over.

Future<void> _pump(
  WidgetTester tester, {
  required String location,
  bool keptPlan = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = GuestOnboardingStorage(preferences);
  if (keptPlan) {
    await storage.saveDraft(
      GuestOnboardingDraft.quickLocalPlanSetup(
        planName: 'عرس محمد',
        persona: GuestPersona.groom,
        location: WeddingLocationDraft.fromLegacyFields(
          governorate: 'صنعاء',
          city: 'صنعاء',
        ),
        weddingDate: null,
        currency: 'YER',
        startingItemNames: const ['الذهب والشبكة'],
      ).copyWith(
        guestPlanId: 'local-guest-1',
        createdAt: DateTime(2026, 11, 2),
        isGuestPlan: true,
        needsSync: true,
      ),
    );
  }
  final authStorage = AuthStorage(preferences);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (c, s) => Text(
          'register:${s.uri.queryParameters['type']}:'
          '${s.uri.queryParameters['resume']}',
        ),
      ),
      GoRoute(path: '/welcome', builder: (c, s) => const Text('welcome')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GuestOnboardingStorage>.value(value: storage),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(
            AuthRepository(
              ApiClient(tokenProvider: () async => null),
              authStorage,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('login-register-action')),
  );
  await tester.tap(find.byKey(const ValueKey('login-register-action')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('from a provider page it opens the provider sign-up', (
    tester,
  ) async {
    await _pump(
      tester,
      location: '/login?resume=/provider/apply',
      keptPlan: true,
    );
    expect(find.text('register:provider:/provider/apply'), findsOneWidget);
  });

  testWidgets('with a plan on the phone it saves it with a number', (
    tester,
  ) async {
    await _pump(tester, location: '/login', keptPlan: true);
    expect(find.text('register:null:null'), findsOneWidget);
  });

  testWidgets('with nothing on the phone it opens the door', (tester) async {
    await _pump(tester, location: '/login');
    expect(find.text('welcome'), findsOneWidget);
  });
}
