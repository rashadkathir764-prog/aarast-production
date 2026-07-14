import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/cost_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_payment_screens.dart';
import 'package:aarast_mobile/features/finance/screens/payment_schedule_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('money detail routes', () {
    test('all detail actions have canonical real routes', () {
      expect(
        AppRouter.moneyCostDetails('plan-1', 'cost-1'),
        '/wedding-plans/plan-1/money/costs/cost-1',
      );
      expect(
        AppRouter.moneyPaymentCreate('plan-1', 'cost-1'),
        '/wedding-plans/plan-1/money/costs/cost-1/payments/create',
      );
      expect(
        AppRouter.moneyPaymentDetails('plan-1', 'payment-1', costId: 'cost-1'),
        '/wedding-plans/plan-1/money/payments/payment-1?costId=cost-1',
      );
      expect(
        AppRouter.moneySchedulePay('plan-1', 'cost-1', 'schedule-1'),
        '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1/pay',
      );
    });
  });

  group('money detail screens at narrow Arabic layout', () {
    testWidgets(
      'cost details exposes the complete hierarchy without overflow',
      (tester) async {
        await _pumpMoneyScreen(
          tester,
          const CostDetailsScreen(weddingPlanId: 'plan-1', costId: 'cost-1'),
        );

        expect(find.text('تفاصيل التكلفة'), findsOneWidget);
        expect(find.text('قاعة الحفل'), findsWidgets);
        expect(find.text('الإجمالي'), findsOneWidget);
        expect(find.text('المدفوع'), findsOneWidget);
        expect(find.text('الباقي'), findsOneWidget);
        expect(find.text('معلومات التكلفة'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('إدارة التكلفة'), 240);
        expect(find.text('إدارة التكلفة'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('الدفعات'), 240);
        expect(find.text('الدفعات'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('مواعيد الدفع'), 240);
        expect(find.text('مواعيد الدفع'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('direct payment validates positive amount and free remainder', (
      tester,
    ) async {
      await _pumpMoneyScreen(
        tester,
        const RecordCostPaymentScreen(
          weddingPlanId: 'plan-1',
          costId: 'cost-1',
        ),
      );

      final amount = find.byKey(const Key('cost-payment-amount'));
      expect(amount, findsOneWidget);
      await tester.enterText(amount, '0');
      final save = find.text('حفظ الدفعة');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(find.text('أدخل مبلغًا أكبر من صفر.'), findsOneWidget);

      await tester.enterText(amount, '500');
      await tester.tap(save);
      await tester.pump();
      expect(
        find.text('المبلغ يتجاوز المتاح للدفعة المباشرة.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'schedule details keeps all pending actions inside the screen',
      (tester) async {
        await _pumpMoneyScreen(
          tester,
          const PaymentScheduleDetailsScreen(
            weddingPlanId: 'plan-1',
            costId: 'cost-1',
            scheduleId: 'schedule-1',
          ),
        );

        expect(find.text('تفاصيل موعد الدفع'), findsOneWidget);
        expect(find.text('إدارة الموعد'), findsOneWidget);
        expect(find.text('تسجيل دفع الموعد'), findsOneWidget);
        expect(find.text('تعديل'), findsOneWidget);
        expect(find.text('إلغاء وحفظ السجل'), findsOneWidget);
        expect(find.text('حذف نهائي'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'paying a schedule shows fixed amount and no free amount field',
      (tester) async {
        await _pumpMoneyScreen(
          tester,
          const PayPaymentScheduleScreen(
            weddingPlanId: 'plan-1',
            costId: 'cost-1',
            scheduleId: 'schedule-1',
          ),
        );

        expect(find.text('المبلغ المحدد في الموعد'), findsOneWidget);
        expect(
          find.textContaining('سيُسجَّل مبلغ الموعد كاملًا'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('cost-payment-amount')), findsNothing);
        expect(find.byKey(const Key('payment-schedule-amount')), findsNothing);
        expect(find.byKey(const Key('pay-schedule-submit')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'schedule form is responsive and validates its available amount',
      (tester) async {
        await _pumpMoneyScreen(
          tester,
          const PaymentScheduleFormScreen(
            weddingPlanId: 'plan-1',
            costId: 'cost-1',
          ),
        );

        final amount = find.byKey(const Key('payment-schedule-amount'));
        await tester.enterText(amount, '900');
        final submit = find.text('إضافة الموعد');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(find.text('المبلغ يتجاوز المتاح للجدولة.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpMoneyScreen(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1100);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(_MoneyDetailsApi()),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MoneyDetailsApi extends FinanceApi {
  _MoneyDetailsApi() : super(ApiClient(tokenProvider: () async => null));

  static final _now = DateTime(2026, 7, 14, 12);

  final WeddingCost cost = WeddingCost(
    id: 'cost-1',
    weddingPlanId: 'plan-1',
    budgetCategoryId: 'category-1',
    title: 'قاعة الحفل',
    totalAmount: '1000',
    paidAmount: '200',
    remainingAmount: '800',
    status: 'PARTIALLY_PAID',
    providerId: 'provider-1',
    providerName: 'قاعة السعادة',
    agreementDate: _now.subtract(const Duration(days: 20)),
    dueDate: _now.add(const Duration(days: 60)),
    note: 'الاتفاق يشمل تجهيز القاعة.',
    paymentsCount: 1,
  );

  final CostPayment payment = CostPayment(
    id: 'payment-1',
    costId: 'cost-1',
    weddingPlanId: 'plan-1',
    amount: '200',
    paidAt: _now.subtract(const Duration(days: 5)),
    method: 'تحويل',
    reversible: true,
    costTitle: 'قاعة الحفل',
  );

  final PaymentSchedule schedule = PaymentSchedule(
    id: 'schedule-1',
    costId: 'cost-1',
    weddingPlanId: 'plan-1',
    amount: '400',
    dueDate: _now.add(const Duration(days: 30)),
    status: 'PENDING',
    costTitle: 'قاعة الحفل',
    note: 'الدفعة الثانية',
  );

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(total: '5000'),
      costs: const MoneyCostsSummary(
        total: '1000',
        paid: '200',
        outstanding: '800',
        count: 1,
      ),
      permissions: const MoneyPermissions(
        canViewMoney: true,
        canManageMoney: true,
      ),
    );
  }

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async {
    return [
      BudgetCategory(
        id: 'category-1',
        weddingPlanId: planId,
        name: 'القاعات',
        allocatedAmount: '2000',
      ),
    ];
  }

  @override
  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
  }) async {
    return FinancePage(
      items: [cost],
      page: 1,
      pageSize: 30,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async {
    return FinancePage(
      items: [payment],
      page: 1,
      pageSize: 30,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async {
    return [schedule];
  }

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async {
    return [payment];
  }

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async {
    return [schedule];
  }
}
