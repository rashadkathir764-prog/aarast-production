import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clientId = '7b38c528-3b2e-4eb7-9a9c-d8f7d2ca5a0b';
const _localCategoryId = 'local-budget-category-$_clientId';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'JSON queue atomically keeps only the latest entity replacement',
    () async {
      final database = await _freshDatabase();
      await database.enqueueSync(
        entityType: 'money_budget',
        operation: 'replace',
        endpoint: '/api/v1/wedding-plans/plan-1/money-budget',
        method: 'PUT',
        payload: {'totalBudget': '100'},
        localEntityId: 'plan-1',
        replacePendingForEntity: true,
      );
      await database.enqueueSync(
        entityType: 'money_budget',
        operation: 'replace',
        endpoint: '/api/v1/wedding-plans/plan-1/money-budget',
        method: 'PUT',
        payload: {'totalBudget': '250'},
        localEntityId: 'plan-1',
        replacePendingForEntity: true,
      );
      await database.enqueueSync(
        entityType: 'money_budget',
        operation: 'replace',
        endpoint: '/api/v1/wedding-plans/plan-2/money-budget',
        method: 'PUT',
        payload: {'totalBudget': '900'},
        localEntityId: 'plan-2',
        replacePendingForEntity: true,
      );

      final pending = await database.pendingSyncItems();
      expect(pending, hasLength(2));
      expect(
        pending.singleWhere((item) => item.localEntityId == 'plan-1').payload,
        {'totalBudget': '250'},
      );
    },
  );

  test(
    'queued endpoint, payload, and entity id are rewritten together',
    () async {
      final database = await _freshDatabase();
      await database.enqueueSync(
        entityType: 'cost',
        operation: 'update',
        endpoint: '/api/v1/costs/local-cost-1',
        method: 'PATCH',
        payload: {'relatedId': 'local-cost-1'},
        localEntityId: 'local-cost-1',
      );

      await database.rewriteQueuedReferences(
        localId: 'local-cost-1',
        remoteId: 'cost-1',
      );

      final queued = (await database.pendingSyncItems()).single;
      expect(queued.endpoint, '/api/v1/costs/cost-1');
      expect(queued.payload['relatedId'], 'cost-1');
      expect(queued.localEntityId, 'cost-1');
    },
  );

  test(
    'money budget wrapper maps category ids before dependent cost replay',
    () async {
      final database = await _freshDatabase();
      await database.saveCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        json: {
          'id': _localCategoryId,
          'clientId': _clientId,
          'weddingPlanId': 'plan-1',
          'name': 'القاعة',
          'allocatedAmount': '250000',
        },
        dirty: true,
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: {
          'id': 'local-cost-1',
          'weddingPlanId': 'plan-1',
          'budgetCategoryId': _localCategoryId,
          'title': 'تكلفة القاعة',
          'totalAmount': '300000',
          'paidAmount': '0',
          'status': 'OPEN',
        },
        dirty: true,
      );
      await database.enqueueSync(
        entityType: 'money_budget',
        operation: 'replace',
        endpoint: '/api/v1/wedding-plans/plan-1/money-budget',
        method: 'PUT',
        payload: {
          'totalBudget': '1000000',
          'currency': 'YER',
          'categories': [
            {
              'clientId': _clientId,
              'name': 'القاعة',
              'allocatedAmount': '250000',
            },
          ],
        },
        localEntityId: 'plan-1',
        replacePendingForEntity: true,
      );
      await database.enqueueSync(
        entityType: 'cost',
        operation: 'create',
        endpoint: '/api/v1/wedding-plans/plan-1/costs',
        method: 'POST',
        payload: {
          'budgetCategoryId': _localCategoryId,
          'title': 'تكلفة القاعة',
          'totalAmount': '300000',
        },
        localEntityId: 'local-cost-1',
      );
      final pendingBeforeSync = await database.pendingSyncItems();
      expect(
        pendingBeforeSync.map((item) => item.id).toSet(),
        hasLength(pendingBeforeSync.length),
        reason: 'queue ids must remain unique inside one clock tick',
      );
      expect(pendingBeforeSync, hasLength(2));

      final adapter = _MoneySyncAdapter();
      final apiClient = ApiClient(tokenProvider: () async => 'token')
        ..dio.httpClientAdapter = adapter;
      final service = OfflineSyncService(
        database: database,
        apiClient: apiClient,
      );
      await service.ensureCacheOwner('user-1');

      await service.syncPendingChanges();

      final pendingAfterSync = await database.pendingSyncItems();
      expect(
        adapter.requests,
        hasLength(2),
        reason:
            'state=${service.state}; error=${service.lastError}; '
            'pending=${pendingAfterSync.map((item) => '${item.entityType}:${item.operation}:${item.lastError}').toList()}',
      );
      expect(
        (adapter.requests[1].data as Map)['budgetCategoryId'],
        'server-category-1',
        reason: 'the sync loop must re-read the rewritten queued payload',
      );
      expect(await database.pendingSyncCount(), 0);

      final rawBudget = await database.getMeta('money_budget:plan-1');
      final budget = jsonDecode(rawBudget!) as Map<String, dynamic>;
      expect(budget['totalBudget'], '1000000');
      expect(budget['currency'], 'YER');

      final categories = await database.readCachedList(
        table: OfflineTables.cachedBudgetCategories,
        parentColumn: 'planId',
        parentId: 'plan-1',
      );
      expect(categories, hasLength(1));
      expect(categories.single['id'], 'server-category-1');
      expect(categories.single.containsKey('summary'), isFalse);

      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedCosts,
          id: 'local-cost-1',
        ),
        isNull,
      );
      final remoteCost = await database.readCachedItem(
        table: OfflineTables.cachedCosts,
        id: 'server-cost-1',
      );
      expect(remoteCost?['budgetCategoryId'], 'server-category-1');

      // A server category cached from the wrapper is clean and therefore is
      // replaceable by a later authoritative list refresh.
      await database.replaceCachedList(
        table: OfflineTables.cachedBudgetCategories,
        items: const [],
        parentColumn: 'planId',
        parentId: 'plan-1',
      );
      expect(
        await database.readCachedList(
          table: OfflineTables.cachedBudgetCategories,
          parentColumn: 'planId',
          parentId: 'plan-1',
        ),
        isEmpty,
      );
    },
  );

  test('SQLite coalescing is implemented inside one transaction', () {
    final source = File(
      'lib/core/offline/local_database_mobile.dart',
    ).readAsStringSync();
    expect(source, contains('replacePendingForEntity'));
    expect(source, contains('await _db.transaction((txn) async'));
    expect(source, contains("'entityType = ? AND operation = ? AND '"));
    expect(source, contains('await txn.insert(OfflineTables.syncQueue'));
  });

  test('FinanceApi coalesces offline money budget edits by plan', () async {
    final database = await _freshDatabase();
    final client = _OfflineFinanceClient();
    final offline = OfflineSyncService(database: database, apiClient: client);
    await offline.initialize();
    final api = FinanceApi(client, offline: offline);

    final first = await api.replaceMoneyBudget(
      planId: 'plan-1',
      totalBudget: '1000',
      currency: 'YER',
      categories: const [(id: null, name: 'القاعة', allocatedAmount: '400')],
    );
    final localCategoryId = first.categories.single.id;
    await api.replaceMoneyBudget(
      planId: 'plan-1',
      totalBudget: '1200',
      currency: 'YER',
      categories: [
        (id: localCategoryId, name: 'قاعة الحفل', allocatedAmount: '500'),
      ],
    );

    final queued = await database.pendingSyncItems();
    expect(queued, hasLength(1));
    expect(queued.single.entityType, 'money_budget');
    expect(queued.single.payload['totalBudget'], '1200');
    expect(
      ((queued.single.payload['categories'] as List).single as Map)['clientId'],
      localCategoryId.replaceFirst('local-budget-category-', ''),
    );
    final cached = await database.readCachedList(
      table: OfflineTables.cachedBudgetCategories,
      parentColumn: 'planId',
      parentId: 'plan-1',
    );
    expect(cached, hasLength(1));
    expect(cached.single['name'], 'قاعة الحفل');
  });

  test('online budget idMap rewrites cached dependent category ids', () async {
    final database = await _freshDatabase();
    await database.saveCachedItem(
      table: OfflineTables.cachedBudgetCategories,
      json: {
        'id': _localCategoryId,
        'weddingPlanId': 'plan-1',
        'name': 'القاعة',
        'allocatedAmount': '400',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: {
        ..._costJson(_cost(id: 'local-cost-1')),
        'budgetCategoryId': _localCategoryId,
      },
      dirty: true,
    );
    final client = _OnlineBudgetClient();
    final offline = OfflineSyncService(database: database, apiClient: client);
    await offline.initialize();

    await FinanceApi(client, offline: offline).replaceMoneyBudget(
      planId: 'plan-1',
      totalBudget: '1000',
      currency: 'YER',
      categories: const [
        (id: _localCategoryId, name: 'القاعة', allocatedAmount: '400'),
      ],
    );

    final cost = await database.readCachedItem(
      table: OfflineTables.cachedCosts,
      id: 'local-cost-1',
    );
    expect(cost?['budgetCategoryId'], 'server-category-1');
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedBudgetCategories,
        id: _localCategoryId,
      ),
      isNull,
    );
  });

  test(
    'remote-plan local ids remain queued through dependent money writes',
    () async {
      final database = await _freshDatabase();
      final client = _OfflineFinanceClient();
      final offline = OfflineSyncService(database: database, apiClient: client);
      await offline.initialize();
      final api = FinanceApi(client, offline: offline);

      final cost = await api.createCost(
        planId: 'plan-1',
        budgetCategoryId: 'category-1',
        title: 'القاعة',
        totalAmount: '1000',
        partyName: 'قاعة خارجية',
      );
      final updated = await api.updateCost(
        cost: cost,
        budgetCategoryId: 'category-1',
        title: 'قاعة الحفل',
        totalAmount: '1000',
        partyName: 'قاعة خارجية',
      );
      final payment = await api.createPayment(cost: updated, amount: '100');
      await api.reversePayment(
        payment: payment,
        cost: _withBalance(updated, paidAmount: '100', remainingAmount: '900'),
        reason: 'تصحيح الدفعة',
      );
      final schedule = await api.createSchedule(
        cost: updated,
        amount: '200',
        dueDate: DateTime(2026, 8, 1),
      );
      final changedSchedule = await api.updateSchedule(
        schedule: schedule,
        cost: updated,
        amount: '250',
        dueDate: DateTime(2026, 8, 2),
      );
      await api.paySchedule(schedule: changedSchedule, cost: updated);

      final queued = await database.pendingSyncItems();
      expect(
        queued.map((item) => '${item.entityType}:${item.operation}'),
        containsAll([
          'cost:create',
          'cost:update',
          'cost_payment:create',
          'cost_payment:reverse',
          'payment_schedule:create',
          'payment_schedule:update',
          'payment_schedule:pay',
        ]),
      );
      expect(
        queued
            .where((item) => item.operation != 'create')
            .every(
              (item) =>
                  item.endpoint.contains('local-') ||
                  item.localEntityId?.startsWith('local-') == true,
            ),
        isTrue,
      );
    },
  );

  test(
    'server-id reversal and schedule pay queue on network failure',
    () async {
      final database = await _freshDatabase();
      final client = _OfflineFinanceClient();
      final offline = OfflineSyncService(database: database, apiClient: client);
      await offline.initialize();
      final api = FinanceApi(client, offline: offline);
      final cost = _cost(id: 'cost-1', paidAmount: '300');
      final payment = CostPayment(
        id: 'payment-1',
        costId: cost.id,
        amount: '100',
        paidAt: DateTime(2026, 7, 14),
        entryType: 'PAYMENT',
        reversible: true,
        paymentScheduleId: 'paid-schedule-1',
        weddingPlanId: cost.weddingPlanId,
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 'paid-schedule-1',
          'weddingPlanId': cost.weddingPlanId,
          'costId': cost.id,
          'amount': '100',
          'dueDate': '2026-07-10T00:00:00.000Z',
          'paidAt': '2026-07-14T00:00:00.000Z',
          'status': 'PAID',
        },
      );
      final schedule = PaymentSchedule(
        id: 'schedule-1',
        costId: cost.id,
        amount: '200',
        dueDate: DateTime(2026, 8, 1),
        status: 'PENDING',
        weddingPlanId: cost.weddingPlanId,
      );

      final reversal = await api.reversePayment(
        payment: payment,
        cost: cost,
        reason: 'تصحيح',
      );
      final scheduledPayment = await api.paySchedule(
        schedule: schedule,
        cost: _withBalance(cost, paidAmount: '200', remainingAmount: '800'),
      );

      expect(reversal.id, startsWith('local-cost-payment-'));
      final restoredSchedule = await database.readCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        id: 'paid-schedule-1',
      );
      expect(restoredSchedule?['status'], 'PENDING');
      expect(restoredSchedule?['paidAt'], isNull);
      expect(scheduledPayment.id, startsWith('local-cost-payment-'));
      final queued = await database.pendingSyncItems();
      expect(
        queued.map((item) => '${item.operation}:${item.endpoint}'),
        containsAll([
          'reverse:/api/v1/cost-payments/payment-1/reverse',
          'pay:/api/v1/payment-schedules/schedule-1/pay',
        ]),
      );
    },
  );

  test('repeated offline payments use cached balance and unique ids', () async {
    final database = await _freshDatabase();
    final client = _OfflineFinanceClient();
    final offline = OfflineSyncService(database: database, apiClient: client);
    await offline.initialize();
    final api = FinanceApi(client, offline: offline);
    final staleCost = await api.createCost(
      planId: 'plan-1',
      budgetCategoryId: 'category-1',
      title: 'القاعة',
      totalAmount: '1000',
      partyName: 'قاعة خارجية',
    );

    final first = await api.createPayment(cost: staleCost, amount: '100');
    final second = await api.createPayment(cost: staleCost, amount: '100');

    expect(first.id, isNot(second.id));
    final cachedCost = await database.readCachedItem(
      table: OfflineTables.cachedCosts,
      id: staleCost.id,
    );
    expect(cachedCost?['paidAmount'], '200.00');
    expect(cachedCost?['remainingAmount'], '800.00');
    expect(cachedCost?['paymentsCount'], 2);
  });

  test('reversal sync seals the original payment in cache', () async {
    final database = await _freshDatabase();
    await database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: _costJson(_cost(id: 'cost-1')),
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedCostPayments,
      json: {
        'id': 'payment-1',
        'weddingPlanId': 'plan-1',
        'costId': 'cost-1',
        'amount': '100',
        'entryType': 'PAYMENT',
        'paidAt': '2026-07-14T12:00:00.000Z',
        'reversedById': 'local-cost-payment-reversal',
        'reversible': false,
        'paymentScheduleId': 'schedule-1',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedPaymentSchedules,
      json: {
        'id': 'schedule-1',
        'weddingPlanId': 'plan-1',
        'costId': 'cost-1',
        'amount': '100',
        'dueDate': '2026-07-10T00:00:00.000Z',
        'paidAt': '2026-07-14T12:00:00.000Z',
        'status': 'PAID',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedCostPayments,
      json: {
        'id': 'local-cost-payment-reversal',
        'weddingPlanId': 'plan-1',
        'costId': 'cost-1',
        'amount': '100',
        'entryType': 'REVERSAL',
        'reversalOfId': 'payment-1',
        'paidAt': '2026-07-14T12:01:00.000Z',
        'reversible': false,
      },
      dirty: true,
    );
    await database.enqueueSync(
      entityType: 'cost_payment',
      operation: 'reverse',
      endpoint: '/api/v1/cost-payments/payment-1/reverse',
      method: 'POST',
      payload: {'reason': 'تصحيح'},
      localEntityId: 'local-cost-payment-reversal',
    );
    final client = ApiClient(tokenProvider: () async => 'token')
      ..dio.httpClientAdapter = _StaticJsonAdapter({
        'id': 'payment-reversal-1',
        'weddingPlanId': 'plan-1',
        'costId': 'cost-1',
        'amount': '100',
        'entryType': 'REVERSAL',
        'reversalOfId': 'payment-1',
        'paidAt': '2026-07-14T12:01:00.000Z',
        'reversible': false,
      });
    final service = OfflineSyncService(database: database, apiClient: client);
    await service.ensureCacheOwner('user-1');

    await service.syncPendingChanges();

    final source = await database.readCachedItem(
      table: OfflineTables.cachedCostPayments,
      id: 'payment-1',
    );
    expect(source?['reversedById'], 'payment-reversal-1');
    expect(source?['reversible'], isFalse);
    final restoredSchedule = await database.readCachedItem(
      table: OfflineTables.cachedPaymentSchedules,
      id: 'schedule-1',
    );
    expect(restoredSchedule?['status'], 'PENDING');
    expect(restoredSchedule?['paidAt'], isNull);
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedCostPayments,
        id: 'local-cost-payment-reversal',
      ),
      isNull,
    );
  });

  test(
    'schedule pay wrapper maps payment and cleans derived balance',
    () async {
      final database = await _freshDatabase();
      await database.saveCachedItem(
        table: OfflineTables.cachedCosts,
        json: _costJson(_cost(id: 'cost-1', paidAmount: '200')),
        dirty: true,
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: {
          'id': 'schedule-1',
          'weddingPlanId': 'plan-1',
          'costId': 'cost-1',
          'amount': '200',
          'dueDate': '2026-08-01T00:00:00.000Z',
          'status': 'PAID',
          'paidAt': '2026-07-14T12:00:00.000Z',
        },
        dirty: true,
      );
      await database.saveCachedItem(
        table: OfflineTables.cachedCostPayments,
        json: {
          'id': 'local-cost-payment-1',
          'weddingPlanId': 'plan-1',
          'costId': 'cost-1',
          'paymentScheduleId': 'schedule-1',
          'amount': '200',
          'entryType': 'PAYMENT',
          'paidAt': '2026-07-14T12:00:00.000Z',
          'reversible': true,
        },
        dirty: true,
      );
      await database.enqueueSync(
        entityType: 'payment_schedule',
        operation: 'pay',
        endpoint: '/api/v1/payment-schedules/schedule-1/pay',
        method: 'POST',
        payload: const {},
        localEntityId: 'local-cost-payment-1',
      );

      final client = ApiClient(tokenProvider: () async => 'token')
        ..dio.httpClientAdapter = _StaticJsonAdapter({
          'payment': {
            'id': 'payment-1',
            'weddingPlanId': 'plan-1',
            'costId': 'cost-1',
            'paymentScheduleId': 'schedule-1',
            'amount': '200',
            'entryType': 'PAYMENT',
            'paidAt': '2026-07-14T12:00:00.000Z',
            'reversible': true,
          },
          'schedule': {
            'id': 'schedule-1',
            'weddingPlanId': 'plan-1',
            'costId': 'cost-1',
            'amount': '200',
            'dueDate': '2026-08-01T00:00:00.000Z',
            'status': 'PAID',
            'paidAt': '2026-07-14T12:00:00.000Z',
          },
        });
      final service = OfflineSyncService(database: database, apiClient: client);
      await service.ensureCacheOwner('user-1');
      await service.syncPendingChanges();

      expect(await database.pendingSyncCount(), 0);
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedCostPayments,
          id: 'local-cost-payment-1',
        ),
        isNull,
      );
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedCostPayments,
          id: 'payment-1',
        ),
        isNotNull,
      );
      expect(
        (await database.readCachedItem(
          table: OfflineTables.cachedPaymentSchedules,
          id: 'schedule-1',
        ))?['status'],
        'PAID',
      );
      await database.replaceCachedList(
        table: OfflineTables.cachedCosts,
        items: const [],
        parentColumn: 'planId',
        parentId: 'plan-1',
      );
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedCosts,
          id: 'cost-1',
        ),
        isNull,
        reason: 'the locally derived balance must be clean after sync',
      );
    },
  );

  test('delete sync response never becomes a fake cached entity', () async {
    final database = await _freshDatabase();
    await database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: _costJson(_cost(id: 'cost-1')),
      dirty: true,
    );
    await database.enqueueSync(
      entityType: 'cost',
      operation: 'delete',
      endpoint: '/api/v1/costs/cost-1',
      method: 'DELETE',
      payload: const {},
      localEntityId: 'cost-1',
    );
    final client = ApiClient(tokenProvider: () async => 'token')
      ..dio.httpClientAdapter = _StaticJsonAdapter({'deleted': true});
    final service = OfflineSyncService(database: database, apiClient: client);
    await service.ensureCacheOwner('user-1');
    await service.syncPendingChanges();

    expect(await database.pendingSyncCount(), 0);
    expect(
      await database.readCachedItem(
        table: OfflineTables.cachedCosts,
        id: 'cost-1',
      ),
      isNull,
    );
    expect(
      await database.readCachedList(table: OfflineTables.cachedCosts),
      isEmpty,
    );
  });

  test(
    'offline initial payment keeps payload and receives its server id',
    () async {
      final database = await _freshDatabase();
      final offlineClient = _OfflineFinanceClient();
      final offline = OfflineSyncService(
        database: database,
        apiClient: offlineClient,
      );
      await offline.initialize();
      final api = FinanceApi(offlineClient, offline: offline);
      final localCost = await api.createCost(
        planId: 'plan-1',
        budgetCategoryId: 'category-1',
        title: 'القاعة',
        totalAmount: '1000',
        initialPaymentAmount: '100',
        partyName: 'قاعة خارجية',
      );
      final queuedBeforeSync = await database.pendingSyncItems();
      expect(queuedBeforeSync.single.payload['initialPaymentAmount'], '100');
      final localPayments = await database.readCachedList(
        table: OfflineTables.cachedCostPayments,
      );
      expect(localPayments, hasLength(1));
      final localPaymentId = localPayments.single['id']!.toString();

      final adapter = _InitialCostSyncAdapter();
      final onlineClient = ApiClient(tokenProvider: () async => 'token')
        ..dio.httpClientAdapter = adapter;
      final sync = OfflineSyncService(
        database: database,
        apiClient: onlineClient,
      );
      await sync.ensureCacheOwner('user-1');
      await sync.syncPendingChanges();

      expect(adapter.requests.map((item) => item.path), [
        '/api/v1/wedding-plans/plan-1/costs',
        '/api/v1/costs/cost-1/payments',
      ]);
      expect(await database.pendingSyncCount(), 0);
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedCosts,
          id: localCost.id,
        ),
        isNull,
      );
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedCostPayments,
          id: localPaymentId,
        ),
        isNull,
      );
      expect(
        await database.readCachedItem(
          table: OfflineTables.cachedCostPayments,
          id: 'payment-1',
        ),
        isNotNull,
      );
    },
  );
}

Future<JsonLocalDatabase> _freshDatabase() async {
  final preferences = await SharedPreferences.getInstance();
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  return database;
}

WeddingCost _cost({required String id, String paidAmount = '0'}) {
  final paid = num.parse(paidAmount);
  return WeddingCost(
    id: id,
    weddingPlanId: 'plan-1',
    budgetCategoryId: 'category-1',
    title: 'القاعة',
    totalAmount: '1000',
    paidAmount: paidAmount,
    remainingAmount: (1000 - paid).toString(),
    status: paid > 0 ? 'PARTIALLY_PAID' : 'OPEN',
    partyName: 'قاعة خارجية',
    paymentsCount: paid > 0 ? 1 : 0,
  );
}

WeddingCost _withBalance(
  WeddingCost cost, {
  required String paidAmount,
  required String remainingAmount,
}) {
  return WeddingCost(
    id: cost.id,
    weddingPlanId: cost.weddingPlanId,
    budgetCategoryId: cost.budgetCategoryId,
    title: cost.title,
    totalAmount: cost.totalAmount,
    paidAmount: paidAmount,
    remainingAmount: remainingAmount,
    status: num.parse(paidAmount) > 0 ? 'PARTIALLY_PAID' : 'OPEN',
    providerId: cost.providerId,
    quoteOfferId: cost.quoteOfferId,
    partyName: cost.partyName,
    partyPhone: cost.partyPhone,
    note: cost.note,
    agreementDate: cost.agreementDate,
    dueDate: cost.dueDate,
    paymentsCount: num.parse(paidAmount) > 0 ? 1 : 0,
    categoryName: cost.categoryName,
    providerName: cost.providerName,
    createdAt: cost.createdAt,
    updatedAt: cost.updatedAt,
  );
}

Map<String, dynamic> _costJson(WeddingCost cost) => {
  'id': cost.id,
  'weddingPlanId': cost.weddingPlanId,
  'budgetCategoryId': cost.budgetCategoryId,
  'title': cost.title,
  'totalAmount': cost.totalAmount,
  'paidAmount': cost.paidAmount,
  'remainingAmount': cost.remainingAmount,
  'status': cost.status,
  'partyName': cost.partyName,
  'paymentsCount': cost.paymentsCount,
};

class _OfflineFinanceClient extends ApiClient {
  _OfflineFinanceClient() : super(tokenProvider: () async => null);

  static const _offline = ApiException(
    aarastBackendConnectionErrorMessage,
    isNetworkFailure: true,
  );

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) async => throw _offline;

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async => throw _offline;

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> data,
  ) async => throw _offline;

  @override
  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> data,
  ) async => throw _offline;

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async => throw _offline;
}

class _OnlineBudgetClient extends ApiClient {
  _OnlineBudgetClient() : super(tokenProvider: () async => null);

  @override
  Future<Map<String, dynamic>> mutateJson(
    String path,
    Map<String, dynamic> data, {
    required String method,
    required String clientRequestId,
  }) => putJson(path, data);

  @override
  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    return {
      'summary': {
        'planId': 'plan-1',
        'currency': 'YER',
        'budget': {
          'total': '1000',
          'allocated': '400',
          'unallocated': '600',
          'confirmedCost': '1000',
          'remaining': '0',
        },
        'costs': {
          'total': '1000',
          'paid': '0',
          'outstanding': '1000',
          'count': 1,
        },
        'paymentSchedules': {'upcomingCount': 0, 'overdueCount': 0},
        'categories': const [],
        'warnings': const [],
        'permissions': {'canViewMoney': true, 'canManageMoney': true},
      },
      'categories': [
        {
          'id': 'server-category-1',
          'weddingPlanId': 'plan-1',
          'name': 'القاعة',
          'allocatedAmount': '400',
          'costsCount': 1,
        },
      ],
      'idMap': {_clientId: 'server-category-1'},
    };
  }
}

class _StaticJsonAdapter implements HttpClientAdapter {
  _StaticJsonAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

class _InitialCostSyncAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Object body = options.path.endsWith('/payments')
        ? [
            {
              'id': 'payment-1',
              'weddingPlanId': 'plan-1',
              'costId': 'cost-1',
              'amount': '100',
              'entryType': 'PAYMENT',
              'paidAt': '2026-07-14T12:00:00.000Z',
              'note': 'دفعة أولى',
              'reversible': true,
            },
          ]
        : {
            'id': 'cost-1',
            'weddingPlanId': 'plan-1',
            'budgetCategoryId': 'category-1',
            'title': 'القاعة',
            'totalAmount': '1000',
            'paidAmount': '100',
            'remainingAmount': '900',
            'status': 'PARTIALLY_PAID',
            'paymentsCount': 1,
          };
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

class _MoneySyncAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = requests.length == 1
        ? jsonEncode({
            'summary': {
              'currency': 'YER',
              'budget': {'total': '1000000'},
            },
            'categories': [
              {
                'id': 'server-category-1',
                'weddingPlanId': 'plan-1',
                'name': 'القاعة',
                'allocatedAmount': '250000',
              },
            ],
            'idMap': {_clientId: 'server-category-1'},
          })
        : jsonEncode({
            'id': 'server-cost-1',
            'weddingPlanId': 'plan-1',
            'budgetCategoryId': 'server-category-1',
            'title': 'تكلفة القاعة',
            'totalAmount': '300000',
            'paidAmount': '0',
            'status': 'OPEN',
          });
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
