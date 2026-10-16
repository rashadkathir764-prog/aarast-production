import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.10: a cost the owner or partner keeps to themselves.

void main() {
  test('a private cost and the right to record one read from the server', () {
    expect(WeddingCost.fromJson({'id': 'c', 'isPrivate': true}).isPrivate, isTrue);
    expect(WeddingCost.fromJson({'id': 'c'}).isPrivate, isFalse);
    expect(
      MoneyPermissions.fromJson({'canManageMoney': true, 'canRecordPrivateCost': true})
          .canRecordPrivateCost,
      isTrue,
    );
    expect(MoneyPermissions.fromJson({'canManageMoney': true}).canRecordPrivateCost, isFalse);
  });

  testWidgets('a private cost shows a lock in the list, a shared one does not', (
    tester,
  ) async {
    Widget card(bool isPrivate) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: CostCard(
          cost: WeddingCost.fromJson({
            'id': 'c',
            'title': 'فستان',
            'totalAmount': '1000',
            'paidAmount': '0',
            'remainingAmount': '1000',
            'status': 'OPEN',
            'isPrivate': isPrivate,
          }),
          currency: 'YER',
          onTap: () {},
        ),
      ),
    );

    await tester.pumpWidget(card(true));
    expect(find.byKey(const ValueKey('cost-private-lock')), findsOneWidget);

    await tester.pumpWidget(card(false));
    expect(find.byKey(const ValueKey('cost-private-lock')), findsNothing);
  });
}
