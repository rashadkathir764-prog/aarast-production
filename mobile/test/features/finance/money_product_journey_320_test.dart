import 'dart:async';

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
import 'package:aarast_mobile/features/finance/screens/money_budget_screen.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const _planId = 'plan-money-product';

void main() {
  group('canonical money product journey at 320px RTL and 1.3 scale', () {
    // The server leaves the shortfall empty before any source is recorded:
    // that is not knowing, never «يغطون اتفاقاتك».
    testWidgets('no funding source yet claims no coverage', (tester) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
        funding: const MoneyFundingSummary(),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.byKey(const ValueKey('money-cover-unknown')), findsOneWidget);
      expect(find.textContaining('يغطون'), findsNothing);
      expect(find.textContaining(' معك '), findsNothing);
    });

    testWidgets('owner opens real schedule, category, and cost destinations', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.byType(MoneyOverviewScreen), findsOneWidget);
      // D102: what is on him first, then his coming dues.
      expect(find.byKey(const ValueKey('money-share-hero')), findsOneWidget);
      const dueKey = ValueKey('money-coming-due-schedule-1');
      await tester.scrollUntilVisible(
        find.byKey(dueKey),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      // An undated rest is not a coming due.
      expect(
        find.byKey(const ValueKey('money-coming-due-cost-1')),
        findsNothing,
      );
      // The whole picture opens «البنود», where the costs live (c01).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('money-whole-cost')),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('money-whole-cost')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-whole-cost')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('money-item-category-1')),
        findsOneWidget,
      );
      _expectRtl(tester, find.byType(MoneyOverviewScreen));
      expect(tester.takeException(), isNull);

      // A coming due is paid on its own page (D106), by its id.
      await tester.tap(find.byKey(const ValueKey('journey-tab-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(dueKey),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(dueKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(dueKey));
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneySchedulePay(_planId, 'cost-1', 'schedule-1'),
      );
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
      // D102: an item opens its page; its agreement is one press on.
      const itemKey = ValueKey('money-item-category-1');
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
        AppRouter.moneyCategoryDetails(_planId, 'category-1'),
      );
      expect(find.byType(BudgetCategoryDetailsScreen), findsOneWidget);
      const agreementKey = ValueKey('category-cost-cost-1');
      await tester.scrollUntilVisible(
        find.byKey(agreementKey),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(agreementKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(agreementKey));
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyCostDetails(_planId, 'cost-1'),
      );
      expect(find.byType(CostDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Rule zero: the old starter («جهّز ميزانية عرسك») is not in the
    // prototype. An empty plan opens on «البنود», and the budget (w19) is
    // one press away in the money menu.
    testWidgets('a new groom opens on «البنود» and reaches the budget', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
        noBudget: true,
        personaCode: 'GROOM',
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.byKey(const ValueKey('money-starter-setup')), findsNothing);
      expect(find.text('جهّز ميزانية عرسك'), findsNothing);
      expect(find.text('ما في بنود بعد'), findsOneWidget);
      expect(find.text('أضف أول بند'), findsOneWidget);
      expect(find.text('فستان العروسة'), findsNothing);
      expect(find.byKey(const ValueKey('money-budget-setup')), findsNothing);
      expect(tester.takeException(), isNull);

      await _openMoneySettings(tester);
      await tester.tap(find.byKey(const ValueKey('money-settings-budget')));
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
    });

    testWidgets(
      'budget waits for a successful retry before hydrating persisted data',
      (tester) async {
        final harness = _MoneyProductHarness.owner(
          initialLocation: AppRouter.moneyBudget(_planId),
          failSummaryLoads: 1,
        );
        addTearDown(harness.dispose);
        await _pumpProduct(tester, harness.app);

        expect(find.text('ما قدرنا نتأكد من صلاحيتك'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('money-budget-reserve')),
          findsNothing,
        );

        await tester.tap(find.text('جرّب مرة ثانية'));
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

    // D109: an item's estimate is free; passing the budget is said under
    // the field, and the item is saved with it.
    testWidgets('an item estimate may pass the budget, said, not refused', (
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
      await tester.pump();
      // The budget is 1,000,000 and the items expect 500,000 already.
      expect(find.textContaining('فوق الميزانية'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('money-category-form-amount')),
        '900000',
      );
      await tester.pump();
      expect(
        find.textContaining('تصير بنود العرس فوق الميزانية بـ400,000'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('category-save')));
      await tester.pumpAndSettle();

      // Saved: the item, and its estimate; no share was asked for.
      expect(harness.api.lastCreatedCategoryId, isNotNull);
      expect(harness.api.savedAllocations?['التصوير'], isNull);
      expect(
        harness.api.savedEstimates[harness.api.lastCreatedCategoryId],
        '900000',
      );
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
      expect(find.text('كم تتوقع يكلف؟'), findsOneWidget);
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

    // J1-08: two quick taps on «حفظ الاتفاق» record one agreement.
    testWidgets('two quick taps on save record the agreement once', (
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
        '30000',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      // A slow network: the second tap lands while the first is in flight.
      final gate = Completer<void>();
      harness.api.createCostGate = gate;
      final save = find.byKey(const ValueKey('cost-save'));
      await tester.tap(save);
      await tester.tap(save);
      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.api.createCostCalls, 1);
      expect(tester.takeException(), isNull);
    });

    // J1-09: the server takes a title of 160 at most; the field stops there.
    testWidgets('the agreement name stops at the server limit', (tester) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);
      harness.router.push(
        AppRouter.moneyCostCreate(_planId, categoryId: 'category-1'),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('cost-title')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, 160);
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
      // RA-MO-174: without an agreement day the deposit is today's.
      expect(find.textContaining('العربون · اليوم'), findsOneWidget);
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

        expect(find.text('ما قدرنا نتأكد من صلاحيتك'), findsOneWidget);
        expect(find.textContaining('العرض بعملة'), findsNothing);
        await tester.tap(find.text('جرّب مرة ثانية'));
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

    // The old «كل التكاليف» page is gone: the items live on «البنود».
    testWidgets('«البنود» separates a load error from an empty result', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
        noBudget: true,
        failSummaryLoads: 1,
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(find.text('ما قدرنا نجيبها'), findsOneWidget);
      expect(find.text('ما في بنود بعد'), findsNothing);
      await tester.tap(find.text('جرّب مرة ثانية'));
      await tester.pumpAndSettle();

      expect(find.text('ما قدرنا نجيبها'), findsNothing);
      expect(find.text('ما في بنود بعد'), findsOneWidget);
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

    // R5: one thing has one name across the tabs.
    testWidgets('an agreement reads by its item, not by who it is with', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('القاعات'), findsWidgets);
      expect(find.text('حجز القاعة'), findsNothing);
    });

    // R16: money and the providers tab tell the same story.
    testWidgets('an item with offers says so and opens them', (tester) async {
      final harness = _MoneyProductHarness.owner(
        initialLocation: AppRouter.money(_planId),
        photoItem: true,
      );
      addTearDown(harness.dispose);
      final market = _OffersMarketplace();
      await _pumpProduct(
        tester,
        ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
          value: market,
          child: harness.app,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
      await tester.pumpAndSettle();
      expect(market.loads, 1);
      expect(find.text('وصلك عرض'), findsOneWidget);

      // The item opens its page, which says where its offers are.
      await tester.scrollUntilVisible(
        find.text('التصوير'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('التصوير'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التصوير'));
      await tester.pumpAndSettle();
      expect(
        harness.currentLocation,
        AppRouter.moneyCategoryDetails(_planId, 'category-2'),
      );
      final offers = find.byKey(const ValueKey('item-market'));
      expect(
        find.descendant(of: offers, matching: find.textContaining('وصلك عرض')),
        findsOneWidget,
      );
      await tester.ensureVisible(offers);
      await tester.pumpAndSettle();
      await tester.tap(offers);
      await tester.pumpAndSettle();
      expect(harness.currentLocation, contains('/providers/requests'));
      expect(harness.currentLocation, contains('item=category-2'));
    });

    // R20: the server keeps the budget and its items to the plan's owner, so
    // a member who manages money is not offered what it refuses.
    testWidgets('a money manager records agreements, not the budget', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.moneyManager(
        initialLocation: AppRouter.money(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(harness.provider.canManageMoney, isTrue);
      expect(harness.provider.canManageBudget, isFalse);
      await tester.tap(find.byKey(const ValueKey('journey-tab-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('money-empty-add-cost')), findsNothing);
    });

    testWidgets('the budget page tells a money manager it is the owner\'s', (
      tester,
    ) async {
      final harness = _MoneyProductHarness.moneyManager(
        initialLocation: AppRouter.moneyBudget(_planId),
      );
      addTearDown(harness.dispose);
      await _pumpProduct(tester, harness.app);

      expect(
        find.text('الميزانية والبنود يعدّلها صاحب الخطة.'),
        findsOneWidget,
      );
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
        expect(find.text('القاعات'), findsWidgets);
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
    MoneyFundingSummary? funding,
    bool photoItem = false,
  }) {
    final api = _MoneyProductApi(
      noBudget: noBudget,
      funding: funding,
      photoItem: photoItem,
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

  factory _MoneyProductHarness.moneyManager({required String initialLocation}) {
    final api = _MoneyProductApi();
    final provider = FinanceProvider(
      api,
      permissionsApi: _MoneyPermissionsApi(
        const PlanAccessPermissions(
          weddingPlanId: _planId,
          isOwner: false,
          canViewMoney: true,
          canManageMoney: true,
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
          path: '/wedding-plans/:id/providers/requests',
          builder: (context, state) => const Text('طلبات البند'),
        ),
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

class _OffersMarketplace extends ProviderMarketplaceProvider {
  _OffersMarketplace()
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  int loads = 0;

  @override
  Future<void> loadScopedQuoteRequests() async => loads += 1;

  @override
  List<QuoteRequest> get quoteRequests => [
    QuoteRequest(
      id: 'quote-1',
      providerId: 'provider-1',
      weddingPlanId: _planId,
      status: 'RECEIVED',
      lifecycleStatus: 'RECEIVED',
      service: const MarketplaceService(
        id: 'service-1',
        providerId: 'provider-1',
        title: 'صور وفيديو',
        category: ProviderCategory(id: 'cat-photo', nameAr: 'تصوير'),
        isActive: true,
      ),
      offers: const [
        QuoteOffer(
          id: 'offer-1',
          status: 'PENDING',
          amount: '550000',
          currency: 'YER',
        ),
      ],
    ),
  ];
}

class _MoneyProductApi extends FinanceApi {
  _MoneyProductApi({
    this.noBudget = false,
    this.failSummaryLoads = 0,
    this.currency = 'YER',
    this.funding,
    this.photoItem = false,
  }) : super(ApiClient(tokenProvider: () async => null));

  final bool noBudget;
  final bool photoItem;
  final MoneyFundingSummary? funding;
  int failSummaryLoads;
  final String currency;
  final now = DateTime.utc(2026, 7, 14, 12);
  int createCostCalls = 0;

  /// When set, the agreement's write waits for it (a slow network).
  Completer<void>? createCostGate;
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

  /// D109: each item estimate saved, by item.
  final savedEstimates = <String, String?>{};

  @override
  Future<BudgetCategory> setItemEstimate({
    required BudgetCategory category,
    required String? estimatedAmount,
  }) async {
    savedEstimates[category.id] = estimatedAmount;
    return category;
  }

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
    bool isExpense = false,
    String? estimateCover,
    String? estimatePart,
  }) async {
    createCostCalls += 1;
    await createCostGate?.future;
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
      funding: funding,
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
      // D105: the wedding's items expect their one agreement.
      expected: const MoneyExpected(
        wedding: MoneyExpectedTotals(agreed: '500000', expected: '500000'),
        total: '500000',
        budgetLeft: '500000',
      ),
      // D102: what is left, by whom, and each thing still to pay, as the
      // server sends them.
      outstanding: const MoneyOutstanding(total: '400000', owner: '400000'),
      obligations: [
        MoneyObligation(
          kind: MoneyObligationKind.due,
          id: 'schedule-1',
          weddingCostId: 'cost-1',
          budgetCategoryId: 'category-1',
          title: 'حجز القاعة',
          amount: '200000',
          scheduledAmount: '200000',
          dueDate: schedule.dueDate,
        ),
        const MoneyObligation(
          kind: MoneyObligationKind.undated,
          id: 'cost-1',
          weddingCostId: 'cost-1',
          budgetCategoryId: 'category-1',
          title: 'حجز القاعة',
          amount: '200000',
        ),
      ],
      categories: [
        const MoneyCategorySummary(
          categoryId: 'category-1',
          name: 'القاعات',
          allocatedAmount: '700000',
          confirmedCost: '500000',
          paid: '100000',
          outstanding: '400000',
          remainingAllocation: '200000',
          costsCount: 1,
        ),
        if (photoItem)
          const MoneyCategorySummary(
            categoryId: 'category-2',
            name: 'التصوير',
            allocatedAmount: '300000',
            confirmedCost: '0',
            paid: '0',
            outstanding: '0',
            remainingAllocation: '300000',
            costsCount: 0,
            providerCategoryIds: ['cat-photo'],
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
    String? expectedBudgetVersion,
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
