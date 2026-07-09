import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/debts/data/debt_installment_api.dart';
import 'package:aarast_mobile/features/debts/models/debt.dart';
import 'package:aarast_mobile/features/debts/models/installment.dart';
import 'package:aarast_mobile/features/debts/providers/debt_installment_provider.dart';
import 'package:aarast_mobile/features/debts/screens/create_installment_screen.dart';
import 'package:aarast_mobile/features/debts/screens/debt_details_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('debt details use the selected plan currency label', (
    tester,
  ) async {
    _setTallView(tester);
    final apiClient = ApiClient(tokenProvider: () async => null);
    final debtProvider = DebtInstallmentProvider(_FakeDebtApi(apiClient))
      ..selectDebt(_debt());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DebtInstallmentProvider>.value(
            value: debtProvider,
          ),
          ChangeNotifierProvider<WeddingPlansProvider>.value(
            value: _FakeWeddingPlansProvider(apiClient, [_plan()]),
          ),
        ],
        child: const MaterialApp(home: DebtDetailsScreen(debtId: 'debt-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل دين قديم'), findsOneWidget);
    expect(find.textContaining('ر.س'), findsWidgets);
    expect(find.textContaining('YER'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create installment uses the selected debt plan currency label', (
    tester,
  ) async {
    _setTallView(tester);
    final apiClient = ApiClient(tokenProvider: () async => null);
    final debtProvider = DebtInstallmentProvider(_FakeDebtApi(apiClient))
      ..selectDebt(_debt());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DebtInstallmentProvider>.value(
            value: debtProvider,
          ),
          ChangeNotifierProvider<WeddingPlansProvider>.value(
            value: _FakeWeddingPlansProvider(apiClient, [_plan()]),
          ),
        ],
        child: const MaterialApp(
          home: CreateInstallmentScreen(debtId: 'debt-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('قسط لدين قديم'), findsOneWidget);
    expect(find.text('ر.س'), findsWidgets);
    expect(find.text('YER'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'debt detail and installment sources avoid raw YER and Material icons',
    () {
      final root = _findMobileRoot();
      for (final path in [
        '${root}lib/features/debts/screens/debt_details_screen.dart',
        '${root}lib/features/debts/screens/create_installment_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final materialIconLines = source
            .split('\n')
            .where(
              (line) =>
                  line.contains('Icons.') && !line.contains('LucideIcons.'),
            )
            .toList(growable: false);

        expect(source, isNot(contains("suffixText: 'YER'")));
        expect(source, isNot(contains(" ر.ي'")));
        expect(materialIconLines, isEmpty);
        expect(source, contains('LucideIcons.'));
        expect(source, contains('currencyLabelAr'));
      }
    },
  );

  test('legacy debt list routes new additions to financial commitments', () {
    final root = _findMobileRoot();
    final source = File(
      '${root}lib/features/debts/screens/debt_installment_screen.dart',
    ).readAsStringSync();

    expect(source, contains('سجل الديون القديم'));
    expect(source, contains('AppRouter.createFinancialCommitment'));
    expect(source, isNot(contains('AppRouter.createDebt')));
  });
}

Debt _debt() {
  final now = DateTime.utc(2026, 7, 5);
  return Debt(
    id: 'debt-1',
    weddingPlanId: 'plan-sar',
    creditorName: 'قاعة السلام',
    title: 'باقي الصالة',
    totalAmount: '1500',
    paidAmount: '500',
    status: 'PARTIALLY_PAID',
    dueDate: DateTime.utc(2026, 8, 5),
    createdAt: now,
    updatedAt: now,
  );
}

WeddingPlan _plan() {
  final now = DateTime.utc(2026, 7, 5);
  return WeddingPlan(
    id: 'plan-sar',
    ownerUserId: 'user-1',
    title: 'خطة الرياض',
    currency: 'SAR',
    status: 'PLANNING',
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeDebtApi extends DebtInstallmentApi {
  _FakeDebtApi(super.apiClient);

  @override
  Future<List<Installment>> getInstallments(String debtId) async => const [];
}

class _FakeWeddingPlansProvider extends WeddingPlansProvider {
  _FakeWeddingPlansProvider(ApiClient apiClient, this._fakePlans)
    : super(WeddingPlansApi(apiClient));

  final List<WeddingPlan> _fakePlans;

  @override
  List<WeddingPlan> get plans => _fakePlans;
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
