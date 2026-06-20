import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/screens/generated_dashboard_preview_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/guest_onboarding_flow_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/persona_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/provider_path_pending_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GuestOnboardingFlowScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('does not continue from choose path before a real selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: GuestOnboardingFlowScreen()),
      );
      await tester.pumpAndSettle();

      await _tapPrimaryAction(tester);

      expect(find.byKey(const Key('guest-path-wedding-user')), findsOneWidget);
      expect(find.byType(PersonaScreen), findsNothing);

      await _tapPrimaryAction(tester);

      expect(find.byKey(const Key('guest-path-wedding-user')), findsOneWidget);
      expect(find.byType(PersonaScreen), findsNothing);
    });

    testWidgets(
      'provider path stays inside a safe pending screen after continue',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: GuestOnboardingFlowScreen()),
        );
        await tester.pumpAndSettle();

        await _tapPrimaryAction(tester);
        await _tapVisible(tester, const Key('guest-path-provider'));

        expect(find.byKey(const Key('guest-path-provider')), findsOneWidget);
        expect(find.byType(ProviderPathPendingScreen), findsNothing);

        await _tapPrimaryAction(tester);

        expect(find.byType(ProviderPathPendingScreen), findsOneWidget);
        expect(
          find.byKey(const Key('provider-dashboard-screen')),
          findsNothing,
        );
      },
    );

    testWidgets('wedding user path reaches generated preview internally', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: GuestOnboardingFlowScreen()),
      );
      await tester.pumpAndSettle();

      await _advanceToPreview(tester);

      expect(find.byType(GeneratedDashboardPreviewScreen), findsOneWidget);
    });

    testWidgets('onboarding can create a local guest plan without login', (
      tester,
    ) async {
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final guestStorage = GuestOnboardingStorage(preferences);
      final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
      final weddingPlansProvider = WeddingPlansProvider(
        WeddingPlansApi(apiClient),
      );
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const GuestOnboardingFlowScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('dashboard-opened')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            Provider<GuestOnboardingStorage>.value(value: guestStorage),
            ChangeNotifierProvider<WeddingPlansProvider>.value(
              value: weddingPlansProvider,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await _advanceToPreview(tester, personaKey: 'guest-persona-helper');
      await _tapPrimaryAction(tester);

      final savedDraft = await guestStorage.loadDraft();
      expect(find.text('dashboard-opened'), findsOneWidget);
      expect(savedDraft?.guestPlanId, startsWith('guest-plan-'));
      expect(savedDraft?.isGuestPlan, isTrue);
      expect(savedDraft?.needsSync, isTrue);
      expect(savedDraft?.persona, GuestPersona.helper);
    });
  });
}

Future<void> _advanceToPreview(
  WidgetTester tester, {
  String personaKey = 'guest-persona-groom',
}) async {
  await _tapPrimaryAction(tester);
  await _tapVisible(tester, const Key('guest-path-wedding-user'));
  await _tapPrimaryAction(tester);
  await _tapVisible(tester, Key(personaKey));
  await _tapPrimaryAction(tester);

  final governorateField = find.byType(TextField).at(0);
  final cityField = find.byType(TextField).at(1);
  await tester.ensureVisible(governorateField);
  await tester.pumpAndSettle();
  await tester.enterText(governorateField, 'Sanaa');
  await tester.ensureVisible(cityField);
  await tester.pumpAndSettle();
  await tester.enterText(cityField, 'Sanaa');

  await _tapPrimaryAction(tester);
  await _tapVisible(tester, const Key('guest-date-unknown'));
  await _tapPrimaryAction(tester);
  await _tapVisible(tester, const Key('guest-priority-0'));
  await _tapPrimaryAction(tester);
  await _tapVisible(tester, const Key('guest-budget-skip'));
  await _tapPrimaryAction(tester);
  await _tapVisible(tester, const Key('guest-category-0'));
  await _tapPrimaryAction(tester);
}

Future<void> _tapPrimaryAction(WidgetTester tester) {
  return _tapVisible(tester, const Key('guest-onboarding-primary-action'));
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
