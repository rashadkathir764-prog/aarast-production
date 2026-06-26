import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../models/debt.dart';
import '../models/debt_summary.dart';
import '../models/installment.dart';

class DebtInstallmentApi {
  const DebtInstallmentApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  Future<List<Debt>> getDebts(String weddingPlanId) async {
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final cached = await _offline?.database.readCachedList(
        table: OfflineTables.cachedDebts,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .map(Debt.fromJson)
          .toList();
    }
    try {
      final items = await _getJsonMapList(
        '/wedding-plans/$weddingPlanId/debts',
      );
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedDebts,
        items: items,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return items.map(Debt.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedDebts,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (cached != null) return cached.map(Debt.fromJson).toList();
      rethrow;
    }
  }

  Future<DebtSummary> getDebtSummary(String weddingPlanId) async {
    final key = 'debt_summary:$weddingPlanId';
    if (_isLocalGuestPlanId(weddingPlanId)) {
      final debts = await _offline?.database.readCachedList(
        table: OfflineTables.cachedDebts,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      return _summaryFromDebts(debts ?? const <Map<String, dynamic>>[]);
    }
    try {
      final json = await _apiClient.getJson(
        '/wedding-plans/$weddingPlanId/debts/summary',
      );
      await _offline?.database.setMeta(key, jsonEncode(json));
      return DebtSummary.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached != null) {
        return DebtSummary.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      }
      final debts = await _offline.database.readCachedList(
        table: OfflineTables.cachedDebts,
        parentColumn: 'planId',
        parentId: weddingPlanId,
      );
      if (debts.isNotEmpty) return _summaryFromDebts(debts);
      rethrow;
    }
  }

  Future<Debt> createDebt({
    required String weddingPlanId,
    required String creditorName,
    required String title,
    required String totalAmount,
    String? creditorPhone,
    String? paidAmount,
    DateTime? dueDate,
    String status = 'OPEN',
    String? note,
  }) async {
    final normalizedCreditorPhone = _normalizeOptionalPhone(creditorPhone);
    final payload = {
      'creditorName': creditorName.trim(),
      'title': title.trim(),
      'totalAmount': totalAmount.trim(),
      'status': status,
      if (paidAmount != null && paidAmount.trim().isNotEmpty)
        'paidAmount': paidAmount.trim(),
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    if (normalizedCreditorPhone != null) {
      payload['creditorPhone'] = normalizedCreditorPhone;
    }
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return _createLocalDebt(weddingPlanId: weddingPlanId, payload: payload);
    }
    try {
      final json = await _apiClient.postJson(
        '/wedding-plans/$weddingPlanId/debts',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedDebts,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return Debt.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = 'local-debt-${now.microsecondsSinceEpoch}';
      final localJson = {
        'id': localId,
        'weddingPlanId': weddingPlanId,
        'paidAmount': '0',
        ...payload,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedDebts,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'debt',
        operation: 'create',
        endpoint: '/wedding-plans/$weddingPlanId/debts',
        method: 'POST',
        payload: payload,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return Debt.fromJson(localJson);
    }
  }

  Future<Debt> updateDebt(String id, Map<String, dynamic> data) async {
    if (id.startsWith('local-debt-')) {
      return _updateLocalDebt(id: id, data: data);
    }
    final json = await _apiClient.patchJson('/debts/$id', data);
    return Debt.fromJson(json);
  }

  Future<void> deleteDebt(String id) async {
    await _apiClient.deleteJson('/debts/$id');
  }

  Future<List<Installment>> getInstallments(String debtId) async {
    if (debtId.startsWith('local-debt-')) {
      final cached = await _offline?.database.readCachedList(
        table: OfflineTables.cachedInstallments,
        parentColumn: 'debtId',
        parentId: debtId,
      );
      return (cached ?? const <Map<String, dynamic>>[])
          .map(Installment.fromJson)
          .toList();
    }
    try {
      final items = await _getJsonMapList('/debts/$debtId/installments');
      await _offline?.database.replaceCachedList(
        table: OfflineTables.cachedInstallments,
        items: items,
        parentColumn: 'debtId',
        parentId: debtId,
      );
      return items.map(Installment.fromJson).toList();
    } on Object catch (error) {
      final cached = await _cachedListOnNetworkFailure(
        error,
        table: OfflineTables.cachedInstallments,
        parentColumn: 'debtId',
        parentId: debtId,
      );
      if (cached != null) return cached.map(Installment.fromJson).toList();
      rethrow;
    }
  }

  Future<List<Installment>> getDueInstallments(String weddingPlanId) async {
    final key = 'due_installments:$weddingPlanId';
    if (_isLocalGuestPlanId(weddingPlanId)) {
      return const [];
    }
    try {
      final items = await _getJsonMapList(
        '/wedding-plans/$weddingPlanId/installments/due',
      );
      await _offline?.database.setMeta(key, jsonEncode(items));
      return items.map(Installment.fromJson).toList();
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await _offline.database.getMeta(key);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Installment.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
  }

  Future<Installment> createInstallment({
    required String debtId,
    required String amount,
    DateTime? dueDate,
    DateTime? paidAt,
    String status = 'PENDING',
    String? note,
  }) async {
    final payload = {
      'amount': amount.trim(),
      'status': status,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    if (debtId.startsWith('local-debt-')) {
      return _createLocalInstallment(debtId: debtId, payload: payload);
    }
    try {
      final json = await _apiClient.postJson(
        '/debts/$debtId/installments',
        payload,
      );
      await _offline?.database.saveCachedItem(
        table: OfflineTables.cachedInstallments,
        json: json,
      );
      await _offline?.syncPendingChanges();
      return Installment.fromJson(json);
    } on Object catch (error) {
      if (!CachePolicy.shouldQueueWrite(error) || _offline == null) rethrow;
      final now = DateTime.now();
      final localId = 'local-installment-${now.microsecondsSinceEpoch}';
      final localJson = {
        'id': localId,
        'debtId': debtId,
        ...payload,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };
      await _offline.database.saveCachedItem(
        table: OfflineTables.cachedInstallments,
        json: localJson,
        dirty: true,
      );
      await _offline.database.enqueueSync(
        entityType: 'installment',
        operation: 'create',
        endpoint: '/debts/$debtId/installments',
        method: 'POST',
        payload: payload,
        localEntityId: localId,
      );
      await _offline.refreshStatus();
      return Installment.fromJson(localJson);
    }
  }

  Future<Installment> updateInstallment(
    String id,
    Map<String, dynamic> data,
  ) async {
    final json = await _apiClient.patchJson('/installments/$id', data);
    return Installment.fromJson(json);
  }

  Future<void> deleteInstallment(String id) async {
    await _apiClient.deleteJson('/installments/$id');
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    final list = await _apiClient.getJsonList(path);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>?> _cachedListOnNetworkFailure(
    Object error, {
    required String table,
    String? parentColumn,
    String? parentId,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _offline.database.readCachedList(
      table: table,
      parentColumn: parentColumn,
      parentId: parentId,
    );
    return cached.isEmpty ? null : cached;
  }

  DebtSummary _summaryFromDebts(List<Map<String, dynamic>> debts) {
    num totalDebt = 0;
    num totalPaid = 0;
    var countOpen = 0;
    var countPartiallyPaid = 0;
    var countPaid = 0;
    var countCancelled = 0;
    for (final debt in debts) {
      final total = num.tryParse(debt['totalAmount']?.toString() ?? '') ?? 0;
      final paid = num.tryParse(debt['paidAmount']?.toString() ?? '') ?? 0;
      totalDebt += total;
      totalPaid += paid;
      switch (debt['status']?.toString()) {
        case 'PAID':
          countPaid++;
        case 'PARTIALLY_PAID':
          countPartiallyPaid++;
        case 'CANCELLED':
          countCancelled++;
        default:
          countOpen++;
      }
    }
    final remaining = (totalDebt - totalPaid).clamp(0, totalDebt);
    return DebtSummary(
      totalDebt: totalDebt.toStringAsFixed(2),
      totalPaid: totalPaid.toStringAsFixed(2),
      remainingDebt: remaining.toStringAsFixed(2),
      countOpen: countOpen,
      countPartiallyPaid: countPartiallyPaid,
      countPaid: countPaid,
      countCancelled: countCancelled,
    );
  }

  Future<Debt> _createLocalDebt({
    required String weddingPlanId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localId = 'local-debt-${now.microsecondsSinceEpoch}';
    final localJson = {
      'id': localId,
      'weddingPlanId': weddingPlanId,
      'paidAmount': '0',
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedDebts,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Debt.fromJson(localJson);
  }

  Future<Debt> _updateLocalDebt({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final cached = await _offline?.database.readCachedItem(
      table: OfflineTables.cachedDebts,
      id: id,
    );
    final now = DateTime.now();
    final localJson = {
      ...?cached,
      ...data,
      'id': id,
      'weddingPlanId': cached?['weddingPlanId'] ?? '',
      'createdAt': cached?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedDebts,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Debt.fromJson(localJson);
  }

  Future<Installment> _createLocalInstallment({
    required String debtId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final localJson = {
      'id': 'local-installment-${now.microsecondsSinceEpoch}',
      'debtId': debtId,
      ...payload,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    await _offline?.database.saveCachedItem(
      table: OfflineTables.cachedInstallments,
      json: localJson,
      dirty: true,
    );
    await _offline?.refreshStatus();
    return Installment.fromJson(localJson);
  }

  String? _normalizeOptionalPhone(String? phone) {
    try {
      return PhoneNumberUtils.normalizeOptional(phone);
    } on FormatException {
      throw const ApiException('أدخل رقم جوال صحيح.');
    }
  }

  bool _isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }
}
