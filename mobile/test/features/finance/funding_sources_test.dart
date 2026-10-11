import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/funding_sources_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('costs can be filtered by who pays and carry the payer', () async {
    final requests = <Uri>[];
    final apiClient = ApiClient(tokenProvider: () async => 'token');
    apiClient.dio.httpClientAdapter = _RecordingAdapter(requests, {
      'items': [
        {
          'id': 'cost-1',
          'weddingPlanId': 'plan-1',
          'budgetCategoryId': 'cat-1',
          'title': 'الذهب',
          'totalAmount': '900000',
          'paidAmount': '0',
          'status': 'OPEN',
          'payer': 'GROOM',
          'payerName': null,
        },
      ],
      'page': 1,
      'limit': 30,
      'total': 1,
      'totalPages': 1,
    });

    final page = await FinanceApi(apiClient).getCosts('plan-1', payer: 'GROOM');

    expect(requests.single.queryParameters['payer'], 'GROOM');
    expect(page.items.single.payer, 'GROOM');
    expect(CostPayerOption.label(page.items.single.payer), 'العريس');
    expect(
      WeddingCost.fromJson({
        'id': 'c',
        'payer': 'FAMILY',
        'payerName': 'الوالد',
      }).payerName,
      'الوالد',
    );
  });

  test('a loan parses its repayments and what is still owed', () {
    final loan = FundingSource.fromJson({
      'id': 'loan-1',
      'weddingPlanId': 'plan-1',
      'kind': 'LOAN',
      'sourceName': 'ابن العم',
      'amount': '200000',
      'status': 'RECEIVED',
      'repaidAmount': '50000',
      'outstandingAmount': '150000',
      'repayments': [
        {
          'id': 'r-1',
          'fundingSourceId': 'loan-1',
          'amount': '50000',
          'status': 'PAID',
          'paidAt': '2026-10-01T00:00:00.000Z',
        },
      ],
    });

    expect(loan.isLoan, isTrue);
    expect(loan.outstandingAmount, '150000');
    expect(loan.repayments.single.isPaid, isTrue);
  });

  test('only the owner summary carries funding', () {
    final owner = MoneySummary.fromJson({
      'weddingPlanId': 'plan-1',
      'funding': {
        'total': '300000',
        'availableCash': '50000',
        'shortfall': '100000',
        'overdueLoanRepayments': 1,
        'sourcesCount': 2,
      },
    });
    final member = MoneySummary.fromJson({
      'weddingPlanId': 'plan-1',
      'funding': null,
    });

    expect(owner.funding?.shortfall, '100000');
    expect(owner.funding?.overdueLoanRepayments, 1);
    expect(member.funding, isNull);
  });

  group('FundingProvider', () {
    test('create and loan repayments show what the server saved', () async {
      final api = _FakeFundingApi();
      final provider = FundingProvider(api);
      await provider.load('plan-1');

      expect(
        await provider.create(
          weddingPlanId: 'plan-1',
          kind: FundingKind.loan,
          sourceName: 'ابن العم',
          amount: '200000',
          status: FundingStatus.received,
        ),
        isTrue,
      );
      final loan = provider.sources.last;
      expect(await provider.addRepayment(loan, amount: '50000'), isTrue);
      final repayment = provider.sourceById(loan.id)!.repayments.single;
      expect(
        await provider.setRepaymentPaid(loan, repayment, paid: true),
        isTrue,
      );

      expect(provider.sourceById(loan.id)!.repayments.single.isPaid, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('a rejected change keeps the list and says why', () async {
      final api = _FakeFundingApi()..reject = true;
      final provider = FundingProvider(api);
      await provider.load('plan-1');

      final ok = await provider.create(
        weddingPlanId: 'plan-1',
        kind: FundingKind.gift,
        sourceName: 'نقوط',
        amount: '1000',
        status: FundingStatus.received,
      );

      expect(ok, isFalse);
      expect(provider.sources, hasLength(1));
      expect(provider.errorMessage, 'تعذر الحفظ.');
      expect(provider.isSaving, isFalse);
    });
  });

  testWidgets('FundingSourcesScreen lists sources and adds one', (
    tester,
  ) async {
    final api = _FakeFundingApi();
    final provider = FundingProvider(api);

    await tester.pumpWidget(
      ChangeNotifierProvider<FundingProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: FundingSourcesScreen(weddingPlanId: 'plan-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الوالد'), findsOneWidget);
    expect(find.text('دعم الأهل · وعد'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('funding-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('funding-name')),
      'مدخراتي',
    );
    await tester.enterText(
      find.byKey(const ValueKey('funding-amount')),
      '500000',
    );
    await tester.tap(find.text('مدخرات'));
    await tester.ensureVisible(find.byKey(const ValueKey('funding-save')));
    await tester.tap(find.byKey(const ValueKey('funding-save')));
    await tester.pumpAndSettle();

    expect(api.created.single.$1, FundingKind.savings);
    expect(api.created.single.$2, 'مدخراتي');
    expect(find.text('مدخراتي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeFundingApi extends FundingApi {
  _FakeFundingApi() : super(ApiClient(tokenProvider: () async => null));

  bool reject = false;
  int _sequence = 0;
  final created = <(String, String)>[];

  final List<FundingSource> _sources = [
    const FundingSource(
      id: 'source-0',
      weddingPlanId: 'plan-1',
      kind: FundingKind.familySupport,
      sourceName: 'الوالد',
      amount: '300000',
      status: FundingStatus.pledged,
    ),
  ];

  void _gate() {
    if (reject) throw const ApiException('تعذر الحفظ.', statusCode: 400);
  }

  @override
  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async =>
      List.of(_sources);

  @override
  Future<FundingSource> createFundingSource({
    required String weddingPlanId,
    required String kind,
    required String sourceName,
    required String amount,
    required String status,
    String? sourcePhone,
    String? note,
  }) async {
    _gate();
    created.add((kind, sourceName));
    final source = FundingSource(
      id: 'source-${++_sequence}',
      weddingPlanId: weddingPlanId,
      kind: kind,
      sourceName: sourceName,
      amount: amount,
      status: status,
      outstandingAmount: kind == FundingKind.loan ? amount : null,
    );
    _sources.add(source);
    return source;
  }

  @override
  Future<FundingSource> addRepayment(
    FundingSource loan, {
    required String amount,
    DateTime? dueDate,
  }) async {
    _gate();
    return _withRepayments(loan.id, [
      LoanRepayment(
        id: 'repayment-${++_sequence}',
        fundingSourceId: loan.id,
        amount: amount,
        status: RepaymentStatus.planned,
        dueDate: dueDate,
      ),
    ]);
  }

  @override
  Future<FundingSource> setRepaymentStatus(
    LoanRepayment repayment,
    String status,
  ) async {
    _gate();
    final loan = _sources.firstWhere(
      (item) => item.id == repayment.fundingSourceId,
    );
    return _withRepayments(loan.id, [
      for (final item in loan.repayments)
        item.id == repayment.id
            ? LoanRepayment(
                id: item.id,
                fundingSourceId: item.fundingSourceId,
                amount: item.amount,
                status: status,
                paidAt: status == RepaymentStatus.paid ? DateTime.now() : null,
              )
            : item,
    ]);
  }

  FundingSource _withRepayments(String id, List<LoanRepayment> repayments) {
    final index = _sources.indexWhere((item) => item.id == id);
    final current = _sources[index];
    final updated = FundingSource(
      id: current.id,
      weddingPlanId: current.weddingPlanId,
      kind: current.kind,
      sourceName: current.sourceName,
      amount: current.amount,
      status: current.status,
      outstandingAmount: current.outstandingAmount,
      repayments: repayments,
    );
    _sources[index] = updated;
    return updated;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.requests, this.body);

  final List<Uri> requests;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
