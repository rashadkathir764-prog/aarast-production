import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/utils/app_clock.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import 'finance_local_serializers.dart';
import 'finance_local_summary.dart';
import 'finance_money_rules.dart';

int _lastLocalEntityMicros = 0;

String _nextLocalEntityId(String prefix) {
  var micros = DateTime.now().microsecondsSinceEpoch;
  if (micros <= _lastLocalEntityMicros) micros = _lastLocalEntityMicros + 1;
  _lastLocalEntityMicros = micros;
  return '$prefix-$micros';
}

/// Finance persistence and aggregation that run entirely on the encrypted
/// mobile cache. Network and sync-queue orchestration belong to [FinanceApi].
class FinanceLocalDataSource {
  const FinanceLocalDataSource(this._offline);

  final OfflineSyncService? _offline;

  static bool isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }

  static String budgetMetaKey(String planId) => 'money_budget:$planId';

  Future<Map<String, dynamic>?> readBudget(String planId) async {
    final raw = await _offline?.database.getMeta(budgetMetaKey(planId));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  Future<void> saveBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<Map<String, dynamic>> categories,
  }) async {
    await saveBudgetMetadata(
      planId: planId,
      totalBudget: totalBudget,
      currency: currency,
    );
    await _offline?.database.replaceCachedList(
      table: OfflineTables.cachedBudgetCategories,
      items: categories,
      parentColumn: 'planId',
      parentId: planId,
      preserveDirty: false,
    );
    await _offline?.refreshStatus();
  }

  Future<void> saveBudgetMetadata({
    required String planId,
    required String? totalBudget,
    required String currency,
  }) async {
    await _offline?.database.setMeta(
      budgetMetaKey(planId),
      jsonEncode({
        'totalBudget': totalBudget,
        'currency': currency,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
    await _offline?.refreshStatus();
  }

  Future<MoneySummary> moneySummary(
    String planId, {
    String? estimatedBudget,
    String? currency,
    MoneyFundingSummary? funding,
  }) async {
    final budget = await readBudget(planId);
    final totalBudget = _nullableMoney(
      budget?['totalBudget'] ?? estimatedBudget,
    );
    final resolvedCurrency =
        stringOrNull(budget?['currency']) ??
        stringOrNull(currency)?.toUpperCase() ??
        'YER';
    final rawCategories = await _readPlanList(
      OfflineTables.cachedBudgetCategories,
      planId,
    );
    final costs = (await _readPlanList(
      OfflineTables.cachedCosts,
      planId,
    )).where((cost) => cost['status']?.toString() != 'CANCELLED').toList();
    final activeCostIds = costs
        .map((cost) => cost['id']?.toString())
        .whereType<String>()
        .toSet();
    final payments =
        (await _readPlanList(OfflineTables.cachedCostPayments, planId)).where(
          (payment) => activeCostIds.contains(payment['costId']?.toString()),
        );
    final schedules =
        (await _readPlanList(OfflineTables.cachedPaymentSchedules, planId))
            .where(
              (schedule) =>
                  activeCostIds.contains(schedule['costId']?.toString()),
            )
            .toList();

    final total = FinanceMoneyRules.value(totalBudget);
    final allocated = rawCategories.fold<num>(
      0,
      (sum, category) =>
          sum + FinanceMoneyRules.value(category['allocatedAmount']),
    );
    final costTotal = costs.fold<num>(
      0,
      (sum, cost) => sum + FinanceMoneyRules.value(cost['totalAmount']),
    );
    final paidByCost = localNetPaidByCost(payments);
    final paidTotal = costs.fold<num>(
      0,
      (sum, cost) => sum + (paidByCost[cost['id']?.toString()] ?? 0),
    );
    final outstanding = (costTotal - paidTotal).clamp(0, costTotal);
    final categorySummaries = rawCategories.map((raw) {
      final id = raw['id']?.toString() ?? '';
      final categoryCosts = costs
          .where((cost) => cost['budgetCategoryId']?.toString() == id)
          .toList();
      final confirmed = categoryCosts.fold<num>(
        0,
        (sum, cost) => sum + FinanceMoneyRules.value(cost['totalAmount']),
      );
      final paid = categoryCosts.fold<num>(
        0,
        (sum, cost) => sum + (paidByCost[cost['id']?.toString()] ?? 0),
      );
      final allocation = _nullableMoney(raw['allocatedAmount']);
      return MoneyCategorySummary(
        categoryId: id,
        name: raw['name']?.toString() ?? '',
        allocatedAmount: allocation,
        confirmedCost: FinanceMoneyRules.asMoney(confirmed) ?? '0',
        paid: FinanceMoneyRules.asMoney(paid) ?? '0',
        outstanding:
            FinanceMoneyRules.asMoney((confirmed - paid).clamp(0, confirmed)) ??
            '0',
        remainingAllocation: allocation == null
            ? null
            : FinanceMoneyRules.asMoney(
                FinanceMoneyRules.value(allocation) - confirmed,
              ),
        costsCount: categoryCosts.length,
      );
    }).toList();

    final scheduleSummary = LocalPaymentScheduleSummary.from(
      schedules,
      _today(),
    );

    final warnings = <MoneyWarning>[
      if (totalBudget != null && costTotal > total)
        MoneyWarning(
          type: 'BUDGET_EXCEEDED',
          severity: 'DANGER',
          amount: FinanceMoneyRules.asMoney(costTotal - total),
        ),
      for (final category in categorySummaries)
        if (category.allocatedAmount != null &&
            FinanceMoneyRules.value(category.confirmedCost) >
                FinanceMoneyRules.value(category.allocatedAmount))
          MoneyWarning(
            type: 'CATEGORY_EXCEEDED',
            severity: 'DANGER',
            categoryId: category.categoryId,
            count: category.costsCount,
            amount: FinanceMoneyRules.asMoney(
              FinanceMoneyRules.value(category.confirmedCost) -
                  FinanceMoneyRules.value(category.allocatedAmount),
            ),
          ),
      if (scheduleSummary.overdueCount > 0)
        MoneyWarning(
          type: 'PAYMENT_SCHEDULE_OVERDUE',
          severity: 'DANGER',
          count: scheduleSummary.overdueCount,
        ),
      if (scheduleSummary.dueSoonCount > 0)
        MoneyWarning(
          type: 'PAYMENT_SCHEDULE_DUE_SOON',
          severity: 'WARNING',
          count: scheduleSummary.dueSoonCount,
        ),
    ];

    return MoneySummary(
      planId: planId,
      currency: resolvedCurrency,
      budget: MoneyBudgetSummary(
        total: totalBudget,
        allocated: FinanceMoneyRules.asMoney(allocated) ?? '0',
        unallocated: totalBudget == null
            ? null
            : FinanceMoneyRules.asMoney(total - allocated),
        confirmedCost: FinanceMoneyRules.asMoney(costTotal) ?? '0',
        remaining: totalBudget == null
            ? null
            : FinanceMoneyRules.asMoney(total - costTotal),
      ),
      costs: MoneyCostsSummary(
        total: FinanceMoneyRules.asMoney(costTotal) ?? '0',
        paid: FinanceMoneyRules.asMoney(paidTotal) ?? '0',
        outstanding: FinanceMoneyRules.asMoney(outstanding) ?? '0',
        count: costs.length,
      ),
      paymentSchedules: MoneySchedulesSummary(
        totalCount: schedules.length,
        upcomingCount: scheduleSummary.upcomingCount,
        overdueCount: scheduleSummary.overdueCount,
        paidCount: scheduleSummary.paidCount,
        next: scheduleSummary.pending.isEmpty
            ? null
            : PaymentSchedule.fromJson(scheduleSummary.pending.first),
      ),
      categories: categorySummaries,
      warnings: warnings,
      funding: funding,
      permissions: const MoneyPermissions(
        canViewMoney: true,
        canManageMoney: true,
      ),
    );
  }

  Future<BudgetCategory> createBudgetCategory({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final json = {
      'id': _nextLocalEntityId('local-budget-category'),
      'weddingPlanId': weddingPlanId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _save(OfflineTables.cachedBudgetCategories, json, dirty: true);
    return BudgetCategory.fromJson(json);
  }

  Future<BudgetCategory> updateBudgetCategory({
    required BudgetCategory category,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _read(
      OfflineTables.cachedBudgetCategories,
      category.id,
    );
    final json = {
      ...?cached,
      ...payload,
      'id': category.id,
      'weddingPlanId': category.weddingPlanId,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _save(OfflineTables.cachedBudgetCategories, json, dirty: true);
    return BudgetCategory.fromJson(json);
  }

  Future<bool> categoryHasCosts(String categoryId) async {
    final costs = await _offline?.database.readCachedList(
      table: OfflineTables.cachedCosts,
    );
    return (costs ?? const <Map<String, dynamic>>[]).any(
      (cost) =>
          cost['budgetCategoryId']?.toString() == categoryId &&
          cost['status']?.toString() != 'CANCELLED',
    );
  }

  Future<WeddingCost> createCost({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    FinanceMoneyRules.assertCostAmounts(
      totalAmount: payload['totalAmount']?.toString() ?? '',
      initialPaymentAmount: payload['initialPaymentAmount']?.toString(),
    );
    final now = DateTime.now();
    final total = FinanceMoneyRules.value(payload['totalAmount']);
    final initial = FinanceMoneyRules.value(payload['initialPaymentAmount']);
    final costId = _nextLocalEntityId('local-cost');
    final costPayload = Map<String, dynamic>.from(payload)
      ..remove('initialPaymentAmount');
    final json = {
      ...costPayload,
      'id': costId,
      'weddingPlanId': weddingPlanId,
      'paidAmount': FinanceMoneyRules.asMoney(initial),
      'remainingAmount': FinanceMoneyRules.asMoney(total - initial),
      'status': FinanceMoneyRules.costStatus(total, initial),
      'paymentsCount': initial > 0 ? 1 : 0,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _save(OfflineTables.cachedCosts, json, dirty: true);
    if (initial > 0) {
      await _createPaymentCache(
        cost: json,
        payload: {
          'amount': FinanceMoneyRules.asMoney(initial),
          'paidAt': payload['agreementDate'] ?? now.toIso8601String(),
          'note': 'دفعة أولى',
        },
        updateCost: false,
      );
    }
    return WeddingCost.fromJson(json);
  }

  Future<WeddingCost> updateCost({
    required WeddingCost cost,
    required Map<String, dynamic> payload,
  }) async {
    final cached = await _read(OfflineTables.cachedCosts, cost.id);
    // D86: a cancelled agreement is not edited; the server refuses (409).
    if ((cached?['status'] ?? cost.status) == 'CANCELLED') {
      throw const ApiException('الاتفاق ملغي، ما يتعدّل.');
    }
    final total = FinanceMoneyRules.assertPositive(
      payload['totalAmount'],
      'إجمالي الاتفاق',
    );
    final paid = FinanceMoneyRules.value(
      cached?['paidAmount'] ?? cost.paidAmount,
    );
    if (total < paid) {
      throw const ApiException('إجمالي الاتفاق ما ينقص عن المدفوع.');
    }
    final json = <String, dynamic>{
      ...?cached,
      ...payload,
      'id': cost.id,
      'weddingPlanId': cost.weddingPlanId,
      'paidAmount': FinanceMoneyRules.asMoney(paid),
      'remainingAmount': FinanceMoneyRules.asMoney(total - paid),
      'status': cost.isCancelled
          ? 'CANCELLED'
          : FinanceMoneyRules.costStatus(total, paid),
      'updatedAt': DateTime.now().toIso8601String(),
    }..remove('dueDate');
    await _save(OfflineTables.cachedCosts, json, dirty: true);
    return WeddingCost.fromJson(json);
  }

  Future<void> markDeleted({required String table, required String id}) async {
    final cached = await _read(table, id);
    if (cached == null) return;
    await _offline?.database.saveCachedItem(
      table: table,
      json: cached,
      dirty: true,
      deletedLocally: true,
    );
  }

  Future<WeddingCost> cancelCost(WeddingCost cost) async {
    final cached = await _read(OfflineTables.cachedCosts, cost.id);
    final current = cached == null ? cost : WeddingCost.fromJson(cached);
    if (current.hasActivePayments) {
      throw const ApiException('اعكس الدفعات القائمة أولًا قبل إلغاء التكلفة.');
    }
    final json = <String, dynamic>{
      ...?cached,
      'id': cost.id,
      'weddingPlanId': cost.weddingPlanId,
      'status': 'CANCELLED',
      'updatedAt': DateTime.now().toIso8601String(),
    }..remove('dueDate');
    await _save(OfflineTables.cachedCosts, json, dirty: true);
    await _cancelPendingSchedules(current.id);
    return WeddingCost.fromJson(json);
  }

  Future<CostPayment> createPayment({
    required WeddingCost cost,
    required Map<String, dynamic> payload,
  }) async {
    final currentCost = await _currentCost(cost);
    final amount = FinanceMoneyRules.assertPositive(
      payload['amount'],
      'المبلغ',
    );
    FinanceMoneyRules.assertPaymentWithinRemaining(
      cost: {
        'totalAmount': currentCost.totalAmount,
        'paidAmount': currentCost.paidAmount,
        'status': currentCost.status,
      },
      amount: amount,
    );
    return _createPaymentCache(
      cost: weddingCostToLocalJson(currentCost),
      payload: payload,
    );
  }

  Future<CostPayment> reversePayment({
    required CostPayment payment,
    required WeddingCost cost,
    required String reason,
  }) async {
    if (!payment.reversible || payment.isReversal || payment.isReversed) {
      throw const ApiException('هذي الدفعة ما تنعكس.');
    }
    final currentCost = await _currentCost(cost);
    final now = DateTime.now();
    final reversalId = _nextLocalEntityId('local-cost-payment');
    final reversal = {
      'id': reversalId,
      'weddingPlanId': currentCost.weddingPlanId,
      'costId': currentCost.id,
      'amount': payment.amount,
      'entryType': 'REVERSAL',
      'paidAt': now.toIso8601String(),
      'reversalOfId': payment.id,
      'note': reason.trim(),
      'createdAt': now.toIso8601String(),
    };
    await _save(OfflineTables.cachedCostPayments, reversal, dirty: true);
    await _save(OfflineTables.cachedCostPayments, {
      ...costPaymentToLocalJson(payment),
      'reversedById': reversalId,
      'reversible': false,
    }, dirty: true);
    await _restoreScheduleAfterReversal(payment.paymentScheduleId);
    final paid =
        (FinanceMoneyRules.value(currentCost.paidAmount) -
                FinanceMoneyRules.value(payment.amount))
            .clamp(0, FinanceMoneyRules.value(currentCost.totalAmount));
    await _updateCostBalance(currentCost, paid);
    return CostPayment.fromJson(reversal);
  }

  Future<PaymentSchedule> createSchedule({
    required WeddingCost cost,
    required Map<String, dynamic> payload,
  }) async {
    final currentCost = await _currentCost(cost);
    if (currentCost.isCancelled || currentCost.isPaid) {
      throw const ApiException('الاتفاق خالص أو ملغي، ما يحتاج موعد دفع.');
    }
    final amount = FinanceMoneyRules.assertPositive(
      payload['amount'],
      'المبلغ',
    );
    FinanceMoneyRules.assertScheduleWithinRemaining(
      amount: amount,
      remainingAmount: FinanceMoneyRules.value(currentCost.remainingAmount),
    );
    final now = DateTime.now();
    final json = {
      'id': _nextLocalEntityId('local-payment-schedule'),
      'weddingPlanId': currentCost.weddingPlanId,
      'costId': currentCost.id,
      ...payload,
      'status': 'PENDING',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _save(OfflineTables.cachedPaymentSchedules, json, dirty: true);
    return PaymentSchedule.fromJson(json);
  }

  Future<PaymentSchedule> updateSchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
    required Map<String, dynamic> payload,
  }) async {
    if (!schedule.isPending) {
      throw const ApiException('الموعد مدفوع أو ملغي، ما يتعدّل.');
    }
    if (schedule.paidAt != null) {
      throw const ApiException('هذا الموعد اندفع من قبل، ما يتعدّل.');
    }
    final currentCost = await _currentCost(cost);
    final amount = FinanceMoneyRules.assertPositive(
      payload['amount'],
      'المبلغ',
    );
    FinanceMoneyRules.assertScheduleWithinRemaining(
      amount: amount,
      remainingAmount: FinanceMoneyRules.value(currentCost.remainingAmount),
    );
    final cached = await _read(
      OfflineTables.cachedPaymentSchedules,
      schedule.id,
    );
    final json = {
      ...?cached,
      ...payload,
      'id': schedule.id,
      'weddingPlanId': currentCost.weddingPlanId,
      'costId': currentCost.id,
      'status': 'PENDING',
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _save(OfflineTables.cachedPaymentSchedules, json, dirty: true);
    return PaymentSchedule.fromJson(json);
  }

  Future<CostPayment> paySchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
    required Map<String, dynamic> payload,
  }) async {
    if (!schedule.isPending) {
      throw const ApiException('هذا الموعد ما يندفع الحين.');
    }
    final currentCost = await _currentCost(cost);
    if (FinanceMoneyRules.value(schedule.amount) >
        FinanceMoneyRules.value(currentCost.remainingAmount)) {
      throw const ApiException('مبلغ الموعد يتجاوز غير المدفوع على التكلفة.');
    }
    final payment = await _createPaymentCache(
      cost: weddingCostToLocalJson(currentCost),
      payload: {
        ...payload,
        'amount': schedule.amount,
        'paymentScheduleId': schedule.id,
      },
    );
    await _save(OfflineTables.cachedPaymentSchedules, {
      ...paymentScheduleToLocalJson(schedule),
      'status': 'PAID',
      'paidAt': payment.paidAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, dirty: true);
    return payment;
  }

  Future<CostPayment> _createPaymentCache({
    required Map<String, dynamic> cost,
    required Map<String, dynamic> payload,
    bool updateCost = true,
  }) async {
    final amount = FinanceMoneyRules.assertPositive(
      payload['amount'],
      'المبلغ',
    );
    final now = DateTime.now();
    final json = {
      'id': _nextLocalEntityId('local-cost-payment'),
      'weddingPlanId': cost['weddingPlanId'],
      'costId': cost['id'],
      'amount': FinanceMoneyRules.asMoney(amount),
      'entryType': 'PAYMENT',
      'paidAt': payload['paidAt'] ?? now.toIso8601String(),
      if (payload['paymentScheduleId'] != null)
        'paymentScheduleId': payload['paymentScheduleId'],
      if (payload['method'] != null) 'method': payload['method'],
      if (payload['note'] != null) 'note': payload['note'],
      'reversible': true,
      'createdAt': now.toIso8601String(),
    };
    await _save(OfflineTables.cachedCostPayments, json, dirty: true);
    if (updateCost) {
      final paid = FinanceMoneyRules.value(cost['paidAmount']) + amount;
      await _updateCostBalance(
        WeddingCost.fromJson(cost),
        paid,
        exceptScheduleId: payload['paymentScheduleId']?.toString(),
      );
    }
    return CostPayment.fromJson(json);
  }

  Future<void> _updateCostBalance(
    WeddingCost cost,
    num paid, {
    String? exceptScheduleId,
  }) async {
    final total = FinanceMoneyRules.value(cost.totalAmount);
    final cached = await _read(OfflineTables.cachedCosts, cost.id);
    final json = <String, dynamic>{
      ...?cached,
      ...weddingCostToLocalJson(cost),
      'paidAmount': FinanceMoneyRules.asMoney(paid),
      'remainingAmount': FinanceMoneyRules.asMoney(
        (total - paid).clamp(0, total),
      ),
      'status': cost.isCancelled
          ? 'CANCELLED'
          : FinanceMoneyRules.costStatus(total, paid),
      'paymentsCount': (cost.paymentsCount ?? 0) + 1,
      'updatedAt': DateTime.now().toIso8601String(),
    }..remove('dueDate');
    await _save(OfflineTables.cachedCosts, json, dirty: true);
    if (json['status'] == 'PAID') {
      await _cancelPendingSchedules(
        cost.id,
        exceptScheduleId: exceptScheduleId,
      );
    }
  }

  Future<void> _cancelPendingSchedules(
    String costId, {
    String? exceptScheduleId,
  }) async {
    final schedules = await _offline?.database.readCachedList(
      table: OfflineTables.cachedPaymentSchedules,
    );
    for (final schedule in schedules ?? const <Map<String, dynamic>>[]) {
      if (schedule['costId']?.toString() != costId ||
          schedule['status']?.toString() != 'PENDING' ||
          schedule['id']?.toString() == exceptScheduleId) {
        continue;
      }
      await _save(OfflineTables.cachedPaymentSchedules, {
        ...schedule,
        'status': 'CANCELLED',
        'updatedAt': DateTime.now().toIso8601String(),
      }, dirty: true);
    }
  }

  Future<void> _restoreScheduleAfterReversal(String? scheduleId) async {
    final id = scheduleId?.trim();
    if (id == null || id.isEmpty) return;
    final cached = await _read(OfflineTables.cachedPaymentSchedules, id);
    if (cached == null) return;
    await _save(OfflineTables.cachedPaymentSchedules, {
      ...cached,
      'status': 'PENDING',
      'paidAt': null,
      'updatedAt': DateTime.now().toIso8601String(),
    }, dirty: true);
  }

  Future<WeddingCost> _currentCost(WeddingCost fallback) async {
    final cached = await _read(OfflineTables.cachedCosts, fallback.id);
    return cached == null ? fallback : WeddingCost.fromJson(cached);
  }

  Future<List<Map<String, dynamic>>> _readPlanList(
    String table,
    String planId,
  ) async {
    return await _offline?.database.readCachedList(
          table: table,
          parentColumn: 'planId',
          parentId: planId,
        ) ??
        const [];
  }

  Future<Map<String, dynamic>?> _read(String table, String id) {
    return _offline?.database.readCachedItem(table: table, id: id) ??
        Future.value(null);
  }

  Future<void> _save(
    String table,
    Map<String, dynamic> json, {
    required bool dirty,
  }) async {
    await _offline?.database.saveCachedItem(
      table: table,
      json: json,
      dirty: dirty,
    );
    await _offline?.refreshStatus();
  }
}

String? _nullableMoney(Object? value) {
  final text = value?.toString().replaceAll(',', '').trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime _today() {
  final now = appNow();
  return DateTime(now.year, now.month, now.day);
}
