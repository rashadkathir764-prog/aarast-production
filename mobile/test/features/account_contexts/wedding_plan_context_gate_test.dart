import 'dart:async';

import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('blocks a different available plan without selecting it', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final plan2 = accountContext(
      role: AccountContextRole.contributor,
      planId: 'plan-2',
    );
    final harness = await _Harness.create([plan1, plan2]);
    await harness.controller.refresh();
    await harness.controller.select(plan1.contextKey);
    harness.setActiveCalls.clear();

    await tester.pumpWidget(
      harness.wrap(
        const WeddingPlanContextGate(
          weddingPlanId: 'plan-2',
          child: Text('plan-2-content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('plan-2-content'), findsNothing);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-mismatch')),
      findsOneWidget,
    );
    expect(harness.controller.selectedContext, plan1);
    expect(harness.setActiveCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks an archived route without opening read-only context', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final archived = accountContext(
      role: AccountContextRole.contributor,
      planId: 'plan-archived',
      lifecycle: 'ARCHIVED',
      accessMode: AccountContextAccessMode.readOnly,
      isAvailable: false,
      unavailableReason: 'PLAN_ARCHIVED',
    );
    final harness = await _Harness.create([plan1, archived]);
    await harness.controller.refresh();
    await harness.controller.select(plan1.contextKey);
    harness.setActiveCalls.clear();

    await tester.pumpWidget(
      harness.wrap(
        const WeddingPlanContextGate(
          weddingPlanId: 'plan-archived',
          child: Text('archived-content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('archived-content'), findsNothing);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-mismatch')),
      findsOneWidget,
    );
    expect(harness.controller.selectedContext, plan1);
    expect(harness.setActiveCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders only when route matches selectedContext', (
    tester,
  ) async {
    final plan = accountContext(role: AccountContextRole.owner);
    final harness = await _Harness.create([plan]);
    await harness.controller.refresh();
    await harness.controller.select(plan.contextKey);
    harness.setActiveCalls.clear();

    await tester.pumpWidget(
      harness.wrap(
        WeddingPlanContextGate(
          weddingPlanId: plan.weddingPlanId!,
          child: const Text('matching-plan-content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('matching-plan-content'), findsOneWidget);
    expect(harness.controller.selectedContext, plan);
    expect(harness.setActiveCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-plan contributor cannot render the owner dashboard route', (
    tester,
  ) async {
    final contributor = accountContext(role: AccountContextRole.contributor);
    final harness = await _Harness.create([contributor]);
    await harness.controller.refresh();
    await harness.controller.select(contributor.contextKey);

    await tester.pumpWidget(
      harness.wrap(
        WeddingPlanContextGate(
          weddingPlanId: contributor.weddingPlanId!,
          requiredAccess: WeddingPlanRouteAccess.ownerDashboard,
          child: const Text('owner-dashboard-content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('owner-dashboard-content'), findsNothing);
    expect(find.text('هذا القسم مو مفتوح لك'), findsOneWidget);
    expect(harness.controller.selectedContext, contributor);
    expect(tester.takeException(), isNull);
  });

  test('capability guard allows only permissions from selected context', () {
    final contributor = accountContext(role: AccountContextRole.contributor);

    expect(
      accountContextAllowsPlanAccess(
        contributor,
        WeddingPlanRouteAccess.viewPlan,
      ),
      isTrue,
    );
    expect(
      accountContextAllowsPlanAccess(
        contributor,
        WeddingPlanRouteAccess.manageTasks,
      ),
      isTrue,
    );
    expect(
      accountContextAllowsPlanAccess(
        contributor,
        WeddingPlanRouteAccess.viewMoney,
      ),
      isFalse,
    );
    expect(
      accountContextAllowsPlanAccess(
        contributor,
        WeddingPlanRouteAccess.manageProviders,
      ),
      isFalse,
    );
    expect(
      accountContextAllowsPlanAccess(
        contributor,
        WeddingPlanRouteAccess.inviteMembers,
      ),
      isFalse,
    );
  });

  testWidgets('hides content after revocation without choosing a fallback', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final plan2 = accountContext(
      role: AccountContextRole.contributor,
      planId: 'plan-2',
    );
    final harness = await _Harness.create([plan1, plan2]);
    await harness.controller.refresh();
    await harness.controller.select(plan2.contextKey);

    await tester.pumpWidget(
      harness.wrap(
        const WeddingPlanContextGate(
          weddingPlanId: 'plan-2',
          child: Text('private-plan-2'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('private-plan-2'), findsOneWidget);

    harness.gateway.contexts = [plan1];
    await harness.controller.refresh();
    await tester.pumpAndSettle();

    expect(find.text('private-plan-2'), findsNothing);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-mismatch')),
      findsOneWidget,
    );
    expect(find.textContaining('plan-2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-135: a participant's contexts are read again each time the app
  // comes back to the front and on each pull to refresh. The gate drew its
  // spinner in place of the page for that long, so the page under it was
  // torn down: a task being written was gone when the person came back
  // from copying a number out of WhatsApp.
  // D112 (Q-17): the page stays in front on the right last confirmed while
  // the server is asked; it closes only on the server's refusal (the test
  // after this one).
  testWidgets('a page already open stays in front, with what was typed in '
      'it, while the contexts are read again', (tester) async {
    final plan = accountContext(role: AccountContextRole.contributor);
    final harness = await _Harness.create([plan]);
    await harness.controller.refresh();
    await harness.controller.select(plan.contextKey);

    await tester.pumpWidget(
      harness.wrap(
        WeddingPlanContextGate(
          weddingPlanId: plan.weddingPlanId!,
          child: const Material(child: TextField()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'رتّب الغداء');

    harness.gateway.hold = Completer<void>();
    final refresh = harness.controller.refresh();
    await tester.pump();
    expect(harness.controller.isRefreshing, isTrue);
    expect(find.text('رتّب الغداء'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-loading')),
      findsNothing,
    );

    harness.gateway.hold!.complete();
    await refresh;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The same page, as it was left.
    expect(find.text('رتّب الغداء'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-loading')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a right withdrawn while the page was held removes the page', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final plan2 = accountContext(
      role: AccountContextRole.contributor,
      planId: 'plan-2',
    );
    final harness = await _Harness.create([plan1, plan2]);
    await harness.controller.refresh();
    await harness.controller.select(plan2.contextKey);
    await tester.pumpWidget(
      harness.wrap(
        const WeddingPlanContextGate(
          weddingPlanId: 'plan-2',
          child: Material(child: TextField()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'سر الخطة');

    harness.gateway.contexts = [plan1];
    harness.gateway.hold = Completer<void>();
    final refresh = harness.controller.refresh();
    await tester.pump();
    harness.gateway.hold!.complete();
    await refresh;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('سر الخطة', skipOffstage: false), findsNothing);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-mismatch')),
      findsOneWidget,
    );
  });

  testWidgets('nothing loaded yet: the gate waits, it does not open', (
    tester,
  ) async {
    final plan = accountContext(role: AccountContextRole.contributor);
    final harness = await _Harness.create([plan]);
    harness.gateway.hold = Completer<void>();
    final refresh = harness.controller.refresh();

    await tester.pumpWidget(
      harness.wrap(
        WeddingPlanContextGate(
          weddingPlanId: plan.weddingPlanId!,
          child: const Text('private-content'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('private-content'), findsNothing);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-loading')),
      findsOneWidget,
    );
    harness.gateway.hold!.complete();
    await refresh;
  });

  testWidgets('missing context is truthful, RTL, and safe at 320 pixels', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final harness = await _Harness.create([plan1]);
    await harness.controller.refresh();
    await harness.controller.select(plan1.contextKey);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness.wrap(
        const WeddingPlanContextGate(
          weddingPlanId: 'missing-private-id',
          child: Text('private-missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gate = find.byKey(const ValueKey('wedding-plan-context-mismatch'));
    expect(gate, findsOneWidget);
    expect(find.text('private-missing'), findsNothing);
    expect(find.textContaining('missing-private-id'), findsNothing);
    expect(Directionality.of(tester.element(gate)), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'context load failure shows a clear error instead of a permanent spinner',
    (tester) async {
      final harness = await _Harness.create(
        const [],
        listError: StateError('contexts unavailable'),
      );

      await harness.controller.refresh();
      expect(harness.controller.errorMessage, isNotNull);
      expect(harness.controller.isRefreshing, isFalse);

      await tester.pumpWidget(
        harness.wrap(
          const WeddingPlanContextGate(
            weddingPlanId: 'plan-unavailable',
            child: Text('private-content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('wedding-plan-context-mismatch')),
        findsOneWidget,
      );
      expect(find.text(harness.controller.errorMessage!), findsOneWidget);
      expect(find.byType(AarastScreenLoading), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('private-content'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  _Harness(this.gateway, this.controller, this.setActiveCalls);

  final _MutableGateway gateway;
  final AccountContextController controller;
  final List<String> setActiveCalls;

  static Future<_Harness> create(
    List<AccountContext> contexts, {
    Object? listError,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final gateway = _MutableGateway(contexts, listError: listError);
    final calls = <String>[];
    final controller = AccountContextController(
      contextsApi: gateway,
      authStorage: AuthStorage(preferences),
      setActiveWeddingPlan: (planId) async => calls.add(planId),
    );
    return _Harness(gateway, controller, calls);
  }

  Widget wrap(Widget child) {
    return ChangeNotifierProvider<AccountContextController>.value(
      value: controller,
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );
  }
}

class _MutableGateway implements AccountContextsGateway {
  _MutableGateway(this.contexts, {this.listError});

  List<AccountContext> contexts;
  final Object? listError;

  /// Holds the next answers until completed: a slow server.
  Completer<void>? hold;

  @override
  Future<List<AccountContext>> listContexts() async {
    await hold?.future;
    final error = listError;
    if (error != null) throw error;
    return contexts;
  }

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.firstWhere((context) => context.contextKey == contextKey);
  }
}
