// Canonical quick-add actions.
//
// Locks the labels + routes emitted by [buildCanonicalQuickAddActions]
// so duplicate shortcuts (MainShell, LocalGuestDashboardScreen) cannot
// drift from the navigation blueprint.

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/quick_add_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildCanonicalQuickAddActions', () {
    test('emits the five canonical actions with stable labels', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add('$route|rf=$refreshDashboard');
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-1',
        openRoute: open,
      );

      expect(actions.length, 5);
      expect(actions.map((a) => a.label).toList(), <String>[
        'إضافة مصروف',
        'إضافة مهمة',
        'إضافة ضيف',
        'إضافة دين/قسط',
        'طلب عرض سعر',
      ]);
    });

    test('routes every action through the canonical AppRouter paths', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add(route);
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-7',
        openRoute: open,
      );

      for (final action in actions) {
        action.onTap();
      }

      expect(calls, <String>[
        AppRouter.createExpense('plan-7'),
        AppRouter.createTask('plan-7'),
        AppRouter.guestList('plan-7'),
        AppRouter.createDebt('plan-7'),
        AppRouter.providerMarketplace,
      ]);
    });

    test('forwards refreshDashboardOnExpense to expense open only', () {
      final calls = <String>[];
      Future<void> open(String route, {bool refreshDashboard = false}) async {
        calls.add('$route|rf=$refreshDashboard');
      }

      final actions = buildCanonicalQuickAddActions(
        _DummyContext(),
        planId: 'plan-r',
        refreshDashboardOnExpense: true,
        openRoute: open,
      );

      for (final action in actions) {
        action.onTap();
      }

      // Only the first action (expense) propagates refreshDashboard=true.
      expect(calls[0].endsWith('|rf=true'), isTrue);
      for (var i = 1; i < calls.length; i++) {
        expect(calls[i].endsWith('|rf=false'), isTrue, reason: calls[i]);
      }
    });

    test('orders the first action by the active tab context', () {
      Future<void> open(String route, {bool refreshDashboard = false}) async {}

      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.money,
          openRoute: open,
        ).first.label,
        'إضافة مصروف',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.tasks,
          openRoute: open,
        ).first.label,
        'إضافة مهمة',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.guests,
          openRoute: open,
        ).first.label,
        'إضافة ضيف',
      );
      expect(
        buildCanonicalQuickAddActions(
          _DummyContext(),
          planId: 'plan-1',
          contextOrder: QuickAddContext.providers,
          openRoute: open,
        ).first.label,
        'طلب عرض سعر',
      );
    });
  });
}

class _DummyContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
