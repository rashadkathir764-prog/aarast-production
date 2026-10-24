import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/widgets/money_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

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

    // The design's round button (c01), not the old Material icon button.
    expect(find.byType(JourneyRoundButton), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(provider.amountsHidden, isFalse);
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
    expect(find.byTooltip('أخفِ المبالغ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('money-privacy-toggle')));
    await tester.pump();

    expect(provider.amountsHidden, isTrue);
    expect(find.byIcon(LucideIcons.eye), findsOneWidget);
    expect(find.byTooltip('أظهر المبالغ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('money-privacy-toggle')));
    await tester.pump();

    expect(provider.amountsHidden, isFalse);
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
  });
}
