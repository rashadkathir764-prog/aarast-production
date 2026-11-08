import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/plan_day.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import 'finance_local_money_plan.dart';
import 'finance_local_serializers.dart';
import 'finance_local_summary.dart';
import 'finance_money_rules.dart';

part 'finance_local_money_summary.dart';
part 'finance_local_schedules.dart';

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
    // D109: the whole budget names the items and their allocations; an
    // item's own estimate is kept unless the save names it (as the server).
    final saved = {
      for (final item in await _readPlanList(
        OfflineTables.cachedBudgetCategories,
        planId,
      ))
        item['id']?.toString(): item,
    };
    await _offline?.database.replaceCachedList(
      table: OfflineTables.cachedBudgetCategories,
      items: [
        for (final item in categories)
          item.containsKey('estimatedAmount')
              ? item
              : {
                  ...item,
                  'estimatedAmount':
                      saved[item['id']?.toString()]?['estimatedAmount'],
                },
      ],
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

  /// The money picture of a plan kept on the phone (finance_local_money_summary.dart).
  Future<MoneySummary> moneySummary(
    String planId, {
    String? estimatedBudget,
    String? currency,
    MoneyFundingSummary? funding,
    String? persona,
  }) => _localMoneySummary(
    planId,
    estimatedBudget: estimatedBudget,
    currency: currency,
    funding: funding,
    persona: persona,
  );

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
    // D107: an expense is paid in full the day it is recorded.
    final isExpense = payload['entryKind'] == 'EXPENSE';
    final initial = isExpense
        ? total
        : FinanceMoneyRules.value(payload['initialPaymentAmount']);
    final costId = _nextLocalEntityId('local-cost');
    final costPayload = Map<String, dynamic>.from(payload)
      ..remove('initialPaymentAmount')
      ..addAll(_coverOf(payload, isExpense: isExpense, total: total));
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
          'note': isExpense ? 'دفعتها كاملة' : 'دفعة أولى',
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
    final current = cached == null ? cost : WeddingCost.fromJson(cached);
    // D107: an expense's amount is its payment.
    if (current.isExpense &&
        paid > 0 &&
        total != FinanceMoneyRules.value(current.totalAmount)) {
      throw const ApiException(
        'مبلغ المصروف هو اللي دفعته. لو غلطت فيه، تراجع عن دفعته وسجّله من جديد.',
      );
    }
    final json = <String, dynamic>{
      ...?cached,
      ...payload,
      if (payload.containsKey('estimateCover'))
        ..._coverOf(payload, isExpense: current.isExpense, total: total),
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
    // RA-BE-53: a new total changes what is left, so what each reminder asks.
    await _refreshScheduleDues(cost.id, json['remainingAmount'].toString());
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
    await _giveBackPartialPayment(payment, currentCost.id);
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
    if (payload['remindAt'] != null) {
      _assertRemindDay(payload['remindAt'], payload['dueDate']);
    }
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
    final cached = await _read(
      OfflineTables.cachedPaymentSchedules,
      schedule.id,
    );
    final current = cached == null
        ? schedule
        : PaymentSchedule.fromJson(cached);
    final amount = FinanceMoneyRules.assertPositive(
      payload['amount'],
      'المبلغ',
    );
    // RA-BE-109: only a new amount is a new claim on what is left; moving
    // the day or the note of a date that asks less than its amount is not
    // refused for it.
    if (amount != FinanceMoneyRules.value(current.amount)) {
      FinanceMoneyRules.assertScheduleWithinRemaining(
        amount: amount,
        remainingAmount: FinanceMoneyRules.value(currentCost.remainingAmount),
      );
    }
    // D106: a new due day keeps the first one, and its own reminder goes
    // back to the default; a reminder day is between today and the due day.
    final dueDay = _dayOf(payload['dueDate']) ?? _dayOf(current.dueDate)!;
    final moved = dueDay != _dayOf(current.dueDate);
    final firstDue = current.rescheduledFrom ?? current.dueDate;
    final Object? remindAt;
    if (payload.containsKey('remindAt')) {
      remindAt = payload['remindAt'];
      if (remindAt != null) _assertRemindDay(remindAt, dueDay);
    } else {
      remindAt = moved ? null : cached?['remindAt'];
    }
    final json = {
      ...?cached,
      ...payload,
      'id': schedule.id,
      'weddingPlanId': currentCost.weddingPlanId,
      'costId': currentCost.id,
      'status': 'PENDING',
      'remindAt': remindAt,
      'rescheduledFrom': moved
          ? (dueDay == _dayOf(firstDue) ? null : firstDue.toIso8601String())
          : cached?['rescheduledFrom'],
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
    final cached = await _read(
      OfflineTables.cachedPaymentSchedules,
      schedule.id,
    );
    final current = cached == null
        ? schedule
        : PaymentSchedule.fromJson(cached);
    // RA-BE-53: as the server does, the reminder pays what its agreement
    // still owes at most. Refusing its whole amount over the remaining left
    // a reminder that could never be paid after a straight payment.
    final due = FinanceMoneyRules.value(
      current.withRemaining(currentCost.remainingAmount).dueAmount,
    );
    if (due <= 0) {
      throw const ApiException('هذا الاتفاق مدفوع كله، فما فيه شي يندفع.');
    }
    // D106: what was paid, when it is not what the date asks for; never
    // more than what is left on the agreement.
    final paid = payload['amount'] == null
        ? due
        : FinanceMoneyRules.assertPositive(payload['amount'], 'المبلغ');
    FinanceMoneyRules.assertPaymentWithinRemaining(
      cost: {
        'totalAmount': currentCost.totalAmount,
        'paidAmount': currentCost.paidAmount,
        'status': currentCost.status,
      },
      amount: paid,
    );
    final rest = Map<String, dynamic>.from(payload)..remove('amount');
    if (paid < due) {
      // Less than it asks: a payment on the agreement linked to the date,
      // and the date asks for that much less (the server's ledger keeps a
      // paid date equal to its one payment).
      final payment = await _createPaymentCache(
        cost: weddingCostToLocalJson(currentCost),
        payload: {
          ...rest,
          'amount': FinanceMoneyRules.asMoney(paid),
          'lowersScheduleId': schedule.id,
        },
      );
      final after =
          await _read(OfflineTables.cachedPaymentSchedules, schedule.id) ??
          paymentScheduleToLocalJson(current);
      await _save(OfflineTables.cachedPaymentSchedules, {
        ...after,
        'amount': FinanceMoneyRules.asMoney(due - paid),
        'updatedAt': DateTime.now().toIso8601String(),
      }, dirty: true);
      final costNow = await _currentCost(currentCost);
      await _refreshScheduleDues(costNow.id, costNow.remainingAmount);
      return payment;
    }
    final payment = await _createPaymentCache(
      cost: weddingCostToLocalJson(currentCost),
      payload: {
        ...rest,
        'amount': FinanceMoneyRules.asMoney(due),
        'paymentScheduleId': schedule.id,
      },
    );
    await _save(OfflineTables.cachedPaymentSchedules, {
      ...paymentScheduleToLocalJson(current),
      // As the server keeps it: a paid reminder records what was paid.
      'amount': FinanceMoneyRules.asMoney(due),
      'amountDue': '0',
      'status': 'PAID',
      'paidAt': payment.paidAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, dirty: true);
    if (paid > due) {
      // More than it asks: the rest is a payment on the agreement.
      final costNow = await _currentCost(currentCost);
      await _createPaymentCache(
        cost: weddingCostToLocalJson(costNow),
        payload: {...rest, 'amount': FinanceMoneyRules.asMoney(paid - due)},
      );
    }
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
      if (payload['lowersScheduleId'] != null)
        'lowersScheduleId': payload['lowersScheduleId'],
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
    } else {
      await _refreshScheduleDues(cost.id, json['remainingAmount'].toString());
    }
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
