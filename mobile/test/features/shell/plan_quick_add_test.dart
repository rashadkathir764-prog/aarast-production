// The plan's «+» (D33): where it shows, what it is called, what its sheet
// offers on each tab and in which order, and where each choice goes. Both
// shells and the home of a plan kept on the phone share these rules.

import 'package:aarast_mobile/core/experience_v3/aarast_journey_profile.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_quick_add.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

List<String> _labels(List<PlanQuickAction> actions) => [
  for (final action in actions) action.kind.labelFor(JourneyProfile.groom),
];

void main() {
  group('visibility', () {
    test('the same tabs in both shells', () {
      expect(shouldShowPlanQuickAdd(tabIndex: 0), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 1), isFalse);
      expect(shouldShowPlanQuickAdd(tabIndex: 1, canManageMoney: true), isTrue);
      expect(
        shouldShowPlanQuickAdd(
          tabIndex: 1,
          canManageMoney: true,
          isRootDestination: false,
        ),
        isFalse,
      );
      expect(shouldShowPlanQuickAdd(tabIndex: 2), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 3), isTrue);
      expect(shouldShowPlanQuickAdd(tabIndex: 4), isFalse);
    });

    test('w29 guests hide it while an account plan is offline', () {
      expect(
        shouldShowPlanQuickAdd(tabIndex: 3, guestsWaitForConnection: true),
        isFalse,
      );
      // The other tabs queue their writes, so they keep it.
      expect(
        shouldShowPlanQuickAdd(tabIndex: 2, guestsWaitForConnection: true),
        isTrue,
      );
      expect(
        shouldShowPlanQuickAdd(tabIndex: 0, guestsWaitForConnection: true),
        isTrue,
      );
    });

    test('each tab names its «+»', () {
      const groom = JourneyProfile.groom;
      expect(planQuickAddLabelForTab(0, groom), 'إضافة');
      expect(planQuickAddLabelForTab(1, groom), 'إضافة اتفاق');
      expect(planQuickAddLabelForTab(2, groom), 'إضافة مهمة');
      expect(planQuickAddLabelForTab(3, groom), 'إضافة ضيف');
      // The bride's guests are her women guests (JOURNEY_PROFILE.md).
      expect(planQuickAddLabelForTab(3, JourneyProfile.bride), 'إضافة ضيفة');
      expect(planQuickAddIconForTab(0), LucideIcons.plus);
      expect(planQuickAddIconForTab(1), LucideIcons.wallet);
      expect(planQuickAddIconForTab(2), LucideIcons.listPlus);
      expect(planQuickAddIconForTab(3), LucideIcons.userPlus);
    });

    test('the tasks and the guests add straight away', () {
      expect(planQuickAddDirectKind(2), PlanQuickAddKind.task);
      expect(planQuickAddDirectKind(3), PlanQuickAddKind.guest);
      expect(planQuickAddDirectKind(0), isNull);
      expect(planQuickAddDirectKind(1), isNull);
    });
  });

  group('actions', () {
    test('the home offers the canonical choices with stable labels', () {
      final actions = planQuickAddActions(
        planId: 'plan-home',
        tabIndex: 0,
        canManageMoney: true,
      );

      expect(_labels(actions), [
        'إضافة اتفاق',
        'إضافة مهمة',
        'إضافة ضيف',
        'طلب عرض سعر',
      ]);
      expect(actions.first.recommended, isTrue);
      expect(actions.skip(1).every((action) => !action.recommended), isTrue);
    });

    test('a new item is offered to the owner only (R20)', () {
      final actions = planQuickAddActions(
        planId: 'plan-member',
        tabIndex: 1,
        canManageMoney: true,
        canManageBudget: false,
      );

      expect(
        actions.map((action) => action.kind),
        isNot(contains(PlanQuickAddKind.category)),
      );
      expect(
        actions.map((action) => action.kind),
        contains(PlanQuickAddKind.cost),
      );
    });

    test('money offers additions but never manages the budget', () {
      expect(
        _labels(
          planQuickAddActions(
            planId: 'plan-money',
            tabIndex: 1,
            canManageMoney: true,
          ),
        ),
        ['إضافة اتفاق', 'إضافة بند'],
      );
      expect(
        _labels(
          planQuickAddActions(
            planId: 'plan-money',
            tabIndex: 1,
            canManageMoney: true,
            offerAgreementActions: true,
          ),
        ),
        ['إضافة اتفاق', 'تسجيل دفعة', 'إضافة موعد دفع', 'إضافة بند'],
      );
    });

    test('the first choice follows the tab', () {
      String first(int tab) => planQuickAddActions(
        planId: 'plan-order',
        tabIndex: tab,
        canManageMoney: true,
      ).first.kind.labelFor(JourneyProfile.groom);

      expect(first(1), 'إضافة اتفاق');
      expect(first(2), 'إضافة مهمة');
      expect(first(3), 'إضافة ضيف');
      expect(first(4), 'طلب عرض سعر');
    });

    test('each row takes its section colour', () {
      expect(PlanQuickAddKind.cost.section.name, 'money');
      expect(PlanQuickAddKind.payment.section.name, 'money');
      expect(PlanQuickAddKind.task.section.name, 'tasks');
      expect(PlanQuickAddKind.guest.section.name, 'guests');
      expect(PlanQuickAddKind.quote.section.name, 'providers');
    });

    test('never offers money choices without the right to manage money', () {
      for (final tab in [0, 1, 2, 3, 4]) {
        final kinds = planQuickAddActions(
          planId: 'shared-plan',
          tabIndex: tab,
          canManageMoney: false,
          offerAgreementActions: true,
        ).map((action) => action.kind);
        expect(kinds.where((kind) => kind.isMoney), isEmpty, reason: '$tab');
      }
    });
  });

  group('ranking', () {
    test('the plan state wins, then the last choice used comes up', () {
      final urgent = planQuickAddActions(
        planId: 'smart-plan',
        tabIndex: 0,
        canManageMoney: true,
        signals: const PlanQuickAddSignals(overdueTasks: 2, providerCount: 1),
      );
      expect(urgent.first.kind, PlanQuickAddKind.task);
      expect(urgent.first.recommended, isTrue);

      rememberPlanQuickAdd('recent-plan', PlanQuickAddKind.quote);
      final reordered = planQuickAddActions(
        planId: 'recent-plan',
        tabIndex: 0,
        canManageMoney: true,
        signals: const PlanQuickAddSignals(providerCount: 1),
      );
      expect(reordered.first.kind, PlanQuickAddKind.quote);
      expect(reordered.first.recommended, isTrue);
    });

    test('a payment due puts recording the payment first on the money tab', () {
      // Where «تسجيل دفعة» is offered it is what a due date asks for;
      // writing another agreement is not.
      final actions = planQuickAddActions(
        planId: 'due-money-plan',
        tabIndex: 1,
        canManageMoney: true,
        offerAgreementActions: true,
        signals: const PlanQuickAddSignals(
          duePaymentSchedules: 1,
          providerCount: 1,
        ),
      );
      expect(actions.first.kind, PlanQuickAddKind.payment);
      expect(actions.first.recommended, isTrue);
    });

    test('a payment due puts the agreement first where no payment is offered', () {
      final actions = planQuickAddActions(
        planId: 'due-plan',
        tabIndex: 2,
        canManageMoney: true,
        signals: const PlanQuickAddSignals(
          duePaymentSchedules: 1,
          providerCount: 1,
        ),
      );
      expect(actions.first.kind, PlanQuickAddKind.cost);
    });

    test('the wedding stage adapts the recommended choice', () {
      PlanQuickAddKind first(String planId, WeddingPlanStage stage, int n) =>
          planQuickAddActions(
            planId: planId,
            tabIndex: 0,
            canManageMoney: true,
            signals: PlanQuickAddSignals(stage: stage, providerCount: n),
          ).first.kind;

      expect(
        first('stage-foundation', WeddingPlanStage.foundation, 1),
        PlanQuickAddKind.task,
      );
      expect(
        first('stage-final-month', WeddingPlanStage.finalMonth, 1),
        PlanQuickAddKind.guest,
      );
      expect(
        first('stage-wedding-day', WeddingPlanStage.weddingDay, 0),
        PlanQuickAddKind.task,
      );
    });
  });

  group('opening a choice', () {
    testWidgets('remembers the choice and hands the guest and providers to '
        'the shell', (tester) async {
      var guests = 0;
      var providers = 0;
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      await openPlanQuickAdd(
        context,
        planId: 'offline-plan',
        kind: PlanQuickAddKind.guest,
        onAddGuest: () => guests += 1,
        onFindProviders: () => providers += 1,
        onChanged: () async {},
      );
      expect(guests, 1);
      expect(lastPlanQuickAdd('offline-plan'), PlanQuickAddKind.guest);

      await openPlanQuickAdd(
        context,
        planId: 'offline-plan',
        kind: PlanQuickAddKind.quote,
        onAddGuest: () => guests += 1,
        onFindProviders: () => providers += 1,
        onChanged: () async {},
      );
      expect(providers, 1);
      expect(lastPlanQuickAdd('offline-plan'), PlanQuickAddKind.quote);
    });

    testWidgets('opens today\'s forms and refreshes only when they saved', (
      tester,
    ) async {
      final opened = <String>[];
      var changes = 0;
      Widget form(GoRouterState state) {
        opened.add(state.uri.toString());
        return Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                // The item form answers with the new item's id.
                TextButton(
                  onPressed: () => context.pop<Object>(
                    state.uri.path.contains('categories') ? 'category-9' : true,
                  ),
                  child: const Text('save'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('back'),
                ),
              ],
            ),
          ),
        );
      }

      late BuildContext home;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              home = context;
              return const Scaffold(body: Text('home'));
            },
          ),
          GoRoute(
            path: '/wedding-plans/:id/money/costs/create',
            builder: (context, state) => form(state),
          ),
          GoRoute(
            path: '/wedding-plans/:id/money/categories/create',
            builder: (context, state) => form(state),
          ),
          GoRoute(
            path: '/wedding-plans/:id/tasks/create',
            builder: (context, state) => form(state),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      for (final (kind, save) in [
        (PlanQuickAddKind.cost, true),
        (PlanQuickAddKind.category, true),
        (PlanQuickAddKind.task, false),
      ]) {
        final done = openPlanQuickAdd(
          home,
          planId: 'plan-9',
          kind: kind,
          onAddGuest: () {},
          onFindProviders: () {},
          onChanged: () async => changes += 1,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(save ? 'save' : 'back'));
        await tester.pumpAndSettle();
        await done;
      }

      expect(opened, [
        AppRouter.moneyCostCreate('plan-9'),
        AppRouter.moneyCategoryCreate('plan-9'),
        AppRouter.createTask('plan-9'),
      ]);
      expect(changes, 2, reason: 'the task form was left without saving');

      final done = openPlanQuickAdd(
        home,
        planId: 'plan-9',
        kind: PlanQuickAddKind.task,
        onAddGuest: () {},
        onFindProviders: () {},
        onChanged: () async => changes += 1,
        refreshOnReturn: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      await done;
      expect(changes, 3, reason: 'a phone plan rereads on every return');
    });
  });
}
