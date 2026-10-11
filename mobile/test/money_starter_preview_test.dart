@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/preview_fonts.dart';

const _planId = 'money-starter-preview';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('money starter — groom path (420)', (tester) async {
    await _pumpStarter(tester, personaCode: 'GROOM');

    expect(find.text('جهّز ميزانية عرسك'), findsOneWidget);
    expect(find.text('تجهيز الميزانية · 10'), findsOneWidget);
    await expectLater(
      find.byType(MoneyOverviewScreen),
      matchesGoldenFile('goldens/money_starter_groom.png'),
    );
  });

  testWidgets('money starter — bride path (420)', (tester) async {
    await _pumpStarter(tester, personaCode: 'BRIDE');

    expect(find.text('جهّزي ميزانية فرحتك'), findsOneWidget);
    expect(find.text('تجهيز الميزانية · 10'), findsOneWidget);
    await expectLater(
      find.byType(MoneyOverviewScreen),
      matchesGoldenFile('goldens/money_starter_bride.png'),
    );
  });
}

Future<void> _pumpStarter(
  WidgetTester tester, {
  required String personaCode,
}) async {
  tester.view.physicalSize = const Size(420, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<FinanceProvider>(
      create: (_) => FinanceProvider(_EmptyFinanceApi()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MoneyOverviewScreen(
            weddingPlanId: _planId,
            personaCode: personaCode,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class _EmptyFinanceApi extends FinanceApi {
  _EmptyFinanceApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<MoneySummary> getMoneySummary(String planId) async {
    return MoneySummary(
      planId: planId,
      currency: 'YER',
      permissions: const MoneyPermissions(
        canViewMoney: true,
        canManageMoney: true,
      ),
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
    return FinancePage(
      items: const [],
      page: page,
      pageSize: limit,
      total: 0,
      totalPages: 1,
    );
  }

  @override
  Future<FinancePage<CostPayment>> getPlanPayments(
    String planId, {
    int page = 1,
    int limit = 30,
  }) async {
    return FinancePage(
      items: const [],
      page: page,
      pageSize: limit,
      total: 0,
      totalPages: 1,
    );
  }

  @override
  Future<List<PaymentSchedule>> getDuePaymentSchedules(String planId) async {
    return const [];
  }
}
