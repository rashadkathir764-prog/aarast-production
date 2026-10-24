// The plan's «+» → «تسجيل دفعة» / «إضافة موعد دفع» (D33): which agreement
// the payment or the date goes on, then today's c07 payment form or date
// sheet.

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/widgets/money_cost_action_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('the picker shows only agreements that can take a payment', (
    tester,
  ) async {
    MoneyCostActionSelection? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: TextButton(
                onPressed: () async {
                  selection = await showMoneyCostActionPicker(
                    context,
                    intent: MoneyCostActionIntent.payment,
                    costs: const [_payableCost, _paidCost, _cancelledCost],
                    currency: 'YER',
                  );
                },
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(find.byType(JourneySheetBody), findsOneWidget);
    expect(find.text('الدفعة على أي اتفاق؟'), findsOneWidget);
    expect(find.text(_payableCost.title), findsOneWidget);
    expect(find.textContaining('باقي 750'), findsOneWidget);
    expect(find.text(_paidCost.title), findsNothing);
    expect(find.text(_cancelledCost.title), findsNothing);

    await tester.tap(find.text(_payableCost.title));
    await tester.pumpAndSettle();
    expect(selection?.cost?.id, _payableCost.id);
    expect(selection?.createCost, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden amounts stay hidden in the picker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMoneyCostActionPicker(
                context,
                intent: MoneyCostActionIntent.payment,
                costs: const [_payableCost],
                currency: 'YER',
                hideAmounts: true,
              ),
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(find.text('باقي عليه مبلغ'), findsOneWidget);
    expect(find.textContaining('750'), findsNothing);
  });

  testWidgets(
    'with no open agreement it explains why and offers a real next step',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.reset);
      MoneyCostActionSelection? selection;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selection = await showMoneyCostActionPicker(
                      context,
                      intent: MoneyCostActionIntent.schedule,
                      costs: const [_paidCost],
                      currency: 'YER',
                    );
                  },
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
      expect(find.text('موعد الدفع لأي اتفاق؟'), findsOneWidget);
      expect(find.text('سجّل اتفاق أول'), findsOneWidget);
      expect(find.textContaining('موعد الدفع ينربط'), findsOneWidget);
      await tester.tap(find.text('إضافة اتفاق'));
      await tester.pumpAndSettle();
      expect(selection?.createCost, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  group('openMoneyCostAction', () {
    testWidgets(
      'loads the money, then opens the payment form on the agreement',
      (tester) async {
        final finance = _ActionFinance(costs: const [_payableCost, _paidCost]);
        final result = await _run(
          tester,
          finance,
          MoneyCostActionIntent.payment,
          pick: _payableCost.title,
        );

        expect(finance.loads, 1, reason: 'loaded before asking');
        expect(
          find.text(
            'route:${AppRouter.moneyPaymentCreate('plan-1', _payableCost.id)}',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('save'));
        await tester.pumpAndSettle();
        expect(await result, isTrue);
        expect(finance.loads, 2, reason: 'reloaded after the payment');
      },
    );

    testWidgets('with no open agreement it opens the new agreement form', (
      tester,
    ) async {
      final finance = _ActionFinance(costs: const [_cancelledCost]);
      final result = await _run(
        tester,
        finance,
        MoneyCostActionIntent.payment,
        pick: 'إضافة اتفاق',
      );

      expect(
        find.text('route:${AppRouter.moneyCostCreate('plan-1')}'),
        findsOneWidget,
      );
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(finance.loads, 1, reason: 'nothing changed, nothing reloaded');
    });

    testWidgets('a payment date opens the c07 date sheet on the agreement', (
      tester,
    ) async {
      final finance = _ActionFinance(costs: const [_payableCost]);
      await _run(
        tester,
        finance,
        MoneyCostActionIntent.schedule,
        pick: _payableCost.title,
      );

      expect(find.text('موعد دفع جديد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Opens [intent] from a page with a router, picks [pick] in the sheet and
/// returns the pending result.
Future<Future<bool>> _run(
  WidgetTester tester,
  FinanceProvider finance,
  MoneyCostActionIntent intent, {
  required String pick,
}) async {
  late Future<bool> result;
  Widget stub(GoRouterState state) => Scaffold(
    body: Builder(
      builder: (context) => Column(
        children: [
          Text('route:${state.uri}'),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('save'),
          ),
          TextButton(onPressed: () => context.pop(), child: const Text('back')),
        ],
      ),
    ),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => result = openMoneyCostAction(
              context,
              planId: 'plan-1',
              intent: intent,
            ),
            child: const Text('فتح'),
          ),
        ),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/create',
        builder: (context, state) => stub(state),
      ),
      GoRoute(
        path: '/wedding-plans/:id/money/costs/:costId/payments/create',
        builder: (context, state) => stub(state),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>.value(
      value: finance,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('فتح'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(pick));
  await tester.pumpAndSettle();
  return result;
}

/// Money not loaded yet: the first load fills it.
class _ActionFinance extends FinanceProvider {
  _ActionFinance({required this.costs})
    : super(FinanceApi(ApiClient(tokenProvider: () async => null)));

  @override
  final List<WeddingCost> costs;
  int loads = 0;

  @override
  String? get loadedPlanId => loads == 0 ? null : 'plan-1';

  @override
  bool get hasLoadedMoney => loads > 0;

  @override
  bool get canManageMoney => true;

  @override
  MoneySummary get summary => MoneySummary.empty('plan-1');

  @override
  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {
    loads += 1;
  }
}

const _payableCost = WeddingCost(
  id: 'cost-open',
  weddingPlanId: 'plan-1',
  budgetCategoryId: 'category-1',
  title: 'قاعة الحفل',
  totalAmount: '1000000',
  paidAmount: '250000',
  remainingAmount: '750000',
  status: 'PARTIALLY_PAID',
);

const _paidCost = WeddingCost(
  id: 'cost-paid',
  weddingPlanId: 'plan-1',
  budgetCategoryId: 'category-1',
  title: 'اتفاق خالص',
  totalAmount: '100',
  paidAmount: '100',
  remainingAmount: '0',
  status: 'PAID',
);

const _cancelledCost = WeddingCost(
  id: 'cost-cancelled',
  weddingPlanId: 'plan-1',
  budgetCategoryId: 'category-1',
  title: 'اتفاق ملغي',
  totalAmount: '100',
  paidAmount: '0',
  remainingAmount: '100',
  status: 'CANCELLED',
);
