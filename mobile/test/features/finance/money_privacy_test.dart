import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('privacy control hides and restores every shared money amount', (
    tester,
  ) async {
    final provider = FinanceProvider(
      FinanceApi(ApiClient(tokenProvider: () async => null)),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MoneyPrivacyButton(),
                MoneyAmountText(amount: 1500000, currency: 'YER'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('1.5'), findsOneWidget);
    expect(provider.amountsHidden, isFalse);

    await tester.tap(find.byKey(const ValueKey('money-privacy-toggle')));
    await tester.pump();

    expect(find.text('••••'), findsOneWidget);
    expect(find.textContaining('1.5'), findsNothing);
    expect(provider.amountsHidden, isTrue);

    await tester.tap(find.byKey(const ValueKey('money-privacy-toggle')));
    await tester.pump();

    expect(find.textContaining('1.5'), findsOneWidget);
    expect(provider.amountsHidden, isFalse);
  });
}
