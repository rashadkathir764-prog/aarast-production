import 'package:aarast_mobile/core/storage/auth_storage.dart';
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

  testWidgets('opens an available deep-linked plan before rendering content', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final plan2 = accountContext(
      role: AccountContextRole.contributor,
      planId: 'plan-2',
    );
    final harness = await _Harness.create([plan1, plan2]);
    await harness.controller.refresh(activeWeddingPlanId: plan1.weddingPlanId);
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

    expect(find.text('plan-2-content'), findsOneWidget);
    expect(harness.controller.selectedContext, plan2);
    expect(harness.setActiveCalls, ['plan-2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens archived history read-only without changing active plan', (
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
    await harness.controller.refresh(activeWeddingPlanId: plan1.weddingPlanId);
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

    expect(find.text('archived-content'), findsOneWidget);
    expect(harness.controller.selectedContext, archived);
    expect(harness.setActiveCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides content after a context is revoked and lists fallback', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final plan2 = accountContext(
      role: AccountContextRole.contributor,
      planId: 'plan-2',
    );
    final harness = await _Harness.create([plan1, plan2]);
    await harness.controller.refresh(activeWeddingPlanId: plan1.weddingPlanId);
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
    await harness.controller.refresh(activeWeddingPlanId: plan1.weddingPlanId);
    await tester.pumpAndSettle();

    expect(find.text('private-plan-2'), findsNothing);
    expect(
      find.byKey(const ValueKey('wedding-plan-context-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('plan-2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing context is truthful, RTL, and safe at 320 pixels', (
    tester,
  ) async {
    final plan1 = accountContext(role: AccountContextRole.owner);
    final harness = await _Harness.create([plan1]);
    await harness.controller.refresh(activeWeddingPlanId: plan1.weddingPlanId);
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

    final gate = find.byKey(
      const ValueKey('wedding-plan-context-unavailable'),
    );
    expect(gate, findsOneWidget);
    expect(find.text('private-missing'), findsNothing);
    expect(find.textContaining('missing-private-id'), findsNothing);
    expect(
      Directionality.of(tester.element(gate)),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

class _Harness {
  _Harness(this.gateway, this.controller, this.setActiveCalls);

  final _MutableGateway gateway;
  final AccountContextController controller;
  final List<String> setActiveCalls;

  static Future<_Harness> create(List<AccountContext> contexts) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final gateway = _MutableGateway(contexts);
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
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );
  }
}

class _MutableGateway implements AccountContextsGateway {
  _MutableGateway(this.contexts);

  List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.firstWhere(
      (context) => context.contextKey == contextKey,
    );
  }
}
