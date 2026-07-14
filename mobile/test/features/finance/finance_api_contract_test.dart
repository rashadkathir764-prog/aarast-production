import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinanceApi money-budget contract', () {
    test(
      'sends id xor UUID v4 clientId and decodes the response wrapper',
      () async {
        final client = _RecordingApiClient();
        final api = FinanceApi(client);

        final result = await api.replaceMoneyBudget(
          planId: 'plan-1',
          totalBudget: '1000000',
          currency: 'yer',
          categories: const [
            (
              id: 'category-existing',
              name: 'القاعات',
              allocatedAmount: '600000',
            ),
            (id: null, name: 'التصوير', allocatedAmount: '400000'),
          ],
        );

        expect(client.lastPutPath, '/api/v1/wedding-plans/plan-1/money-budget');
        final sentCategories = (client.lastPutBody!['categories'] as List)
            .cast<Map<String, dynamic>>();
        expect(sentCategories.first['id'], 'category-existing');
        expect(sentCategories.first, isNot(contains('clientId')));
        expect(sentCategories.last, isNot(contains('id')));
        expect(
          sentCategories.last['clientId'],
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(result.summary.planId, 'plan-1');
        expect(result.summary.budget.total, '1000000');
        expect(result.categories.map((item) => item.id), [
          'category-existing',
          'category-created',
        ]);
        expect(result.idMap, {
          sentCategories.last['clientId']: 'category-created',
        });
      },
    );

    test(
      'compatibility save returns the nested summary, not an empty wrapper',
      () async {
        final client = _RecordingApiClient();
        final summary = await FinanceApi(client).saveMoneyBudget(
          planId: 'plan-1',
          totalBudget: '1000000',
          currency: 'YER',
          categories: const [
            (id: 'category-existing', name: 'القاعات', allocatedAmount: null),
          ],
        );

        expect(summary.planId, 'plan-1');
        expect(summary.budget.total, '1000000');
      },
    );

    test('sends a budget-first write with an empty category list', () async {
      final client = _RecordingApiClient();

      await FinanceApi(client).replaceMoneyBudget(
        planId: 'plan-1',
        totalBudget: '1000000',
        currency: 'YER',
        categories: const [],
      );

      expect(client.lastPutBody, {
        'totalBudget': '1000000',
        'currency': 'YER',
        'categories': <Map<String, dynamic>>[],
      });
    });
  });

  test('getBudgetCategories always returns BudgetCategory values', () async {
    final client = _RecordingApiClient();
    final api = FinanceApi(client);

    final remote = await api.getBudgetCategories('plan-1');
    final local = await api.getBudgetCategories('local-guest-plan');

    expect(
      client.lastGetListPath,
      '/api/v1/wedding-plans/plan-1/budget-categories',
    );
    expect(remote, everyElement(isA<BudgetCategory>()));
    expect(remote.single.id, 'category-existing');
    expect(local, isA<List<BudgetCategory>>());
  });

  test(
    'payment detail and schedule cancellation use canonical controllers',
    () async {
      final client = _RecordingApiClient();
      final api = FinanceApi(client);

      final payment = await api.getPayment('payment-1');
      final cancelled = await api.cancelSchedule(
        PaymentSchedule(
          id: 'schedule-1',
          costId: 'cost-1',
          amount: '50',
          dueDate: _dueDate,
          status: 'PENDING',
          weddingPlanId: 'plan-1',
        ),
      );

      expect(payment.id, 'payment-1');
      expect(client.getPaths, contains('/api/v1/cost-payments/payment-1'));
      expect(
        client.postPaths,
        contains('/api/v1/payment-schedules/schedule-1/cancel'),
      );
      expect(cancelled.status, 'CANCELLED');
    },
  );

  test('all FinanceApi HTTP paths match the live money controllers', () {
    final source = File(
      'lib/features/finance/data/finance_api.dart',
    ).readAsStringSync();

    for (final route in <String>[
      '/api/v1/wedding-plans/\$planId/money-summary',
      '/api/v1/wedding-plans/\$planId/money-budget',
      '/api/v1/wedding-plans/\$planId/budget-categories',
      '/api/v1/budget-categories/\${category.id}',
      '/api/v1/wedding-plans/\$planId/costs',
      '/api/v1/costs/\$costId',
      '/api/v1/costs/\${cost.id}',
      '/api/v1/costs/\${cost.id}/cancel',
      '/api/v1/costs/\${cost.id}/payments',
      '/api/v1/cost-payments/\$paymentId',
      '/api/v1/cost-payments/\${payment.id}/reverse',
      '/api/v1/wedding-plans/\$planId/cost-payments',
      '/api/v1/wedding-plans/\$planId/payment-schedules/due',
      '/api/v1/costs/\$costId/payment-schedules',
      '/api/v1/costs/\${cost.id}/payment-schedules',
      '/api/v1/payment-schedules/\${schedule.id}',
      '/api/v1/payment-schedules/\${schedule.id}/cancel',
      '/api/v1/payment-schedules/\${schedule.id}/pay',
    ]) {
      expect(source, contains(route), reason: route);
    }
  });
}

final _dueDate = DateTime(2026, 8, 1);

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(tokenProvider: () async => null);

  String? lastPutPath;
  Map<String, dynamic>? lastPutBody;
  String? lastGetListPath;
  final List<String> getPaths = [];
  final List<String> postPaths = [];

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) {
    return switch (method.toUpperCase()) {
      'PUT' => putJson(path, data),
      'POST' => postJson(path, data),
      _ => throw StateError('Unexpected $method $path'),
    };
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    lastPutPath = path;
    lastPutBody = data;
    final sent = (data['categories'] as List).cast<Map<String, dynamic>>();
    final createdClientId = sent
        .where((item) => item['clientId'] != null)
        .map((item) => item['clientId'].toString())
        .firstOrNull;
    return {
      'summary': {
        'planId': 'plan-1',
        'currency': 'YER',
        'budget': {'total': data['totalBudget']},
        'categories': const [],
        'permissions': {'canViewMoney': true, 'canManageMoney': true},
      },
      'categories': [
        {
          'id': 'category-existing',
          'weddingPlanId': 'plan-1',
          'name': 'القاعات',
          'allocatedAmount': '600000',
          'costsCount': 0,
        },
        if (createdClientId != null)
          {
            'id': 'category-created',
            'weddingPlanId': 'plan-1',
            'name': 'التصوير',
            'allocatedAmount': '400000',
            'costsCount': 0,
          },
      ],
      'idMap': createdClientId == null
          ? <String, String>{}
          : {createdClientId: 'category-created'},
    };
  }

  @override
  Future<List<dynamic>> getJsonList(String path) async {
    lastGetListPath = path;
    return [
      {
        'id': 'category-existing',
        'weddingPlanId': 'plan-1',
        'name': 'القاعات',
        'costsCount': 0,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    getPaths.add(path);
    if (path == '/api/v1/cost-payments/payment-1') {
      return {
        'id': 'payment-1',
        'costId': 'cost-1',
        'amount': '50',
        'paidAt': '2026-07-14T12:00:00.000Z',
      };
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    postPaths.add(path);
    if (path == '/api/v1/payment-schedules/schedule-1/cancel') {
      return {
        'id': 'schedule-1',
        'costId': 'cost-1',
        'weddingPlanId': 'plan-1',
        'amount': '50',
        'dueDate': '2026-08-01T00:00:00.000Z',
        'status': 'CANCELLED',
      };
    }
    throw StateError('Unexpected POST $path');
  }
}
