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
import 'package:go_router/go_router.dart';
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
      'detail routes show one retryable load error instead of fake missing data',
      (tester) async {
        final cases =
            <({Widget screen, String errorTitle, String absentTitle})>[
              (
                screen: const CostDetailsScreen(
                  weddingPlanId: 'plan-1',
                  costId: 'cost-1',
                ),
                errorTitle: 'تعذر تحميل التكلفة',
                absentTitle: 'التكلفة غير موجودة',
              ),
              (
                screen: const RecordCostPaymentScreen(
                  weddingPlanId: 'plan-1',
                  costId: 'cost-1',
                ),
                errorTitle: 'تعذر تحميل التكلفة',
                absentTitle: 'التكلفة غير موجودة',
              ),
              (
                screen: const CostPaymentDetailsScreen(
                  weddingPlanId: 'plan-1',
                  paymentId: 'payment-1',
                  costId: 'cost-1',
                ),
                errorTitle: 'تعذر تحميل الدفعة',
                absentTitle: 'الدفعة غير موجودة',
              ),
              (
                screen: const PaymentSchedulesScreen(weddingPlanId: 'plan-1'),
                errorTitle: 'تعذر تحميل مواعيد الدفع',
                absentTitle: 'لا توجد مواعيد دفع',
              ),
              (
                screen: const PaymentScheduleDetailsScreen(
                  weddingPlanId: 'plan-1',
                  costId: 'cost-1',
                  scheduleId: 'schedule-1',
                ),
                errorTitle: 'تعذر تحميل موعد الدفع',
                absentTitle: 'الموعد غير موجود',
              ),
              (
                screen: const PaymentScheduleFormScreen(
                  weddingPlanId: 'plan-1',
                  costId: 'cost-1',
                ),
                errorTitle: 'تعذر تحميل موعد الدفع',
                absentTitle: 'تعذر فتح الموعد',
              ),
              (
                screen: const PayPaymentScheduleScreen(
                  weddingPlanId: 'plan-1',
                  costId: 'cost-1',
                  scheduleId: 'schedule-1',
                ),
                errorTitle: 'تعذر تحميل موعد الدفع',
                absentTitle: 'تعذر فتح الموعد',
              ),
            ];

        for (final item in cases) {
          await _pumpMoneyScreen(
            tester,
            item.screen,
            api: _FailingMoneyDetailsApi(),
          );
          expect(find.text(item.errorTitle), findsOneWidget, reason: '$item');
          expect(find.text(item.absentTitle), findsNothing, reason: '$item');
          expect(find.text('حاول مرة أخرى'), findsOneWidget, reason: '$item');
          expect(tester.takeException(), isNull, reason: '$item');
        }
      },
    );

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
        expect(find.text('غير مدفوع'), findsOneWidget);
        expect(find.text('معلومات التكلفة'), findsOneWidget);

        await tester.tap(find.byTooltip('المزيد'));
        await tester.pumpAndSettle();
        expect(find.text('تعديل التكلفة'), findsOneWidget);
        expect(find.text('إلغاء التكلفة'), findsNothing);
        await tester.tapAt(const Offset(8, 8));
        await tester.pumpAndSettle();
        expect(find.text('موعد الاستحقاق'), findsNothing);

        await tester.scrollUntilVisible(find.text('الدفعات'), 240);
        expect(find.text('الدفعات'), findsOneWidget);
        expect(find.text('تسجيل دفعة'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('مواعيد الدفع'), 240);
        expect(find.text('مواعيد الدفع'), findsOneWidget);
        expect(find.text('إضافة موعد'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('payment details stay usable at 320px and 1.3 text scale', (
      tester,
    ) async {
      await _pumpMoneyScreen(
        tester,
        const CostPaymentDetailsScreen(
          weddingPlanId: 'plan-1',
          paymentId: 'payment-1',
          costId: 'cost-1',
        ),
      );

      expect(find.text('تفاصيل الدفعة'), findsOneWidget);
      expect(find.text('فتح التكلفة المرتبطة'), findsOneWidget);
      expect(find.text('عكس الدفعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('schedule list stays usable at 320px and 1.3 text scale', (
      tester,
    ) async {
      await _pumpMoneyScreen(
        tester,
        const PaymentSchedulesScreen(weddingPlanId: 'plan-1'),
      );

      expect(find.text('مواعيد الدفع'), findsOneWidget);
      expect(find.text('قاعة الحفل'), findsOneWidget);
      expect(find.text('1 معلّق'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('linked provider opens its real marketplace profile', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/cost',
        routes: [
          GoRoute(
            path: '/cost',
            builder: (_, _) => const CostDetailsScreen(
              weddingPlanId: 'plan-1',
              costId: 'cost-1',
            ),
          ),
          GoRoute(
            path: '/providers/:id',
            builder: (_, state) => Scaffold(
              body: Text('provider-profile-${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      await _pumpMoneyRouter(tester, router);

      final providerName = find.text('قاعة السعادة');
      await tester.scrollUntilVisible(providerName, 220);
      await tester.tap(providerName);
      await tester.pumpAndSettle();

      expect(find.text('provider-profile-provider-1'), findsOneWidget);
      expect(router.state.uri.path, AppRouter.providerDetails('provider-1'));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'direct payment ignores pending reminders and validates real remainder',
      (tester) async {
        await _pumpMoneyScreen(
          tester,
          const RecordCostPaymentScreen(
            weddingPlanId: 'plan-1',
            costId: 'cost-1',
          ),
        );

        final amount = find.byKey(const Key('cost-payment-amount'));
        expect(amount, findsOneWidget);
        expect(find.text('ر.ي'), findsOneWidget);
        expect(find.text('YER'), findsNothing);
        await tester.enterText(amount, '0');
        final save = find.text('حفظ الدفعة');
        await tester.ensureVisible(save);
        await tester.drag(find.byType(ListView).last, const Offset(0, -80));
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pump();
        expect(find.text('أدخل مبلغًا أكبر من صفر.'), findsOneWidget);

        await tester.enterText(amount, '500');
        expect(
          tester.state<FormState>(find.byType(Form)).validate(),
          isTrue,
          reason:
              'the pending 400 reminder must not reserve any of the 800 remainder',
        );
        await tester.pump();
        expect(find.textContaining('يتجاوز'), findsNothing);

        await tester.enterText(amount, '900');
        expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
        await tester.pump();
        expect(
          find.text('المبلغ يتجاوز غير المدفوع على التكلفة.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

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
        await tester.drag(find.byType(ListView).last, const Offset(0, -520));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pay-schedule-submit')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'schedule reminders do not reserve each other and use real remainder',
      (tester) async {
        await _pumpMoneyScreen(
          tester,
          const PaymentScheduleFormScreen(
            weddingPlanId: 'plan-1',
            costId: 'cost-1',
          ),
        );

        final amount = find.byKey(const Key('payment-schedule-amount'));
        expect(find.text('ر.ي'), findsOneWidget);
        expect(find.text('YER'), findsNothing);
        expect(find.text('غير مدفوع على التكلفة'), findsOneWidget);
        await tester.enterText(amount, '700');
        expect(
          tester.state<FormState>(find.byType(Form)).validate(),
          isTrue,
          reason:
              '700 plus the existing 400 reminder may exceed the 800 remainder because reminders do not reserve money',
        );
        await tester.pump();
        await tester.enterText(amount, '900');
        expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
        await tester.pump();
        expect(
          find.text('المبلغ يتجاوز غير المدفوع على التكلفة.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpMoneyScreen(
  WidgetTester tester,
  Widget screen, {
  FinanceApi? api,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1100);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(api ?? _MoneyDetailsApi()),
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

class _FailingMoneyDetailsApi extends _MoneyDetailsApi {
  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    throw const ApiException(
      'تعذر الاتصال بالخادم الآن. تحقق من الاتصال وحاول مرة أخرى.',
      isNetworkFailure: true,
    );
  }
}

Future<void> _pumpMoneyRouter(WidgetTester tester, GoRouter router) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1100);
  addTearDown(tester.view.reset);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(_MoneyDetailsApi()),
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
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
    String? payer,
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
