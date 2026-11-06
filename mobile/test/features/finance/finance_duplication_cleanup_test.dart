import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/experience_v3/aarast_v3_foundations.dart';
import 'package:aarast_mobile/features/catalogs/data/reference_catalog_api.dart';
import 'package:aarast_mobile/features/catalogs/models/reference_catalog.dart';
import 'package:aarast_mobile/features/catalogs/providers/reference_catalog_provider.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/money_formatters.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('one money system cleanup', () {
    // Rule zero: the old budget starter is not in the prototype. A plan with
    // nothing in money opens on «البنود», where the first item goes.
    testWidgets('first money visit opens on «البنود» with no starter', (
      tester,
    ) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.noBudget()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('money-starter-submit')), findsNothing);
      expect(find.byKey(const ValueKey('money-starter-manual')), findsNothing);
      expect(find.text('ما في بنود بعد'), findsOneWidget);
      expect(find.text('أضف أول بند'), findsOneWidget);
      expect(find.byKey(const ValueKey('money-settings-menu')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // RA-MO-14: the opening tab follows the money alone. Waiting for the
    // catalogs and the quote requests too showed «الملخص» first and jumped
    // to «البنود» when those slower reads came back.
    testWidgets('an empty plan opens on «البنود» before the catalogs answer', (
      tester,
    ) async {
      _setTallView(tester);
      final catalog = Completer<ReferenceCatalogBootstrap?>();
      await tester.pumpWidget(
        _wrap(
          _FakeFinanceApi.noBudget(),
          catalogs: ReferenceCatalogProvider(_HeldCatalogApi(catalog)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('أضف أول بند'), findsOneWidget);

      catalog.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('أضف أول بند'), findsOneWidget);
    });

    testWidgets('first load failure shows only a retryable error state', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.failing()));
      await tester.pumpAndSettle();

      expect(find.text('ما قدرنا نجيبها'), findsOneWidget);
      expect(find.text('حاول مرة ثانية'), findsOneWidget);
      expect(find.text('ابدأ تنظيم مال الزفاف'), findsNothing);
      expect(find.text('مواعيد الدفع'), findsNothing);
      expect(find.text('التصنيفات'), findsNothing);
      expect(find.text('أحدث التكاليف'), findsNothing);
      expect(find.text('آخر الدفعات'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero and settings stay usable at 2.0 text scale', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(_FakeFinanceApi.withCosts(), textScale: 2.0),
      );
      await tester.pumpAndSettle();

      // c01: the server's numbers in one sentence, then the budget.
      expect(
        find.textContaining('اتفقت على', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('دفعت منها', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('المتاح من الميزانية'), findsOneWidget);
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
      // c03 lists the payments due; every date of an agreement is on its
      // page (c07), so the menu has no separate payment calendar.
      expect(
        find.byKey(const ValueKey('money-settings-schedules')),
        findsNothing,
      );
      expect(find.text('الميزانية والبنود'), findsOneWidget);
      expect(find.text('مواعيد الدفع'), findsNothing);
      // w22: an account's plan keeps receipts, reached from here.
      expect(
        find.byKey(const ValueKey('money-settings-receipts')),
        findsOneWidget,
      );
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
      // c01: the costs live under «البنود».
      await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
      await tester.pumpAndSettle();

      // c02: a budget item with no agreement yet reads «ما انحجز», with
      // the way to add more under it, and no second empty list.
      expect(find.text('الصالة'), findsOneWidget);
      expect(find.text('ما انحجز'), findsOneWidget);
      expect(find.text('أضف بند'), findsOneWidget);
      expect(find.text('ما في بنود بعد'), findsNothing);
      expect(find.text('مواعيد الدفع'), findsNothing);
      expect(find.byKey(const ValueKey('money-settings-menu')), findsOneWidget);
      expect(find.text('تنظيم إضافي'), findsNothing);
      expect(find.text('التصنيفات'), findsNothing);
      expect(find.text('أحدث التكاليف'), findsNothing);
      expect(find.text('آخر الدفعات'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«البنود» lists every loaded agreement', (tester) async {
      _setTallView(tester);
      await tester.pumpWidget(_wrap(_FakeFinanceApi.withCosts()));
      await tester.pumpAndSettle();
      // c01: the costs live under «البنود».
      await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('money-destination-costs')),
        findsNothing,
      );
      expect(find.text('إضافة تكلفة'), findsNothing);
      // c02: one list of agreements, each with what is paid.
      for (var index = 1; index <= 4; index++) {
        expect(find.byKey(ValueKey('money-item-cost-$index')), findsOneWidget);
      }
      expect(find.text('ما دفعت شي'), findsNWidgets(4));
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
      expect(find.text('الدفعة الجاية'), findsNothing);
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
      expect(find.text('الدفعة الجاية'), findsOneWidget);
      expect(find.text('دفعة متأخرة'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // c03: the payments tab totals what falls due, dates each row, and
    // offers «دفعتها» to screen readers as well as by swipe.
    testWidgets('«الدفعات» totals the due payments at 320px and 1.3', (
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
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journey-tab-2')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('money-due-total')), findsOneWidget);
      expect(find.text('خلال 30 يوم'), findsOneWidget);
      expect(find.text('دفعة وحدة'), findsOneWidget);
      expect(find.text('تكلفة 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('money-due-swipe-schedule-upcoming')),
        findsOneWidget,
      );
      // The main action in sight, beside the swipe.
      expect(
        find.byKey(const ValueKey('money-due-pay-schedule-upcoming')),
        findsOneWidget,
      );
      expect(find.text('سجّل الدفعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // RA-MO-10: the label says what the figure adds up. «المستحق عليك الآن»
    // over late and coming payments called the coming ones due now.
    testWidgets('the «الدفعات» total names late, coming, or both', (
      tester,
    ) async {
      _setTallView(tester);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      PaymentSchedule schedule(String id, int days) => PaymentSchedule(
        id: id,
        costId: 'cost-1',
        amount: '1000',
        dueDate: today.add(Duration(days: days)),
        status: 'PENDING',
        costTitle: 'تكلفة 1',
      );
      Future<void> openPayments(List<PaymentSchedule> due) async {
        // A fresh tree each time: the provider keeps its first instance.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _wrap(_FakeFinanceApi.withCosts(dueSchedules: due)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('journey-tab-2')));
        await tester.pumpAndSettle();
      }

      await openPayments([schedule('late', -5), schedule('soon', 10)]);
      expect(find.text('المتأخر والقادم خلال 30 يوم'), findsOneWidget);
      expect(find.text('المستحق عليك الآن'), findsNothing);

      await openPayments([schedule('late', -5)]);
      expect(find.text('المتأخر'), findsOneWidget);

      await openPayments([schedule('soon', 10)]);
      expect(find.text('خلال 30 يوم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // RA-MO-11 and RA-MO-12: the money texts address no one wrongly.
    testWidgets('money copy is neutral where any reader may read it', (
      tester,
    ) async {
      _setTallView(tester);
      await tester.pumpWidget(
        _wrap(
          _FakeFinanceApi.withCosts(
            warnings: [
              for (var index = 0; index < 5; index++)
                MoneyWarning(
                  type: 'CATEGORY_EXCEEDED',
                  severity: 'warning',
                  categoryId: 'category-1',
                  amount: '100',
                ),
            ],
            payers: const [
              MoneyPayerSummary(payer: 'FATHER', ownerMoney: false, paid: '100'),
              MoneyPayerSummary(payer: 'MOTHER', ownerMoney: false, paid: '100'),
              MoneyPayerSummary(payer: 'BROTHER', ownerMoney: false, paid: '100'),
              MoneyPayerSummary(payer: 'SISTER', ownerMoney: false, paid: '100'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Within the budget, said the same way to the owner and a participant.
      expect(find.text('في حدود الميزانية'), findsOneWidget);
      expect(find.text('في حدود ميزانيتك'), findsNothing);
      // Five over-limit items, three shown: the note counts the other two.
      expect(
        find.text('تجاوز المخصص في بندين ثانيين كذلك. كلها في «البنود».'),
        findsOneWidget,
      );
      // Four payers, two named: the other two are people, «اثنين».
      expect(find.textContaining('اثنين كذلك'), findsOneWidget);
      expect(find.textContaining('ثنتين'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // c05: the owner's «من وين» shows what reached them and what is
    // promised, then each source with its state.
    testWidgets('«من وين» shows the sources and their state at 320px', (
      tester,
    ) async {
      _setPhoneView(tester);
      await tester.pumpWidget(
        _wrap(
          _FakeFinanceApi.withCosts(
            funding: const MoneyFundingSummary(
              received: '6000',
              pledged: '1000',
              availableCash: '6000',
              shortfall: '1000',
            ),
          ),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ومع الموعود ناقصك'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('journey-tab-3')));
      await tester.pumpAndSettle();

      expect(find.text('وصلك'), findsOneWidget);
      expect(find.text('موعود لك'), findsOneWidget);
      expect(find.text('مدخراتي'), findsOneWidget);
      expect(find.text('وصل'), findsOneWidget);
      expect(find.text('سلفة خالي'), findsOneWidget);
      expect(find.text('موعود'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // F02: hiding amounts must cover the next-payment card too.
    testWidgets('hiding amounts masks the next payment amount', (tester) async {
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
      final strip = find.byKey(const ValueKey('money-next-schedule-strip'));
      // Inside Arabic text the amount is in its plain form.
      final amount = compactMoneyParts(1000, currencyCode: 'YER').plainText;
      Finder amountInStrip() =>
          find.descendant(of: strip, matching: find.textContaining(amount));
      expect(amountInStrip(), findsOneWidget);

      // The eye beside «المال» hides it (c01).
      await tester.tap(find.byKey(const ValueKey('money-privacy-toggle')));
      await tester.pumpAndSettle();

      expect(amountInStrip(), findsNothing);
      expect(
        find.descendant(of: strip, matching: find.textContaining('••••')),
        findsOneWidget,
      );
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

      expect(find.text('المتاح من الميزانية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('embedded money root owns an opaque soft-white surface', (
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
      expect(surface.color, AppTheme.canvas);
      // The plan's «+» floats over money for whoever manages it (D33): the
      // last card must scroll fully clear of it.
      expect(padding.bottom, AarastV3Density.pageBottomWithQuickAction);
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

      expect(find.text('ما قدرنا نجيبها'), findsOneWidget);
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
        // The groom cleanup: old pages the design replaced.
        'lib/features/finance/screens/costs_screen.dart',
        'lib/features/finance/screens/payment_schedule_screens.dart',
        'lib/features/finance/widgets/money_starter_setup.dart',
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
        'CostsScreen',
        'PaymentSchedulesScreen',
        'PaymentScheduleFormScreen',
        'PaymentScheduleDetailsScreen',
        '/money/schedules',
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
  ReferenceCatalogProvider? catalogs,
}) {
  const planId = 'plan-money-cleanup';
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider(api),
      ),
      ChangeNotifierProvider<FundingProvider>(
        create: (_) => FundingProvider(_FakeFundingApi()),
      ),
      if (catalogs != null)
        ChangeNotifierProvider<ReferenceCatalogProvider>.value(
          value: catalogs,
        ),
    ],
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
          personaCode: 'groom',
        ),
      ),
    ),
  );
}

/// A catalog read that answers only when the test says so.
class _HeldCatalogApi implements ReferenceCatalogApi {
  _HeldCatalogApi(this._answer);

  final Completer<ReferenceCatalogBootstrap?> _answer;

  @override
  Future<ReferenceCatalogBootstrap?> load() => _answer.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi._(
    this._costs, {
    this.fail = false,
    this.hasBudget = false,
    this.nextSchedule,
    this.funding,
    this.dueSchedules,
    this.warnings = const [],
    this.payers = const [],
  }) : super(ApiClient(tokenProvider: () async => null));

  factory _FakeFinanceApi.noBudget() => _FakeFinanceApi._(const []);

  factory _FakeFinanceApi.budgetOnly() =>
      _FakeFinanceApi._(const [], hasBudget: true);

  factory _FakeFinanceApi.failing() => _FakeFinanceApi._(const [], fail: true);

  factory _FakeFinanceApi.withCosts({
    PaymentSchedule? nextSchedule,
    MoneyFundingSummary? funding,
    List<PaymentSchedule>? dueSchedules,
    List<MoneyWarning> warnings = const [],
    List<MoneyPayerSummary> payers = const [],
  }) => _FakeFinanceApi._(
    [
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
    ],
    nextSchedule: nextSchedule,
    funding: funding,
    dueSchedules: dueSchedules,
    warnings: warnings,
    payers: payers,
  );

  final List<WeddingCost> _costs;
  final MoneyFundingSummary? funding;
  final bool fail;
  final bool hasBudget;
  final PaymentSchedule? nextSchedule;
  final List<PaymentSchedule>? dueSchedules;
  final List<MoneyWarning> warnings;
  final List<MoneyPayerSummary> payers;

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
              // A budget with no categories is offered the starter (Q02), so
              // the set-up-but-nothing-spent state has its categories.
              categories: const [
                MoneyCategorySummary(categoryId: 'category-1', name: 'الصالة'),
              ],
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
      funding: funding,
      warnings: warnings,
      payers: payers,
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
    String? payer,
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
      dueSchedules ?? (nextSchedule == null ? const [] : [nextSchedule!]);
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

class _FakeFundingApi extends FundingApi {
  _FakeFundingApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async =>
      const [
        FundingSource(
          id: 'source-1',
          weddingPlanId: 'plan-money-cleanup',
          kind: FundingKind.savings,
          sourceName: 'مدخراتي',
          amount: '6000',
          status: FundingStatus.received,
        ),
        FundingSource(
          id: 'source-2',
          weddingPlanId: 'plan-money-cleanup',
          kind: FundingKind.loan,
          sourceName: 'سلفة خالي',
          amount: '1000',
          status: FundingStatus.pledged,
        ),
      ];
}
