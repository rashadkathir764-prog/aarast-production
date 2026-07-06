import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/debts/data/debt_installment_api.dart';
import 'package:aarast_mobile/features/debts/providers/debt_installment_provider.dart';
import 'package:aarast_mobile/features/debts/screens/create_debt_screen.dart';
import 'package:aarast_mobile/shared/models/quote_finance_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows Arabic currency labels instead of raw YER', (
    tester,
  ) async {
    _setTallView(tester);

    await _pumpScreen(tester);

    expect(find.text('مبلغ باقي جديد'), findsOneWidget);
    expect(find.text('ر.ي'), findsWidgets);
    expect(find.text('YER'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses quote currency when opened from an accepted quote', (
    tester,
  ) async {
    _setTallView(tester);

    await _pumpScreen(
      tester,
      quoteContext: const QuoteFinanceContext(
        quoteRequestId: 'quote-1',
        providerId: 'provider-1',
        providerName: 'قاعة السلام',
        serviceTitle: 'حجز صالة',
        amount: '1200',
        currency: 'SAR',
      ),
    );

    expect(find.text('حوّل العرض إلى التزام واضح'), findsOneWidget);
    expect(find.text('ر.س'), findsWidgets);
    expect(find.text('YER'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'source keeps create debt screen on Lucide icons and Arabic currency',
    () {
      final source = File(
        '${_findMobileRoot()}lib/features/debts/screens/create_debt_screen.dart',
      ).readAsStringSync();
      final materialIconLines = source
          .split('\n')
          .where(
            (line) => line.contains('Icons.') && !line.contains('LucideIcons.'),
          )
          .toList(growable: false);

      expect(source, isNot(contains("suffixText: 'YER'")));
      expect(materialIconLines, isEmpty);
      expect(source, contains('LucideIcons.'));
      expect(source, contains('currencyLabelAr'));
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  QuoteFinanceContext? quoteContext,
}) async {
  final apiClient = ApiClient(tokenProvider: () async => null);
  await tester.pumpWidget(
    ChangeNotifierProvider<DebtInstallmentProvider>(
      create: (_) => DebtInstallmentProvider(DebtInstallmentApi(apiClient)),
      child: MaterialApp(
        home: CreateDebtScreen(
          weddingPlanId: 'guest-plan-test',
          quoteContext: quoteContext,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1600);
  addTearDown(tester.view.reset);
}

String _findMobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
