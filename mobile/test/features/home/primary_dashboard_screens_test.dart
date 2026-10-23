import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'dart:async';

import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/home/screens/dashboard_entry_screen.dart';
import 'package:aarast_mobile/features/home/screens/local_guest_dashboard_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_management_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_management_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _planId = 'guest-plan-primary-test';
const _planTitle = 'خطة الزفاف الأساسية';

void main() {
  testWidgets('DashboardEntryScreen shows its checking state at 320px RTL', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await _pumpPhone(
      tester,
      harness.wrap(_app(home: const DashboardEntryScreen())),
    );

    expect(find.byType(DashboardEntryScreen), findsOneWidget);
    expect(find.byType(AarastScreenLoading), findsOneWidget);
    _expectRtl(tester, find.byType(DashboardEntryScreen));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardEntryScreen opens saved local content at 320px RTL', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.guestStorage.saveDraft(_guestPlan());
    await harness.auth.restoreSession();

    await _pumpPhone(
      tester,
      harness.wrap(_app(home: const DashboardEntryScreen())),
    );
    await _pumpState(tester);

    expect(find.byType(DashboardEntryScreen), findsOneWidget);
    expect(find.byType(LocalGuestDashboardScreen), findsOneWidget);
    expect(find.textContaining(_planTitle), findsWidgets);
    _expectRtl(tester, find.byType(LocalGuestDashboardScreen));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardEntryScreen sends an empty device to onboarding', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.auth.restoreSession();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardEntryScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const AarastScreenFrame(
            child: Center(child: Text('onboarding-opened')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await _pumpPhone(tester, harness.wrap(_routerApp(router)));
    await _pumpState(tester);

    expect(find.text('onboarding-opened'), findsOneWidget);
    _expectRtl(tester, find.text('onboarding-opened'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlanCenterScreen renders a real loading state at 320px RTL', (
    tester,
  ) async {
    final pending = Completer<GuestOnboardingDraft?>();
    final harness = await _Harness.create(
      storageBuilder: (preferences) =>
          _ControlledGuestStorage(preferences, () => pending.future),
    );
    addTearDown(harness.dispose);

    await _pumpPhone(
      tester,
      harness.wrap(_app(home: const PlanCenterScreen(weddingPlanId: _planId))),
    );
    await _pumpState(tester, frames: 2);

    expect(find.byType(PlanCenterScreen), findsOneWidget);
    expect(find.byType(AarastScreenLoading), findsOneWidget);
    _expectRtl(tester, find.byType(AarastScreenLoading));
    expect(tester.takeException(), isNull);

    pending.complete(null);
    await _pumpState(tester, frames: 2);
  });

  testWidgets('PlanCenterScreen renders its missing-plan state at 320px RTL', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await _pumpPhone(
      tester,
      harness.wrap(_app(home: const PlanCenterScreen(weddingPlanId: _planId))),
    );
    await _pumpState(tester);

    expect(find.byType(PlanCenterScreen), findsOneWidget);
    expect(find.byType(AarastErrorState), findsOneWidget);
    _expectRtl(tester, find.byType(AarastErrorState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlanCenterScreen renders saved plan content at 320px RTL', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.guestStorage.saveDraft(_guestPlan());

    await _pumpPhone(
      tester,
      harness.wrap(_app(home: const PlanCenterScreen(weddingPlanId: _planId))),
    );
    await _pumpState(tester);

    expect(find.byType(PlanCenterScreen), findsOneWidget);
    expect(find.byType(PlanManagementView), findsOneWidget);
    expect(find.text(_planTitle), findsWidgets);
    _expectRtl(tester, find.byType(PlanManagementView));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'WeddingPlanDashboardScreen renders a real loading state at 320px RTL',
    (tester) async {
      final pending = Completer<GuestOnboardingDraft?>();
      final harness = await _Harness.create(
        storageBuilder: (preferences) =>
            _ControlledGuestStorage(preferences, () => pending.future),
      );
      addTearDown(harness.dispose);

      await _pumpPhone(
        tester,
        harness.wrap(
          _app(home: const WeddingPlanDashboardScreen(weddingPlanId: _planId)),
        ),
      );
      await _pumpState(tester, frames: 2);

      expect(find.byType(WeddingPlanDashboardScreen), findsOneWidget);
      expect(find.byType(AarastDashboardSkeleton), findsOneWidget);
      _expectRtl(tester, find.byType(AarastDashboardSkeleton));
      expect(tester.takeException(), isNull);

      pending.complete(null);
      await _pumpState(tester, frames: 2);
    },
  );

  testWidgets('the first frame of a plan is the skeleton, never «no plan»', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);

    // Only the first frame: the plan has not been read yet.
    await tester.pumpWidget(
      harness.wrap(
        _app(home: const WeddingPlanDashboardScreen(weddingPlanId: _planId)),
      ),
    );

    expect(find.byKey(const ValueKey('aarast-home-skeleton')), findsOneWidget);
    expect(find.text('ما عندك خطة بعد'), findsNothing);
    expect(find.text('أنشئ خطتك'), findsNothing);
  });

  testWidgets('WeddingPlanDashboardScreen renders empty state at 320px RTL', (
    tester,
  ) async {
    final logSink = _CollectingLogSink();
    AppLogger.installGlobal(
      AppLogger(
        redactor: LogRedactor(installationSalt: 'groom-dashboard-test'),
        sinks: [logSink],
      ),
    );
    addTearDown(AppLogger.clearGlobal);
    final harness = await _Harness.create();
    addTearDown(harness.dispose);

    await _pumpPhone(
      tester,
      harness.wrap(
        _app(home: const WeddingPlanDashboardScreen(weddingPlanId: _planId)),
      ),
    );
    await _pumpState(tester);

    expect(find.byType(WeddingPlanDashboardScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('aarast-home-empty')), findsOneWidget);
    // One clear way forward (b15).
    expect(find.byType(JourneyButton), findsOneWidget);
    expect(find.text('أنشئ خطتك'), findsOneWidget);
    _expectRtl(tester, find.byKey(const ValueKey('aarast-home-empty')));
    expect(tester.takeException(), isNull);

    expect(
      logSink.events.where(
        (event) =>
            event.name == 'dashboard_built' &&
            event.category == AppLogCategory.groom,
      ),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      logSink.events.where(
        (event) =>
            event.name == 'dashboard_disposed' &&
            event.category == AppLogCategory.groom,
      ),
      hasLength(1),
    );
  });

  testWidgets(
    'WeddingPlanDashboardScreen renders saved dashboard content at 320px RTL',
    (tester) async {
      final harness = await _Harness.create();
      addTearDown(harness.dispose);
      await harness.guestStorage.saveDraft(_guestPlan());

      await _pumpPhone(
        tester,
        harness.wrap(
          _app(home: const WeddingPlanDashboardScreen(weddingPlanId: _planId)),
        ),
      );
      await _pumpState(tester);

      expect(find.byType(WeddingPlanDashboardScreen), findsOneWidget);
      expect(find.byType(AarastDashboardView), findsOneWidget);
      expect(find.textContaining(_planTitle), findsWidgets);
      _expectRtl(tester, find.byType(AarastDashboardView));
      expect(tester.takeException(), isNull);
    },
  );
}

class _CollectingLogSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) => events.add(event);
}

class _Harness {
  _Harness({
    required this.authStorage,
    required this.guestStorage,
    required this.auth,
    required this.weddingPlans,
    required this.dashboard,
  });

  final AuthStorage authStorage;
  final GuestOnboardingStorage guestStorage;
  final AuthController auth;
  final WeddingPlansProvider weddingPlans;
  final DashboardSummaryProvider dashboard;

  static Future<_Harness> create({
    GuestOnboardingStorage Function(SharedPreferences preferences)?
    storageBuilder,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final guestStorage =
        storageBuilder?.call(preferences) ??
        GuestOnboardingStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final weddingPlansApi = WeddingPlansApi(apiClient);

    return _Harness(
      authStorage: authStorage,
      guestStorage: guestStorage,
      auth: AuthController(
        AuthRepository(apiClient, authStorage),
        guestOnboardingStorage: guestStorage,
      ),
      weddingPlans: WeddingPlansProvider(weddingPlansApi),
      dashboard: DashboardSummaryProvider(weddingPlansApi: weddingPlansApi),
    );
  }

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<GuestOnboardingStorage>.value(value: guestStorage),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<WeddingPlansProvider>.value(value: weddingPlans),
        ChangeNotifierProvider<DashboardSummaryProvider>.value(
          value: dashboard,
        ),
      ],
      child: child,
    );
  }

  void dispose() {
    auth.dispose();
    weddingPlans.dispose();
    dashboard.dispose();
  }
}

class _ControlledGuestStorage extends GuestOnboardingStorage {
  _ControlledGuestStorage(super.preferences, this._load);

  final Future<GuestOnboardingDraft?> Function() _load;

  @override
  Future<GuestOnboardingDraft?> loadGuestPlan() => _load();
}

Widget _app({required Widget home}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: _phoneBuilder,
    home: home,
  );
}

Widget _routerApp(GoRouter router) {
  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: _phoneBuilder,
    routerConfig: router,
  );
}

Widget _phoneBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: const TextScaler.linear(1.3),
    ),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

Future<void> _pumpPhone(WidgetTester tester, Widget widget) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 720);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await _pumpState(tester);
}

Future<void> _pumpState(WidgetTester tester, {int frames = 6}) async {
  for (var index = 0; index < frames; index += 1) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void _expectRtl(WidgetTester tester, Finder finder) {
  expect(Directionality.of(tester.element(finder.first)), TextDirection.rtl);
}

GuestOnboardingDraft _guestPlan() {
  return GuestOnboardingDraft(
    guestPlanId: _planId,
    planName: _planTitle,
    createdAt: DateTime.utc(2026, 7, 10),
    isGuestPlan: true,
    needsSync: true,
    selectedPath: GuestOnboardingPath.weddingUser,
    persona: GuestPersona.groom,
    governorate: 'صنعاء',
    city: 'صنعاء',
    district: 'السبعين',
    neighborhood: 'حدة',
    street: null,
    addressNote: null,
    weddingDate: DateTime.utc(2027, 1, 20),
    weddingDateUnknown: false,
    priorities: const ['budget', 'tasks'],
    currency: 'YER',
    estimatedBudget: '1000000',
    selectedCategoryKeys: const ['hall', 'photo'],
  );
}
