import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/shell/screens/wedding_plan_shell.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold local nested route restores the persisted plan summary', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = GuestOnboardingStorage(preferences);
    final weddingDate = DateTime.now().add(const Duration(days: 20));
    const planId = 'local-guest-cold-shell';
    const planName = 'خطة اختبار الهاتف';
    await storage.saveDraft(
      const GuestOnboardingDraft.empty().copyWith(
        guestPlanId: planId,
        planName: planName,
        createdAt: DateTime(2026, 8, 9),
        isGuestPlan: true,
        needsSync: true,
        budgetSkipped: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.groom,
        city: 'صنعاء',
        weddingDate: weddingDate,
        currency: 'YER',
      ),
    );

    final router = GoRouter(
      initialLocation: AppRouter.guestList(planId),
      routes: [
        ShellRoute(
          builder: (context, state, child) => WeddingPlanShell(
            weddingPlanId: state.pathParameters['id'] ?? '',
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/wedding-plans/:id/guests',
              builder: (context, state) =>
                  const Scaffold(body: Text('cold-guests-route')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final accountContexts = AccountContextController(
      contextsApi: const _EmptyAccountContextsGateway(),
      authStorage: AuthStorage(preferences),
      setActiveWeddingPlan: (_) async {},
    );
    addTearDown(accountContexts.dispose);
    final dashboard = DashboardSummaryProvider(
      weddingPlansApi: WeddingPlansApi(
        ApiClient(tokenProvider: () async => null),
      ),
    );
    addTearDown(dashboard.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GuestOnboardingStorage>.value(value: storage),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboard,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The tabs name themselves (DECISIONS D10); the bridge still gives
    // them the plan's summary.
    expect(find.text('cold-guests-route'), findsOneWidget);
    expect(find.textContaining('الضيوف ·'), findsNothing);
    expect(dashboard.summary?.planId, planId);
    expect(dashboard.summary?.title, planName);
    expect(dashboard.summary?.accountBacked, isFalse);
    expect(dashboard.summary?.dataScope, 'LOCAL');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone-only plan\'s «الرئيسية» returns to its one home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = GuestOnboardingStorage(preferences);
    const planId = 'local-guest-home-tab';
    await storage.saveDraft(
      const GuestOnboardingDraft.empty().copyWith(
        guestPlanId: planId,
        planName: 'عرس محمد',
        createdAt: DateTime(2026, 8, 9),
        isGuestPlan: true,
        needsSync: true,
        budgetSkipped: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.groom,
        city: 'صنعاء',
        currency: 'YER',
      ),
    );
    final router = GoRouter(
      initialLocation: AppRouter.guestList(planId),
      routes: [
        GoRoute(
          path: AppRouter.home,
          builder: (context, state) => const Scaffold(body: Text('the-home')),
        ),
        ShellRoute(
          builder: (context, state, child) => WeddingPlanShell(
            weddingPlanId: state.pathParameters['id'] ?? '',
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/wedding-plans/:id/guests',
              builder: (context, state) =>
                  const Scaffold(body: Text('guests-tab')),
            ),
            GoRoute(
              path: '/wedding-plans/:id/dashboard',
              builder: (context, state) =>
                  const Scaffold(body: Text('second-home')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final accountContexts = AccountContextController(
      contextsApi: const _EmptyAccountContextsGateway(),
      authStorage: AuthStorage(preferences),
      setActiveWeddingPlan: (_) async {},
    );
    addTearDown(accountContexts.dispose);
    final dashboard = DashboardSummaryProvider(
      weddingPlansApi: WeddingPlansApi(
        ApiClient(tokenProvider: () async => null),
      ),
    );
    addTearDown(dashboard.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GuestOnboardingStorage>.value(value: storage),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboard,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AarastPlanNavigationBar),
        matching: find.byIcon(LucideIcons.home),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('the-home'), findsOneWidget);
    expect(find.text('second-home'), findsNothing);
  });
}

class _EmptyAccountContextsGateway implements AccountContextsGateway {
  const _EmptyAccountContextsGateway();

  @override
  Future<List<AccountContext>> listContexts() async => const [];

  @override
  Future<AccountContext> validateContext(String contextKey) {
    throw StateError('No authenticated account contexts in local guest mode.');
  }
}
