import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../support/screen_reader.dart';

// The amounts themselves are hidden on the money screens; see «hiding
// amounts masks the next payment amount» in finance_duplication_cleanup_test.

void main() {
  testWidgets('the eye beside «المال» hides the amounts and shows them again', (
    tester,
  ) async {
    final provider = FinanceProvider(
      FinanceApi(ApiClient(tokenProvider: () async => null)),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: MoneyPrivacyButton())),
        ),
      ),
    );

    // Changed on purpose (critique م8, 2026-11-18): the eye with its word,
    // as on the home, not a round icon alone.
    expect(find.byType(IconButton), findsNothing);
    expect(provider.amountsHidden, isFalse);
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
    expect(find.text('أخفِ'), findsOneWidget);
    expect(find.bySemanticsLabel('أخفِ المبالغ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('money-privacy-toggle')));
    await tester.pump();

    expect(provider.amountsHidden, isTrue);
    expect(find.byIcon(LucideIcons.eye), findsOneWidget);
    expect(find.text('أظهر'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('money-privacy-toggle')));
    await tester.pump();

    expect(provider.amountsHidden, isFalse);
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
  });

  // RA-MO-361: the eye said «زر» to a screen reader and a double tap on it
  // did nothing.
  testWidgets('a screen reader presses the eye', (tester) async {
    final semantics = tester.ensureSemantics();
    final provider = FinanceProvider(
      FinanceApi(ApiClient(tokenProvider: () async => null)),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: MoneyPrivacyButton())),
        ),
      ),
    );
    expectEveryButtonActs();

    tester.semantics.tap(find.semantics.byLabel('أخفِ المبالغ'));
    await tester.pump();
    expect(provider.amountsHidden, isTrue);

    tester.semantics.tap(find.semantics.byLabel('أظهر المبالغ'));
    await tester.pump();
    expect(provider.amountsHidden, isFalse);
    semantics.dispose();
  });
}
