import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/active_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/my_wedding_plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

void main() {
  testWidgets('MyWeddingPlansScreen is RTL and overflow-free at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);

    final auth = await _authController();
    final apiClient = ApiClient(tokenProvider: () async => null);
    final plans = _EmptyWeddingPlansProvider(apiClient);
    final accountContexts = await _accountContexts(const []);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MyWeddingPlansScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MyWeddingPlansScreen), findsOneWidget);
    // w11 (D28): plans you help in are listed with yours, so the separate
    // shared-plans link and the empty-state card are gone.
    expect(find.text('خططك'), findsOneWidget);
    expect(find.text('خطة جديدة'), findsOneWidget);
    expect(find.textContaining('تقدر تفتح أكثر من خطة'), findsOneWidget);
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError
          ? '${exception.toStringDeep()}\n${_overflowingFlexes(tester)}'
          : exception?.toString(),
    );
  });

  testWidgets('the highlighted plan follows selectedContext only', (
    tester,
  ) async {
    final newest = _plan('newest', 'الخطة الأحدث');
    final selected = _plan('selected', 'الخطة الحالية');
    final apiClient = ApiClient(tokenProvider: () async => null);
    final plans = _PlansWithActiveProvider(apiClient, [
      newest,
      selected,
    ], newest);
    final accountContexts = await _accountContexts([
      accountContext(role: AccountContextRole.owner, planId: selected.id),
    ], selectedPlanId: selected.id);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MyWeddingPlansScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-switcher-selected')),
        matching: find.text('مفتوحة'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-switcher-newest')),
        matching: find.text('مفتوحة'),
      ),
      findsNothing,
    );
  });

  testWidgets('w11 lists plans you help in, and archived ones stay closed', (
    tester,
  ) async {
    final mine = _plan('mine', 'عرس محمد');
    final archived = _plan('old', 'عرس عادل', status: 'ARCHIVED');
    final apiClient = ApiClient(tokenProvider: () async => null);
    final plans = _PlansWithActiveProvider(apiClient, [mine, archived], mine);
    final accountContexts = await _accountContexts([
      accountContext(role: AccountContextRole.owner, planId: mine.id),
      accountContext(
        role: AccountContextRole.contributor,
        planId: 'helped',
        displayName: 'عرس صالح',
      ),
    ], selectedPlanId: mine.id);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MyWeddingPlansScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('عرس صالح'), findsOneWidget);
    expect(find.text('مشارك'), findsOneWidget);
    expect(find.text('مؤرشفة'), findsOneWidget);
    expect(find.text('في الذكريات · 2026'), findsOneWidget);

    await tester.tap(find.text('عرس عادل'));
    await tester.pumpAndSettle();
    expect(accountContexts.selectedContext?.weddingPlanId, mine.id);
  });

  testWidgets('a plan helped in opens on the participant tabs (D34)', (
    tester,
  ) async {
    final mine = _plan('mine', 'عرس محمد');
    final apiClient = ApiClient(tokenProvider: () async => null);
    final plans = _PlansWithActiveProvider(apiClient, [mine], mine);
    final accountContexts = await _accountContexts([
      accountContext(role: AccountContextRole.owner, planId: mine.id),
      accountContext(
        role: AccountContextRole.contributor,
        planId: 'helped',
        displayName: 'عرس صالح',
      ),
    ], selectedPlanId: mine.id);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MyWeddingPlansScreen()),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(key: Key('participant-home')),
        ),
        GoRoute(
          path: '/wedding-plans/:id/plan-center',
          builder: (_, _) => const Scaffold(key: Key('plan-details')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
          ChangeNotifierProvider<AccountContextController>.value(
            value: accountContexts,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('عرس صالح'));
    await tester.pumpAndSettle();

    expect(
      accountContexts.selectedContext?.contextKey,
      'plan:helped:contributor',
    );
    expect(find.byKey(const Key('participant-home')), findsOneWidget);
    expect(find.byKey(const Key('plan-details')), findsNothing);
  });
}

WeddingPlan _plan(String id, String title, {String status = 'PLANNING'}) {
  final now = DateTime(2026, 7, 11);
  return WeddingPlan(
    id: id,
    ownerUserId: 'user-1',
    title: title,
    city: 'صنعاء',
    currency: 'YER',
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

String _overflowingFlexes(WidgetTester tester) {
  final details = <String>[];
  for (final element in tester.allElements) {
    final render = element.renderObject;
    if (render is! RenderFlex || !render.hasSize) continue;
    var child = render.firstChild;
    var overflow = false;
    final childBounds = <String>[];
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      final bounds = data.offset & child.size;
      overflow =
          overflow ||
          bounds.left < -0.5 ||
          bounds.top < -0.5 ||
          bounds.right > render.size.width + 0.5 ||
          bounds.bottom > render.size.height + 0.5;
      childBounds.add('${child.runtimeType}:${child.size}@${data.offset}');
      child = render.childAfter(child);
    }
    if (!overflow) continue;

    final ancestors = <String>[];
    Element? cursor = element;
    for (var depth = 0; cursor != null && depth < 6; depth += 1) {
      final Element current = cursor!;
      ancestors.add(current.widget.runtimeType.toString());
      current.visitAncestorElements((ancestor) {
        cursor = ancestor;
        return false;
      });
    }
    details.add(
      'RenderFlex ${render.direction} size=${render.size} '
      'widgets=${ancestors.join(' <- ')} children=${childBounds.join(', ')}',
    );
  }
  return details.join('\n');
}

Future<AuthController> _authController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final client = ApiClient(tokenProvider: storage.readAccessToken);
  return AuthController(AuthRepository(client, storage));
}

Future<AccountContextController> _accountContexts(
  List<AccountContext> contexts, {
  String? selectedPlanId,
}) async {
  final preferences = await SharedPreferences.getInstance();
  final controller = AccountContextController(
    contextsApi: _StaticAccountContextsGateway(contexts),
    authStorage: AuthStorage(preferences),
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh();
  if (selectedPlanId != null) {
    final target = contexts.firstWhere(
      (context) => context.weddingPlanId == selectedPlanId,
    );
    await controller.select(target.contextKey);
  }
  return controller;
}

class _StaticAccountContextsGateway implements AccountContextsGateway {
  const _StaticAccountContextsGateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.firstWhere((context) => context.contextKey == contextKey);
  }
}

class _EmptyWeddingPlansProvider extends WeddingPlansProvider {
  _EmptyWeddingPlansProvider(ApiClient apiClient)
    : super(WeddingPlansApi(apiClient));

  @override
  List<WeddingPlan> get plans => const [];

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadMyWeddingPlans() async {}

  @override
  Future<void> loadActiveWeddingPlan() async {}
}

class _PlansWithActiveProvider extends WeddingPlansProvider {
  _PlansWithActiveProvider(ApiClient apiClient, this._plans, WeddingPlan active)
    : _active = ActiveWeddingPlan.fromWeddingPlan(active),
      super(WeddingPlansApi(apiClient));

  final List<WeddingPlan> _plans;
  final ActiveWeddingPlan _active;

  @override
  List<WeddingPlan> get plans => _plans;

  @override
  ActiveWeddingPlan? get activePlan => _active;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadMyWeddingPlans() async {}

  @override
  Future<void> loadActiveWeddingPlan() async {}
}
