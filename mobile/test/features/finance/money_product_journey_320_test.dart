import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/cost_draft_intent.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/budget_category_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_details_screen.dart';
import 'package:aarast_mobile/features/finance/screens/cost_form_screen.dart';
import 'package:aarast_mobile/features/finance/screens/costs_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_budget_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/finance/screens/payment_schedule_screens.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const _planId = 'plan-money-product';

void main() {
  group('canonical money product journey at 320px RTL and 1.3 scale', () {
    testWidgets('owner opens real schedule, category, and cost destinations', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      const stripKey = ValueKey('money-next-schedule-strip');
      expect(find.byType(MoneyOverviewScreen), findsOneWidget);
      // The budget sits under the summary and the next payment.
      await tester.scrollUntilVisible(
        find.text('المتاح من الميزانية'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('المتاح من الميزانية'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('money-dashboard-hero')),
        findsOneWidget,
      );
      expect(find.byKey(stripKey), findsOneWidget);
      expect(
        find.byKey(const ValueKey('money-destination-costs')),
        findsNothing,
      );
      // c01: the costs live under «البنود».
      await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('money-item-cost-1')), findsOneWidget);
      _expectRtl(tester, find.byType(MoneyOverviewScreen));
      expect(tester.takeException(), isNull);
      // The next payment is on «الملخص».
      await tester.tap(find.byKey(const ValueKey('journey-tab-0')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(stripKey),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(stripKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(stripKey));
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyScheduleDetails(_planId, 'cost-1', 'schedule-1'),
      );
      expect(find.byType(PaymentScheduleDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      harness.router.pop();
      await tester.pumpAndSettle();
      await _openMoneySettings(tester);
      await tester.tap(find.byKey(const ValueKey('money-settings-schedules')));
      await tester.pumpAndSettle();
      expect(harness.currentLocation, AppRouter.moneySchedules(_planId));
      expect(find.byType(PaymentSchedulesScreen), findsOneWidget);
      expect(find.byType(ScheduleCard), findsWidgets);
      expect(find.textContaining('معلّق ·'), findsWidgets);
      expect(find.text('تسجيل الدفع'), findsWidgets);
      expect(tester.takeException(), isNull);

      harness.router.pop();
      await tester.pumpAndSettle();
      await _openMoneySettings(tester);
      await tester.tap(find.byKey(const ValueKey('money-settings-budget')));
      await tester.pumpAndSettle();
      expect(harness.currentLocation, AppRouter.moneyBudget(_planId));
      expect(find.byType(MoneyBudgetScreen), findsOneWidget);

      const categoryRow = ValueKey('money-budget-category-category-1');
      await tester.scrollUntilVisible(
        find.byKey(categoryRow),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(categoryRow));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(categoryRow));
      await tester.pumpAndSettle();
      // w19: an item opens its share in a sheet; its page is one press on.
      await tester.tap(
        find.byKey(const ValueKey('money-budget-open-category-1')),
      );
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyCategoryDetails(_planId, 'category-1'),
      );
      expect(find.byType(BudgetCategoryDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      harness.router.pop();
      await tester.pumpAndSettle();
      harness.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
      await tester.pumpAndSettle();
      const itemKey = ValueKey('money-item-cost-1');
      await tester.scrollUntilVisible(
        find.byKey(itemKey),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(itemKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(itemKey));
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyCostDetails(_planId, 'cost-1'),
      );
      expect(find.byType(CostDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'new groom sees the smart starter and can choose manual setup',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.money(_planId),
          noBudget: true,
          personaCode: 'GROOM',
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        expect(
          find.byKey(const ValueKey('money-starter-setup')),
          findsOneWidget,
        );
        expect(find.text('جهّز ميزانية عرسك'), findsOneWidget);
        expect(find.text('فستان العروسة'), findsNothing);
        expect(
          find.byKey(const ValueKey('money-empty-add-cost')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('money-budget-setup')), findsNothing);
        expect(tester.takeException(), isNull);

        final setup = find.byKey(const ValueKey('money-starter-manual'));
        await tester.tap(setup);
        await tester.pumpAndSettle();
        expect(harness.currentLocation, AppRouter.moneyBudget(_planId));
        expect(find.byType(MoneyBudgetScreen), findsOneWidget);
        // w19: the budget, the reserve and each item's share.
        expect(find.text('توزيع الميزانية'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('money-budget-reserve')),
          findsOneWidget,
        );
        expect(find.text('حفظ التوزيع'), findsOneWidget);
        _expectRtl(tester, find.byType(MoneyBudgetScreen));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'starter creates the selected groom categories in one atomic budget write',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.money(_planId),
          noBudget: true,
          personaCode: 'GROOM',
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        // The mahr is outside the budget (DECISIONS 2026-10-22, C1).
        expect(find.text('تجهيز الميزانية · 11'), findsOneWidget);
        await tester.tap(find.text('تجهيز الميزانية · 11'));
        await tester.pumpAndSettle();

        expect(harness.api.replaceBudgetCalls, 1);
        expect(harness.api.savedCategoryCount, 11);
        expect(harness.api.savedTotalBudget, isNull);
        expect(harness.currentLocation, AppRouter.moneyBudget(_planId));
        expect(find.byType(MoneyBudgetScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'budget waits for a successful retry before hydrating persisted data',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.moneyBudget(_planId),
          failSummaryLoads: 1,
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        expect(find.text('تعذر التحقق من الصلاحيات'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('money-budget-reserve')),
          findsNothing,
        );

        await tester.tap(find.text('حاول مرة أخرى'));
        await tester.pumpAndSettle();

        // The budget lives behind the «موزّع / احتياط» box (w19).
        await tester.tap(find.byKey(const ValueKey('money-budget-reserve')));
        await tester.pumpAndSettle();
        final total = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('money-budget-total')),
            matching: find.byType(EditableText),
          ),
        );
        expect(total.controller.text, '1,000,000');
        await tester.tap(find.byKey(const ValueKey('money-budget-total-done')));
        await tester.pumpAndSettle();
        final categoryName = find.byKey(
          const ValueKey('money-budget-category-category-1'),
        );
        await tester.scrollUntilVisible(
          categoryName,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('القاعات'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('budget-only save sends no synthetic category rows', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
        noBudget: true,
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);
      harness.router.push(AppRouter.moneyBudget(_planId));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('money-budget-category-name-0')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('money-budget-reserve')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('money-budget-total')),
        '2500000',
      );
      await tester.tap(find.byKey(const ValueKey('money-budget-total-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-budget-save')));
      await tester.pumpAndSettle();

      expect(harness.api.savedTotalBudget, '2500000');
      expect(harness.api.savedCategoryCount, 0);
      expect(harness.api.replaceBudgetCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty budget form cannot submit a no-op write', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyBudget(_planId),
        noBudget: true,
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      await tester.tap(find.byKey(const ValueKey('money-budget-save')));
      await tester.pump();

      final noOpError = find.text('حدد ميزانية أو أضف بند قبل الحفظ');
      await tester.scrollUntilVisible(
        noOpError,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(noOpError, findsOneWidget);
      expect(harness.api.replaceBudgetCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'an item share is changed in its sheet and the reserve follows (w19)',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.moneyBudget(_planId),
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        // 1 million, 700 thousand of it given to the halls: 300 left.
        final reserve = find.byKey(const ValueKey('money-budget-reserve'));
        expect(
          find.descendant(of: reserve, matching: find.textContaining('300')),
          findsOneWidget,
        );
        // The row shows the share as an amount, not a box to type in.
        const row = ValueKey('money-budget-category-category-1');
        await tester.scrollUntilVisible(
          find.byKey(row),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.descendant(
            of: find.byKey(row),
            matching: find.byType(EditableText),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(row),
            matching: find.textContaining('700'),
          ),
          findsOneWidget,
        );
        // gaps_b vAllocate: 15 bold name, 12.5 label over a 20 figure.
        expect(
          tester.widget<Text>(find.text('القاعات')).style?.fontSize,
          JourneyType.body,
        );
        expect(
          tester
              .widget<Text>(
                find.descendant(of: reserve, matching: find.text('موزّع')),
              )
              .style
              ?.fontSize,
          JourneyType.label,
        );
        await tester.tap(find.byKey(row));
        await tester.pumpAndSettle();
        final share = find.byKey(
          const ValueKey('money-budget-share-category-1'),
        );
        await tester.enterText(share, '400000');
        await tester.pump();
        // Below the 500 thousand already agreed: flagged on the row.
        expect(find.textContaining('اتفقت عليه بـ'), findsOneWidget);
        await tester.enterText(share, '900000');
        await tester.pump();
        expect(find.textContaining('اتفقت عليه بـ'), findsNothing);
        // 1 million with 900 thousand given out: 100 thousand left.
        expect(
          find.descendant(of: reserve, matching: find.textContaining('100')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('money-budget-share-done')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('money-budget-save')));
        await tester.pumpAndSettle();

        expect(harness.api.savedTotalBudget, '1000000');
        expect(harness.api.savedAllocations, {'category-1': '900000'});
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('budget delegates category creation to its focused screen', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyBudget(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.byType(MoneyBudgetScreen), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      // w19: the budget is a box over the items, not a large field.
      expect(find.byKey(const ValueKey('money-budget-total')), findsNothing);
      expect(
        find.byKey(const ValueKey('money-budget-reserve')),
        findsOneWidget,
      );
      final addCategory = find.byKey(
        const ValueKey('money-budget-add-category'),
      );
      await tester.dragUntilVisible(
        addCategory,
        find.byType(ListView),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(addCategory, findsOneWidget);
      expect(find.text('أضف بند'), findsOneWidget);
      // «أضف بند» sits under the items it adds to.
      expect(
        tester.getTopLeft(addCategory).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('money-budget-category-category-1')),
              )
              .dy,
        ),
      );
      await tester.tap(addCategory);
      await tester.pumpAndSettle();

      expect(harness.currentLocation, AppRouter.moneyCategoryCreate(_planId));
      expect(find.byType(BudgetCategoryFormScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('money-category-form-name')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('category allocation cannot exceed the remaining budget', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyCategoryCreate(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      await tester.enterText(
        find.byKey(const ValueKey('money-category-form-name')),
        'التصوير',
      );
      await tester.enterText(
        find.byKey(const ValueKey('money-category-form-amount')),
        '400000',
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pump();

      expect(find.textContaining('أكثر من الباقي في ميزانيتك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('owner cost form is complete and overflow-safe', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyCostCreate(
          _planId,
          categoryId: 'category-1',
        ),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      // c10: the item, who it is with, how much, and how it is paid.
      expect(find.byType(CostFormScreen), findsOneWidget);
      expect(find.text('اتفاق جديد'), findsOneWidget);
      expect(find.text('البند'), findsOneWidget);
      expect(find.text('مع مين؟'), findsOneWidget);
      expect(find.text('بكم اتفقت؟'), findsOneWidget);
      expect(find.text('حفظ الاتفاق'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('كيف بتدفع؟'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('كيف بتدفع؟'), findsOneWidget);
      _expectRtl(tester, find.byType(CostFormScreen));
      expect(tester.takeException(), isNull);

      harness.router.go(AppRouter.moneyCategoryCreate(_planId));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetCategoryFormScreen), findsOneWidget);
      // c09: the item's name and roughly what it gets.
      expect(find.text('بند جديد'), findsOneWidget);
      expect(find.text('اسم البند'), findsOneWidget);
      expect(find.text('كم تخصص له تقريبًا؟'), findsOneWidget);
      expect(find.text('أضف البند'), findsOneWidget);
      _expectRtl(tester, find.byType(BudgetCategoryFormScreen));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cost form saves an Aarast provider without external party', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);
      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
        extra: const CostDraftIntent(
          providerId: 'provider-1',
          providerName: 'قاعة السعادة',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cost-provider-card')), findsOneWidget);
      expect(find.text('قاعة السعادة'), findsWidgets);
      await _submitCostForm(tester, title: 'حجز القاعة', amount: '500000');

      expect(harness.api.createdProviderId, 'provider-1');
      expect(harness.api.createdPartyName, isNull);
      expect(harness.api.createdPartyPhone, isNull);
    });

    testWidgets('cost form saves an external provider without providerId', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);
      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('cost-party-external')),
      );
      await _enterVisible(
        tester,
        find.byKey(const ValueKey('cost-party-name')),
        'محل الورد',
      );
      await _enterVisible(
        tester,
        find.byKey(const ValueKey('cost-party-phone')),
        '777123456',
      );
      await _submitCostForm(tester, title: 'تنسيق الورد', amount: '90000');

      expect(harness.api.createdProviderId, isNull);
      expect(harness.api.createdPartyName, 'محل الورد');
      expect(harness.api.createdPartyPhone, '777123456');
    });

    testWidgets('cost form saves without any provider context', (tester) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);
      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('cost-party-none')), findsOneWidget);
      await _submitCostForm(tester, title: 'رسوم إضافية', amount: '30000');

      expect(harness.api.createdProviderId, isNull);
      expect(harness.api.createdPartyName, isNull);
      expect(harness.api.createdPartyPhone, isNull);
      expect(harness.api.createdInitialPayment, isNull);
      expect(harness.api.createdSchedules, isEmpty);
    });

    testWidgets('a deposit today and monthly payments after it (c10)', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);
      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
      );
      await tester.pumpAndSettle();

      await _enterVisible(
        tester,
        find.byKey(const Key('cost-total-amount')),
        '400000',
      );
      // A deposit plan without the day of the rest saves nothing.
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('cost-plan-depositRest')),
      );
      await _enterVisible(
        tester,
        find.byKey(const ValueKey('cost-plan-deposit')),
        '100000',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-save')));
      await tester.pumpAndSettle();
      expect(harness.api.createdTotalAmount, isNull);

      // Two monthly payments after the deposit.
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('cost-plan-instalments')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('cost-plan-count-2')),
      );
      expect(find.byKey(const ValueKey('cost-plan-preview')), findsOneWidget);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cost-save')));
      await tester.pumpAndSettle();

      expect(harness.api.createdTotalAmount, '400000');
      expect(harness.api.createdInitialPayment, '100000');
      expect(harness.api.createdSchedules.map((line) => line.amount), [
        '150000',
        '150000',
      ]);
      expect(harness.api.createdSchedules.map((line) => line.note), [
        'الدفعة 1',
        'الدفعة 2',
      ]);
      final dates = harness.api.createdSchedules.map((line) => line.dueDate);
      expect(
        dates.last.difference(dates.first).inDays,
        inInclusiveRange(28, 31),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'inline category creation returns and selects the new category',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.money(_planId),
          noBudget: true,
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        harness.router.push(AppRouter.moneyCostCreate(_planId));
        await tester.pumpAndSettle();
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('cost-category-create')),
        );

        await tester.enterText(
          find.byKey(const ValueKey('money-category-form-name')),
          'التصوير',
        );
        await tester.tap(find.byKey(const ValueKey('category-save')));
        await tester.pumpAndSettle();

        expect(find.byType(CostFormScreen), findsOneWidget);
        final created = tester.widget<JourneyChip>(
          find.byKey(const ValueKey('cost-category-created-category-1')),
        );
        expect(created.label, 'التصوير');
        expect(created.selected, isTrue);
        await _submitCostForm(tester, title: 'جلسة تصوير', amount: '300000');

        expect(harness.api.createdBudgetCategoryId, 'created-category-1');
        expect(harness.api.lastCreatedCategoryId, 'created-category-1');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'quote currency waits for successful money load before resolving',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.moneyCostCreate(
            _planId,
            categoryId: 'category-1',
          ),
          currency: 'SAR',
          failSummaryLoads: 1,
        );
        addTearDown(harness.dispose);
        harness.router.go(
          AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
          extra: const CostDraftIntent(
            title: 'عرض قاعة سعودي',
            totalAmount: '2500',
            providerId: 'provider-1',
            providerName: 'قاعة السعادة',
            quoteOfferId: 'offer-sar-retry',
            currency: 'SAR',
          ),
        );
        await _pumpProduct(tester, harness.app);

        expect(find.text('تعذر التحقق من الصلاحيات'), findsOneWidget);
        expect(find.textContaining('العرض بعملة'), findsNothing);
        await tester.tap(find.text('حاول مرة أخرى'));
        await tester.pumpAndSettle();

        // Same currency once loaded: the quote's amount stays agreed.
        final quoteTotal = find.byKey(const ValueKey('cost-quote-total'));
        await tester.scrollUntilVisible(
          quoteTotal,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('2,500 ر.س'), findsOneWidget);
        expect(find.byKey(const Key('cost-total-amount')), findsNothing);
        expect(find.textContaining('العرض بعملة'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cost list separates a load error from an empty result', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.moneyCosts(_planId),
        noBudget: true,
        failSummaryLoads: 1,
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.text('تعذر تحميل التكاليف'), findsOneWidget);
      expect(find.text('لا توجد نتائج'), findsNothing);
      await tester.tap(find.text('حاول مرة أخرى'));
      await tester.pumpAndSettle();

      expect(find.text('تعذر تحميل التكاليف'), findsNothing);
      expect(find.text('لا توجد نتائج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepted quote with a different currency cannot mix amounts', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
        extra: const CostDraftIntent(
          title: 'عرض قاعة بالريال السعودي',
          totalAmount: '2500',
          providerId: 'provider-1',
          providerName: 'قاعة السعادة',
          quoteOfferId: 'offer-sar',
          currency: 'SAR',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('العرض بعملة ريال سعودي'), findsOneWidget);
      // The amount is typed again in the plan's currency.
      final amountField = find.byKey(const Key('cost-total-amount'));
      await tester.scrollUntilVisible(
        amountField,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(amountField, findsOneWidget);
      final editable = tester.widget<EditableText>(
        find.descendant(of: amountField, matching: find.byType(EditableText)),
      );
      expect(editable.controller.text, isEmpty);
      expect(
        find.descendant(of: amountField, matching: find.text('ر.ي')),
        findsOneWidget,
      );
      await _submitCostForm(
        tester,
        title: 'عرض قاعة بالريال السعودي',
        amount: '170000',
      );

      expect(harness.api.createdTotalAmount, '170000');
      expect(harness.api.createdProviderId, 'provider-1');
      expect(harness.api.createdQuoteOfferId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepted quote in plan currency keeps its agreed amount', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
        extra: const CostDraftIntent(
          title: 'عرض القاعة المقبول',
          totalAmount: '250000',
          providerId: 'provider-1',
          providerName: 'قاعة السعادة',
          quoteOfferId: 'offer-yer',
          currency: 'YER',
        ),
      );
      await tester.pumpAndSettle();

      final quoteTotal = find.byKey(const ValueKey('cost-quote-total'));
      await tester.scrollUntilVisible(
        quoteTotal,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('250,000 ر.ي'), findsOneWidget);
      expect(find.text('مثبت من العرض اللي وافقت عليه'), findsOneWidget);
      expect(find.byKey(const Key('cost-total-amount')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'read-only member sees money but cannot enter budget or cost writes',
      (tester) async {
        final harness = _MoneyProductHarness.viewer(
          initialLocation: AppRouter.money(_planId),
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        expect(find.byType(MoneyOverviewScreen), findsOneWidget);
        expect(find.byTooltip('إدارة الميزانية'), findsNothing);
        expect(
          find.byKey(const ValueKey('money-settings-menu')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('money-destination-costs')),
          findsNothing,
        );
        // c01: the costs live under «البنود».
        await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
        await tester.pumpAndSettle();
        expect(find.text('حجز القاعة'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('money-add-cost-primary')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        harness.router.go(AppRouter.moneyBudget(_planId));
        await tester.pumpAndSettle();
        expect(find.byType(MoneyBudgetScreen), findsOneWidget);
        expect(find.text('العرض فقط'), findsOneWidget);
        expect(find.text('حفظ الميزانية'), findsNothing);
        expect(tester.takeException(), isNull);

        harness.router.go(AppRouter.moneyCostCreate(_planId));
        await tester.pumpAndSettle();
        expect(find.byType(CostFormScreen), findsOneWidget);
        expect(find.text('العرض فقط'), findsOneWidget);
        expect(find.text('حفظ الاتفاق'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _openMoneySettings(WidgetTester tester) async {
  final settings = find.byKey(const ValueKey('money-settings-menu'));
  await tester.scrollUntilVisible(
    settings,
    -220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(settings);
  await tester.pumpAndSettle();
  await tester.tap(settings);
  await tester.pumpAndSettle();
}

class _MoneyProductHarness {
  _MoneyProductHarness._({
    required this.api,
    required this.provider,
    required this.router,
  });

  factory _MoneyProductHarness.owner({
    required String initialLocation,
    bool noBudget = false,
    int failSummaryLoads = 0,
    String currency = 'YER',
    String personaCode = 'GROOM',
  }) {
    final api = _MoneyProductApi(
      noBudget: noBudget,
      failSummaryLoads: failSummaryLoads,
      currency: currency,
    );
    final provider = FinanceProvider(api);
    return _MoneyProductHarness._from(
      api: api,
      provider: provider,
      initialLocation: initialLocation,
      personaCode: personaCode,
    );
  }

  factory _MoneyProductHarness.viewer({required String initialLocation}) {
    final api = _MoneyProductApi();
    final provider = FinanceProvider(
      api,
      permissionsApi: _MoneyPermissionsApi(
        const PlanAccessPermissions(
          weddingPlanId: _planId,
          isOwner: false,
          canViewMoney: true,
          canManageMoney: false,
        ),
      ),
    );
    return _MoneyProductHarness._from(
      api: api,
      provider: provider,
      initialLocation: initialLocation,
      personaCode: 'GROOM',
    );
  }

  factory _MoneyProductHarness._from({
    required _MoneyProductApi api,
    required FinanceProvider provider,
    required String initialLocation,
    required String personaCode,
  }) {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/wedding-plans/:id/money',
          builder: (context, state) => MoneyOverviewScreen(
            weddingPlanId: state.pathParameters['id']!,
            personaCode: personaCode,
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/budget',
          builder: (context, state) =>
              MoneyBudgetScreen(weddingPlanId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/schedules',
          builder: (context, state) => PaymentSchedulesScreen(
            weddingPlanId: state.pathParameters['id']!,
            costId: state.uri.queryParameters['costId'],
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/categories/create',
          builder: (context, state) => BudgetCategoryFormScreen(
            weddingPlanId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/categories/:categoryId',
          builder: (context, state) => BudgetCategoryDetailsScreen(
            weddingPlanId: state.pathParameters['id']!,
            categoryId: state.pathParameters['categoryId']!,
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/costs',
          builder: (context, state) =>
              CostsScreen(weddingPlanId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/costs/create',
          builder: (context, state) => CostFormScreen(
            weddingPlanId: state.pathParameters['id']!,
            intent: state.extra is CostDraftIntent
                ? state.extra! as CostDraftIntent
                : null,
            initialCategoryId: state.uri.queryParameters['categoryId'],
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/costs/:costId/schedules/:scheduleId',
          builder: (context, state) => PaymentScheduleDetailsScreen(
            weddingPlanId: state.pathParameters['id']!,
            costId: state.pathParameters['costId']!,
            scheduleId: state.pathParameters['scheduleId']!,
          ),
        ),
        GoRoute(
          path: '/wedding-plans/:id/money/costs/:costId',
          builder: (context, state) => CostDetailsScreen(
            weddingPlanId: state.pathParameters['id']!,
            costId: state.pathParameters['costId']!,
          ),
        ),
      ],
    );
    return _MoneyProductHarness._(api: api, provider: provider, router: router);
  }

  final _MoneyProductApi api;
  final FinanceProvider provider;
  final GoRouter router;

  String get currentLocation => router.state.uri.toString();

  Widget get app => ChangeNotifierProvider<FinanceProvider>.value(
    value: provider,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );

  void dispose() {
    router.dispose();
    provider.dispose();
  }
}

class _MoneyProductApi extends FinanceApi {
  _MoneyProductApi({
    this.noBudget = false,
    this.failSummaryLoads = 0,
    this.currency = 'YER',
  }) : super(ApiClient(tokenProvider: () async => null));

  final bool noBudget;
  int failSummaryLoads;
  final String currency;
  final now = DateTime.utc(2026, 7, 14, 12);
  String? createdTotalAmount;
  String? createdProviderId;
  String? createdQuoteOfferId;
  String? createdBudgetCategoryId;
  String? createdPartyName;
  String? createdPartyPhone;
  String? createdInitialPayment;
  final createdSchedules =
      <({String amount, DateTime dueDate, String? note})>[];
  String? savedTotalBudget;
  int? savedCategoryCount;
  Map<String, String?>? savedAllocations;
  int replaceBudgetCalls = 0;
  String? lastCreatedCategoryId;
  int _categorySequence = 0;

  WeddingCost get cost => WeddingCost(
    id: 'cost-1',
    weddingPlanId: _planId,
    budgetCategoryId: 'category-1',
    title: 'حجز القاعة',
    totalAmount: '500000',
    paidAmount: '100000',
    remainingAmount: '400000',
    status: 'PARTIALLY_PAID',
    providerId: 'provider-1',
    providerName: 'قاعة السعادة',
    paymentsCount: 1,
    createdAt: now.subtract(const Duration(days: 20)),
    updatedAt: now,
  );

  @override
  Future<WeddingCost> createCost({
    required String planId,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? initialPaymentAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    String? payer,
    String? payerName,
    DateTime? agreementDate,
    String? note,
    bool isPrivate = false,
  }) async {
    createdTotalAmount = totalAmount;
    createdProviderId = providerId;
    createdQuoteOfferId = quoteOfferId;
    createdBudgetCategoryId = budgetCategoryId;
    createdPartyName = partyName;
    createdPartyPhone = partyPhone;
    createdInitialPayment = initialPaymentAmount;
    return WeddingCost(
      id: 'created-cost',
      weddingPlanId: planId,
      budgetCategoryId: budgetCategoryId,
      title: title,
      totalAmount: totalAmount,
      paidAmount: initialPaymentAmount ?? '0',
      remainingAmount: totalAmount,
      status: 'OPEN',
      providerId: providerId,
      quoteOfferId: quoteOfferId,
      partyName: partyName,
      partyPhone: partyPhone,
      agreementDate: agreementDate,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<PaymentSchedule> createSchedule({
    required WeddingCost cost,
    required String amount,
    required DateTime dueDate,
    String? note,
  }) async {
    createdSchedules.add((amount: amount, dueDate: dueDate, note: note));
    return PaymentSchedule(
      id: 'created-schedule-${createdSchedules.length}',
      costId: cost.id,
      weddingPlanId: cost.weddingPlanId,
      amount: amount,
      dueDate: dueDate,
      status: 'PENDING',
      costTitle: cost.title,
      note: note,
    );
  }

  CostPayment get payment => CostPayment(
    id: 'payment-1',
    weddingPlanId: _planId,
    costId: 'cost-1',
    amount: '100000',
    paidAt: now.subtract(const Duration(days: 5)),
    costTitle: 'حجز القاعة',
  );

  PaymentSchedule get schedule => PaymentSchedule(
    id: 'schedule-1',
    weddingPlanId: _planId,
    costId: 'cost-1',
    amount: '200000',
    dueDate: now.add(const Duration(days: 10)),
    status: 'PENDING',
    costTitle: 'دفعة حجز القاعة',
  );

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    if (failSummaryLoads > 0) {
      failSummaryLoads -= 1;
      throw const ApiException('تعذر تحميل المال للاختبار.');
    }
    if (noBudget) return MoneySummary.empty(planId, currency: currency);
    return MoneySummary(
      planId: planId,
      currency: currency,
      budget: const MoneyBudgetSummary(
        total: '1000000',
        allocated: '700000',
        unallocated: '300000',
        confirmedCost: '500000',
        remaining: '500000',
      ),
      costs: const MoneyCostsSummary(
        total: '500000',
        paid: '100000',
        outstanding: '400000',
        count: 1,
      ),
      paymentSchedules: MoneySchedulesSummary(upcomingCount: 1, next: schedule),
      categories: const [
        MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'القاعات',
          allocatedAmount: '700000',
          confirmedCost: '500000',
          paid: '100000',
          outstanding: '400000',
          remainingAllocation: '200000',
          costsCount: 1,
        ),
      ],
      permissions: const MoneyPermissions(
        canViewMoney: true,
        canManageMoney: true,
      ),
    );
  }

  @override
  Future<MoneyBudgetReplaceResult> replaceMoneyBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
  }) async {
    replaceBudgetCalls += 1;
    savedTotalBudget = totalBudget;
    savedCategoryCount = categories.length;
    savedAllocations = {
      for (final item in categories) item.id ?? item.name: item.allocatedAmount,
    };
    final idMap = <String, String>{};
    final savedCategories = <BudgetCategory>[];
    for (final category in categories) {
      final id = category.id ?? 'created-category-${++_categorySequence}';
      if (category.id == null) lastCreatedCategoryId = id;
      savedCategories.add(
        BudgetCategory(
          id: id,
          weddingPlanId: planId,
          name: category.name,
          allocatedAmount: category.allocatedAmount,
          remainingAllocation: category.allocatedAmount,
        ),
      );
    }
    final summary = MoneySummary(
      planId: planId,
      currency: currency,
      budget: MoneyBudgetSummary(total: totalBudget),
      categories: [
        for (final category in savedCategories)
          MoneyCategorySummary(
            categoryId: category.id,
            name: category.name,
            allocatedAmount: category.allocatedAmount,
            remainingAllocation: category.allocatedAmount,
          ),
      ],
      permissions: const MoneyPermissions(
        canViewMoney: true,
        canManageMoney: true,
      ),
    );
    return MoneyBudgetReplaceResult(
      summary: summary,
      categories: savedCategories,
      idMap: idMap,
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
  }) async {
    final items = noBudget ? const <WeddingCost>[] : [cost];
    return FinancePage(
      items: items,
      page: page,
      pageSize: limit,
      total: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async {
    final items = noBudget ? const <CostPayment>[] : [payment];
    return FinancePage(
      items: items,
      page: page,
      pageSize: limit,
      total: items.length,
      totalPages: 1,
    );
  }

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async =>
      noBudget ? const [] : [schedule];

  @override
  Future<List<CostPayment>> getCostPayments(
    String costId, {
    String? planId,
  }) async => noBudget ? const [] : [payment];

  @override
  Future<List<PaymentSchedule>> getCostSchedules(
    String costId, {
    String? planId,
  }) async => noBudget ? const [] : [schedule];
}

class _MoneyPermissionsApi extends SharingApi {
  _MoneyPermissionsApi(this.permissions)
    : super(ApiClient(tokenProvider: () async => null));

  final PlanAccessPermissions permissions;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String planId) async =>
      permissions;
}

Future<void> _submitCostForm(
  WidgetTester tester, {
  required String title,
  required String amount,
}) async {
  await _enterVisible(
    tester,
    find.byKey(const Key('cost-total-amount')),
    amount,
  );
  await _enterVisible(tester, find.byKey(const ValueKey('cost-title')), title);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  // «حفظ الاتفاق» stays pinned under the fields.
  await tester.tap(find.byKey(const ValueKey('cost-save')));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<void> _pumpProduct(WidgetTester tester, Widget app) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 760);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void _expectRtl(WidgetTester tester, Finder finder) {
  expect(Directionality.of(tester.element(finder.first)), TextDirection.rtl);
}
