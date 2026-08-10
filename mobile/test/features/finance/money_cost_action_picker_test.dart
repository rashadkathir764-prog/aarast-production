import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/widgets/money_cost_action_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('picker shows only costs that can receive a payment', (
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
    expect(find.text('لأي تكلفة ستسجّل الدفعة؟'), findsOneWidget);
    expect(find.text(_payableCost.title), findsOneWidget);
    expect(find.text(_paidCost.title), findsNothing);
    expect(find.text(_cancelledCost.title), findsNothing);

    await tester.tap(find.text(_payableCost.title));
    await tester.pumpAndSettle();
    expect(selection?.cost?.id, _payableCost.id);
    expect(selection?.createCost, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty picker explains the dependency and offers a real next step',
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
                      costs: const [],
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
      expect(find.text('أضف تكلفة أولًا'), findsOneWidget);
      expect(find.textContaining('موعد الدفع يرتبط'), findsOneWidget);
      await tester.tap(find.text('إضافة تكلفة'));
      await tester.pumpAndSettle();
      expect(selection?.createCost, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
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
  title: 'تكلفة مكتملة',
  totalAmount: '100',
  paidAmount: '100',
  remainingAmount: '0',
  status: 'PAID',
);

const _cancelledCost = WeddingCost(
  id: 'cost-cancelled',
  weddingPlanId: 'plan-1',
  budgetCategoryId: 'category-1',
  title: 'تكلفة ملغاة',
  totalAmount: '100',
  paidAmount: '0',
  remainingAmount: '100',
  status: 'CANCELLED',
);
