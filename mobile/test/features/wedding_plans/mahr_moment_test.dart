import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/mahr_moment_ledger.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/mahr_moment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// y08: the groom handed the whole mahr over.

Future<List<String>> _pump(WidgetTester tester, FinanceProvider finance) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 860);
  addTearDown(tester.view.reset);
  final opened = <String>[];
  final router = GoRouter(
    initialLocation: '/moment',
    routes: [
      GoRoute(
        path: '/moment',
        builder: (_, _) => const MahrMomentScreen(weddingPlanId: 'plan-1'),
      ),
    ],
    errorBuilder: (context, state) {
      opened.add(state.uri.toString());
      return const SizedBox.shrink();
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>.value(
      value: finance,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  test(
    'the first look remembers the state; finishing it celebrates once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ledger = MahrMomentLedger(await SharedPreferences.getInstance());

      // A phone that first sees a mahr already complete does not replay it.
      expect(await ledger.becameComplete('plan-old', complete: true), isFalse);
      expect(await ledger.becameComplete('plan-old', complete: true), isFalse);

      expect(await ledger.becameComplete('plan-1', complete: false), isFalse);
      expect(await ledger.becameComplete('plan-1', complete: true), isTrue);
      expect(await ledger.becameComplete('plan-1', complete: true), isFalse);
    },
  );

  testWidgets('says the whole mahr arrived, payment by payment', (
    tester,
  ) async {
    final finance = FinanceProvider(_Finance());
    await finance.loadMoney('plan-1');

    final opened = await _pump(tester, finance);

    expect(find.text('الاتفاق مع أهل العروسة'), findsOneWidget);
    expect(find.text('سلّمت المهر كامل'), findsOneWidget);
    expect(
      find.text(
        'ثلاثة مليون ريال، وصلت كلها.\nهذا الجزء من عرسك خلص، ألف مبروك.',
      ),
      findsOneWidget,
    );
    expect(find.text('يوم الخطوبة'), findsOneWidget);
    expect(find.text('2,000,000'), findsOneWidget);
    expect(find.text('الباقي · يوم العقد'), findsOneWidget);
    expect(find.text('1,000,000'), findsOneWidget);
    // A reversed payment is not part of what was handed over.
    expect(find.text('500,000'), findsNothing);
    expect(
      find.text('نخفي بطاقة المهر من الرئيسية، وتلقاها في المال.'),
      findsOneWidget,
    );

    await tester.tap(find.text('تمام'));
    await tester.pumpAndSettle();
    // Opened straight from the home's push, «تمام» goes back to the home.
    expect(opened, ['/wedding-plans/plan-1/dashboard']);
  });

  testWidgets('«أخفِ المبالغ» hides the mahr in figures and in words', (
    tester,
  ) async {
    final finance = FinanceProvider(_Finance());
    await finance.loadMoney('plan-1');
    finance.toggleAmountsVisibility();

    await _pump(tester, finance);

    expect(find.text('2,000,000'), findsNothing);
    expect(find.text('••••'), findsNWidgets(2));
    expect(find.textContaining('مليون'), findsNothing);
    expect(find.text('هذا الجزء من عرسك خلص، ألف مبروك.'), findsOneWidget);
  });
}

class _Finance extends FinanceApi {
  _Finance() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<MoneySummary> getMoneySummary(String planId) async => MoneySummary(
    planId: 'plan-1',
    categories: const [
      MoneyCategorySummary(categoryId: 'mahr', name: 'المهر', isMahr: true),
    ],
    mahr: MoneyMahrSummary.fromJson(const {
      'side': 'PAYS',
      'total': '3000000',
      'settled': '3000000',
      'remaining': '0',
      'complete': true,
    }),
  );

  @override
  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
    String? payer,
  }) async => const FinancePage(
    items: [
      WeddingCost(
        id: 'cost-mahr',
        weddingPlanId: 'plan-1',
        budgetCategoryId: 'mahr',
        title: 'المهر',
        totalAmount: '3000000',
        paidAmount: '3000000',
        remainingAmount: '0',
        status: 'PAID',
      ),
    ],
    page: 1,
    pageSize: 30,
    total: 1,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => const FinancePage(
    items: [],
    page: 1,
    pageSize: 30,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      const [];

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async => [
    CostPayment(
      id: 'p2',
      costId: 'cost-mahr',
      amount: '1000000',
      paidAt: DateTime(2026, 11, 15),
      note: 'الباقي · يوم العقد',
    ),
    CostPayment(
      id: 'p1',
      costId: 'cost-mahr',
      amount: '2000000',
      paidAt: DateTime(2026, 6, 10),
      note: 'يوم الخطوبة',
    ),
    CostPayment(
      id: 'p0',
      costId: 'cost-mahr',
      amount: '500000',
      paidAt: DateTime(2026, 5, 1),
      reversedById: 'p0-reversal',
    ),
  ];

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async => const [];
}
