import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('one money system cleanup', () {
    testWidgets('first money visit permits cost entry before budget setup', (
      tester,
    ) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.noBudget()));
      await tester.pumpAndSettle();

      expect(find.text('الميزانية غير محددة'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('money-empty-add-cost')),
        findsOneWidget,
      );
      expect(find.text('تحديد الميزانية'), findsWidgets);
      expect(find.byTooltip('إدارة الميزانية'), findsNothing);
      expect(find.byKey(const ValueKey('money-settings-menu')), findsOneWidget);
      expect(find.text('إضافة تكلفة'), findsOneWidget);
      expect(find.text('التصنيفات'), findsNothing);
      expect(find.text('أحدث التكاليف'), findsNothing);
      expect(find.text('آخر الدفعات'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('first load failure shows only a retryable error state', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.failing()));
      await tester.pumpAndSettle();

      expect(find.text('تعذر تحميل المال'), findsOneWidget);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      expect(find.text('ابدأ تنظيم مال الزفاف'), findsNothing);
      expect(find.text('مواعيد الدفع'), findsNothing);
      expect(find.text('التصنيفات'), findsNothing);
      expect(find.text('أحدث التكاليف'), findsNothing);
      expect(find.text('آخر الدفعات'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero and settings stay compact at large text', (tester) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), textScale: 1.6),
      );
      await tester.pumpAndSettle();

      expect(find.text('الميزانية الكلية'), findsOneWidget);
      expect(find.text('المتاح من الميزانية'), findsOneWidget);
      expect(find.text('المدفوع'), findsWidgets);
      expect(find.text('التكاليف'), findsOneWidget);
      expect(find.text('المتبقي للدفع'), findsWidgets);
      expect(find.text('إضافة تكلفة'), findsNothing);
      expect(
        find.byKey(const ValueKey('money-destination-budget')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('money-destination-costs')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('money-destination-schedules')),
        findsNothing,
      );
      expect(find.text('تنظيم إضافي'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('money-settings-menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('money-settings-budget')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('money-settings-schedules')),
        findsOneWidget,
      );
      expect(find.text('الميزانية والتصنيفات'), findsOneWidget);
      expect(find.text('مواعيد الدفع'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('budget-only state guides without duplicating empty lists', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.budgetOnly(), textScale: 1.3),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد تكاليف بعد'), findsOneWidget);
      expect(find.text('مواعيد الدفع'), findsNothing);
      expect(find.byKey(const ValueKey('money-settings-menu')), findsOneWidget);
      expect(find.text('تنظيم إضافي'), findsNothing);
      expect(find.text('التصنيفات'), findsNothing);
      expect(find.text('أحدث التكاليف'), findsNothing);
      expect(find.text('آخر الدفعات'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('money root shows each cost record once', (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.withCosts()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('money-destination-costs')),
        findsNothing,
      );
      expect(find.text('إضافة تكلفة'), findsNothing);
      for (var index = 1; index <= 4; index++) {
        expect(find.text('تكلفة $index'), findsOneWidget);
      }
    });

    test('payment status palette stays calm and distinct', () {
      expect(moneyStatusMeta('OPEN').color, AppTheme.muted);
      expect(moneyStatusMeta('OPEN').background, AppTheme.dangerSoft);
      expect(moneyStatusMeta('PARTIALLY_PAID').color, AppTheme.warning);
      expect(
        moneyStatusMeta('PARTIALLY_PAID').background,
        AppTheme.warningSoft,
      );
      expect(moneyStatusMeta('PAID').color, AppTheme.success);
      expect(moneyStatusMeta('PAID').background, AppTheme.successSoft);
      expect(moneyStatusMeta('CANCELLED').color, AppTheme.muted);
      expect(
        moneyStatusMeta('CANCELLED').background,
        AppTheme.muted.withValues(alpha: .10),
      );
    });

    testWidgets('past pending schedule is shown as an overdue payment', (
      tester,
    ) async {
      _setPhoneView(tester);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.pumpWidget(
        _wrap(
          _FakeFinanceApi.withCosts(
            nextSchedule: PaymentSchedule(
              id: 'schedule-overdue',
              costId: 'cost-1',
              amount: '1000',
              dueDate: today.subtract(const Duration(days: 2)),
              status: 'PENDING',
              costTitle: 'تكلفة 1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('money-next-schedule-strip')),
        findsOneWidget,
      );
      expect(find.text('دفعة متأخرة'), findsOneWidget);
      expect(find.text('موعد الدفع التالي'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('future pending schedule is shown as the next payment', (
      tester,
    ) async {
      _setPhoneView(tester);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.pumpWidget(
        _wrap(
          _FakeFinanceApi.withCosts(
            nextSchedule: PaymentSchedule(
              id: 'schedule-upcoming',
              costId: 'cost-1',
              amount: '1000',
              dueDate: today.add(const Duration(days: 2)),
              status: 'PENDING',
              costTitle: 'تكلفة 1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('money-next-schedule-strip')),
        findsOneWidget,
      );
      expect(find.text('موعد الدفع التالي'), findsOneWidget);
      expect(find.text('دفعة متأخرة'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('money root stays overflow-free at 320px RTL and scale 1.3', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), textScale: 1.3),
      );
      await tester.pumpAndSettle();

      expect(find.text('المال'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('embedded money root owns an opaque ivory surface', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), embedded: true),
      );
      await tester.pumpAndSettle();

      final surface = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('money-overview-surface')),
      );
      final list = tester.widget<ListView>(
        find.byKey(const PageStorageKey('money-overview-list')),
      );
      final padding = list.padding! as EdgeInsets;
      expect(surface.color, AppTheme.ivory);
      expect(
        padding.bottom,
        greaterThanOrEqualTo(196),
        reason:
            'The final money card must scroll fully clear of the smart FAB.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('member without money access sees the private state only', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), sharedMember: _deniedMember()),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذر تحميل المال'), findsOneWidget);
      expect(find.text('تكلفة 4'), findsNothing);
      expect(find.text('إعداد الميزانية'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('removed finance implementations cannot return', () {
      for (final path in <String>[
        'lib/features/finance/data/budget_expense_api.dart',
        'lib/features/finance/models/expense.dart',
        'lib/features/finance/models/financial_commitment.dart',
        'lib/features/finance/screens/budget_expense_screen.dart',
        'lib/features/finance/screens/financial_payables_screen.dart',
        'lib/features/finance/widgets/finance_overview',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }

      final router = File(
        'lib/core/routing/app_router.dart',
      ).readAsStringSync();
      for (final removed in <String>[
        'BudgetExpenseScreen',
        'FinancialPayablesScreen',
        '/expenses',
        '/financial-commitments',
      ]) {
        expect(router, isNot(contains(removed)), reason: removed);
      }
    });

    test('live mobile copy cannot restore legacy money terminology', () {
      const removedTerms = <String>[
        'المستحقات',
        'مستحقات',
        'المصروف',
        'مصروف',
        'الأقساط',
        'أقساط',
      ];
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final term in removedTerms) {
          if (source.contains(term)) offenders.add('${entity.path}: $term');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}

Widget _wrap(
  _FakeFinanceApi api, {
  SharedMember? sharedMember,
  double textScale = 1,
  bool embedded = false,
}) {
  const planId = 'plan-money-cleanup';
  return ChangeNotifierProvider<FinanceProvider>(
    create: (_) => FinanceProvider(api),
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MoneyOverviewScreen(
          weddingPlanId: planId,
          sharedMember: sharedMember,
          embedded: embedded,
        ),
      ),
    ),
  );
}

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi._(
    this._costs, {
    this.fail = false,
    this.hasBudget = false,
    this.nextSchedule,
  }) : super(ApiClient(tokenProvider: () async => null));

  factory _FakeFinanceApi.noBudget() => _FakeFinanceApi._(const []);

  factory _FakeFinanceApi.budgetOnly() =>
      _FakeFinanceApi._(const [], hasBudget: true);

  factory _FakeFinanceApi.failing() => _FakeFinanceApi._(const [], fail: true);

  factory _FakeFinanceApi.withCosts({PaymentSchedule? nextSchedule}) =>
      _FakeFinanceApi._([
        for (var index = 1; index <= 4; index++)
          WeddingCost(
            id: 'cost-$index',
            weddingPlanId: 'plan-money-cleanup',
            budgetCategoryId: 'category-1',
            title: 'تكلفة $index',
            totalAmount: '2000',
            paidAmount: '0',
            remainingAmount: '2000',
            status: 'OPEN',
            createdAt: DateTime.utc(2026, 7, index),
            updatedAt: DateTime.utc(2026, 7, index),
          ),
      ], nextSchedule: nextSchedule);

  final List<WeddingCost> _costs;
  final bool fail;
  final bool hasBudget;
  final PaymentSchedule? nextSchedule;

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    if (fail) throw const ApiException('تعذر الاتصال بالخادم.');
    if (_costs.isEmpty) {
      return hasBudget
          ? MoneySummary(
              planId: planId,
              currency: 'YER',
              budget: const MoneyBudgetSummary(
                total: '3000000',
                allocated: '0',
                unallocated: '3000000',
                confirmedCost: '0',
                remaining: '3000000',
              ),
            )
          : MoneySummary.empty(planId);
    }
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      budget: const MoneyBudgetSummary(
        total: '20000',
        allocated: '10000',
        unallocated: '10000',
        confirmedCost: '8000',
        remaining: '12000',
      ),
      costs: const MoneyCostsSummary(
        total: '8000',
        outstanding: '8000',
        count: 4,
      ),
      paymentSchedules: MoneySchedulesSummary(
        totalCount: nextSchedule == null ? 0 : 1,
        upcomingCount:
            nextSchedule != null && !nextSchedule!.isOverdueAt(DateTime.now())
            ? 1
            : 0,
        overdueCount:
            nextSchedule != null && nextSchedule!.isOverdueAt(DateTime.now())
            ? 1
            : 0,
        next: nextSchedule,
      ),
      categories: const [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'الصالة',
          allocatedAmount: '10000',
          confirmedCost: '8000',
          outstanding: '8000',
          remainingAllocation: '2000',
          costsCount: 4,
        ),
      ],
    );
  }

  @override
  Future<FinancePage<WeddingCost>> getCosts(
    String planId, {
    int page = 1,
    int limit = 30,
    String? status,
    String? categoryId,
    String? search,
  }) async => FinancePage(
    items: _costs,
    page: page,
    pageSize: limit,
    total: _costs.length,
    totalPages: 1,
  );

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async => FinancePage(
    items: const [],
    page: page,
    pageSize: limit,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      nextSchedule == null ? const [] : [nextSchedule!];
}

SharedMember _deniedMember() {
  final now = DateTime.utc(2026, 7, 11);
  return SharedMember(
    id: 'member-denied',
    weddingPlanId: 'plan-money-cleanup',
    userId: 'user-denied',
    role: 'VIEWER',
    canViewMoney: false,
    canManageTasks: false,
    canManageMoney: false,
    createdAt: now,
    updatedAt: now,
  );
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1800);
  addTearDown(tester.view.reset);
}

void _setPhoneView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1200);
  addTearDown(tester.view.reset);
}
