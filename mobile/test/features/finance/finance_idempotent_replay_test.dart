import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'lost create-cost response replays the same key without duplicating cost or initial payment',
    () async {
      final harness = await _Harness.create();

      final localCost = await harness.api.createCost(
        planId: 'plan-1',
        budgetCategoryId: 'category-1',
        title: 'القاعة',
        totalAmount: '1000',
        initialPaymentAmount: '100',
        partyName: 'قاعة خارجية',
      );

      expect(localCost.id, startsWith('local-'));
      final queued = (await harness.database.pendingSyncItems()).single;
      expect(harness.adapter.mutationRequestIds, [queued.id]);

      await harness.offline.syncPendingChanges();

      expect(harness.adapter.mutationRequestIds, [queued.id, queued.id]);
      expect(harness.adapter.costCommits, 1);
      expect(harness.adapter.initialPaymentCommits, 1);
      expect(await harness.database.pendingSyncCount(), 0);
    },
  );

  test(
    'lost payment response replays the same key without a second ledger entry',
    () async {
      final harness = await _Harness.create();

      final localPayment = await harness.api.createPayment(
        cost: _cost(),
        amount: '125',
      );

      expect(localPayment.id, startsWith('local-'));
      final queued = (await harness.database.pendingSyncItems()).single;
      expect(harness.adapter.mutationRequestIds, [queued.id]);

      await harness.offline.syncPendingChanges();

      expect(harness.adapter.mutationRequestIds, [queued.id, queued.id]);
      expect(harness.adapter.paymentCommits, 1);
      expect(await harness.database.pendingSyncCount(), 0);
    },
  );

  test(
    'lost schedule response replays the same key without a second schedule',
    () async {
      final harness = await _Harness.create();

      final localSchedule = await harness.api.createSchedule(
        cost: _cost(),
        amount: '250',
        dueDate: DateTime.utc(2026, 8, 1),
      );

      expect(localSchedule.id, startsWith('local-'));
      final queued = (await harness.database.pendingSyncItems()).single;
      expect(harness.adapter.mutationRequestIds, [queued.id]);

      await harness.offline.syncPendingChanges();

      expect(harness.adapter.mutationRequestIds, [queued.id, queued.id]);
      expect(harness.adapter.scheduleCommits, 1);
      expect(await harness.database.pendingSyncCount(), 0);
    },
  );

  test(
    '500 after commit queues and replays the same key without a duplicate',
    () async {
      final harness = await _Harness.create(
        firstFailure: _FirstFailure.serverError,
      );

      final localPayment = await harness.api.createPayment(
        cost: _cost(),
        amount: '125',
      );

      expect(localPayment.id, startsWith('local-'));
      final queued = (await harness.database.pendingSyncItems()).single;
      expect(harness.adapter.mutationRequestIds, [queued.id]);

      await harness.offline.syncPendingChanges();

      expect(harness.adapter.mutationRequestIds, [queued.id, queued.id]);
      expect(harness.adapter.paymentCommits, 1);
      expect(await harness.database.pendingSyncCount(), 0);
    },
  );

  test(
    'send timeout queues and replays the same key without a duplicate',
    () async {
      final harness = await _Harness.create(
        firstFailure: _FirstFailure.sendTimeout,
      );

      final localSchedule = await harness.api.createSchedule(
        cost: _cost(),
        amount: '250',
        dueDate: DateTime.utc(2026, 8, 1),
      );

      expect(localSchedule.id, startsWith('local-'));
      final queued = (await harness.database.pendingSyncItems()).single;
      expect(harness.adapter.mutationRequestIds, [queued.id]);

      await harness.offline.syncPendingChanges();

      expect(harness.adapter.mutationRequestIds, [queued.id, queued.id]);
      expect(harness.adapter.scheduleCommits, 1);
      expect(await harness.database.pendingSyncCount(), 0);
    },
  );
}

class _Harness {
  const _Harness({
    required this.database,
    required this.offline,
    required this.api,
    required this.adapter,
  });

  static Future<_Harness> create({
    _FirstFailure firstFailure = _FirstFailure.receiveTimeout,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final adapter = _LostResponseIdempotentAdapter(firstFailure);
    final client = ApiClient(tokenProvider: () async => 'token')
      ..dio.httpClientAdapter = adapter;
    final offline = OfflineSyncService(database: database, apiClient: client);
    await offline.ensureCacheOwner('user-1');
    return _Harness(
      database: database,
      offline: offline,
      api: FinanceApi(client, offline: offline),
      adapter: adapter,
    );
  }

  final JsonLocalDatabase database;
  final OfflineSyncService offline;
  final FinanceApi api;
  final _LostResponseIdempotentAdapter adapter;
}

class _LostResponseIdempotentAdapter implements HttpClientAdapter {
  _LostResponseIdempotentAdapter(this.firstFailure);

  final _FirstFailure firstFailure;
  final Map<String, _CommittedMutation> _committed = {};
  final Set<String> _lostResponses = {};
  final List<String> mutationRequestIds = [];

  int costCommits = 0;
  int initialPaymentCommits = 0;
  int paymentCommits = 0;
  int scheduleCommits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') return _get(options);

    final requestId = options.headers[ApiClient.clientRequestIdHeader]
        ?.toString()
        .trim();
    if (requestId == null || requestId.isEmpty) {
      throw StateError('financial mutation did not include a request id');
    }
    mutationRequestIds.add(requestId);
    final payload = Map<String, dynamic>.from(options.data as Map);
    final fingerprint =
        '${options.method}:${options.path}:${jsonEncode(payload)}';
    final existing = _committed[requestId];
    late final Map<String, dynamic> response;
    if (existing == null) {
      response = _commit(options.path, payload);
      _committed[requestId] = _CommittedMutation(fingerprint, response);
    } else {
      if (existing.fingerprint != fingerprint) {
        throw StateError('request id was reused with a different mutation');
      }
      response = existing.response;
    }

    if (_lostResponses.add(requestId)) {
      throw switch (firstFailure) {
        _FirstFailure.receiveTimeout => DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: 'server committed but the response was lost',
        ),
        _FirstFailure.sendTimeout => DioException(
          requestOptions: options,
          type: DioExceptionType.sendTimeout,
          message: 'request outcome is unknown after send timeout',
        ),
        _FirstFailure.serverError => DioException(
          requestOptions: options,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 500,
            data: const {'message': 'result storage failed after commit'},
          ),
          type: DioExceptionType.badResponse,
        ),
      };
    }
    return _json(response);
  }

  ResponseBody _get(RequestOptions options) {
    if (options.path == '/api/v1/costs/cost-1/payment-schedules') {
      return _jsonList(const []);
    }
    if (options.path == '/api/v1/costs/cost-1/payments') {
      return _jsonList([
        {
          'id': 'payment-initial-1',
          'weddingPlanId': 'plan-1',
          'costId': 'cost-1',
          'amount': '100',
          'entryType': 'PAYMENT',
          'paidAt': '2026-07-14T12:00:00.000Z',
          'note': 'دفعة أولى',
          'reversible': true,
        },
      ]);
    }
    throw StateError('unexpected GET ${options.path}');
  }

  Map<String, dynamic> _commit(String path, Map<String, dynamic> payload) {
    if (path == '/api/v1/wedding-plans/plan-1/costs') {
      costCommits += 1;
      if (payload['initialPaymentAmount'] == '100') {
        initialPaymentCommits += 1;
      }
      return {
        'id': 'cost-1',
        'weddingPlanId': 'plan-1',
        'budgetCategoryId': 'category-1',
        'title': payload['title'],
        'totalAmount': '1000',
        'paidAmount': '100',
        'remainingAmount': '900',
        'status': 'PARTIALLY_PAID',
        'partyName': 'قاعة خارجية',
        'paymentsCount': 1,
      };
    }
    if (path == '/api/v1/costs/cost-1/payments') {
      paymentCommits += 1;
      return {
        'id': 'payment-1',
        'weddingPlanId': 'plan-1',
        'costId': 'cost-1',
        'amount': payload['amount'],
        'entryType': 'PAYMENT',
        'paidAt': '2026-07-14T12:00:00.000Z',
        'reversible': true,
      };
    }
    if (path == '/api/v1/costs/cost-1/payment-schedules') {
      scheduleCommits += 1;
      return {
        'id': 'schedule-1',
        'weddingPlanId': 'plan-1',
        'costId': 'cost-1',
        'amount': payload['amount'],
        'dueDate': payload['dueDate'],
        'status': 'PENDING',
      };
    }
    throw StateError('unexpected mutation $path');
  }

  ResponseBody _json(Map<String, dynamic> value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  ResponseBody _jsonList(List<Map<String, dynamic>> value) =>
      ResponseBody.fromString(
        jsonEncode(value),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

enum _FirstFailure { receiveTimeout, sendTimeout, serverError }

class _CommittedMutation {
  const _CommittedMutation(this.fingerprint, this.response);

  final String fingerprint;
  final Map<String, dynamic> response;
}

WeddingCost _cost() => const WeddingCost(
  id: 'cost-1',
  weddingPlanId: 'plan-1',
  budgetCategoryId: 'category-1',
  title: 'القاعة',
  totalAmount: '1000',
  paidAmount: '0',
  remainingAmount: '1000',
  status: 'OPEN',
  partyName: 'قاعة خارجية',
  paymentsCount: 0,
);
