import 'dart:convert';
import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/utils/arabic_sort.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/plan_day.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import 'finance_api_contracts.dart';
import 'finance_local_data_source.dart';
import 'finance_money_rules.dart';

export 'finance_api_contracts.dart';

part 'finance_api.budget.dart';
part 'finance_api.costs.dart';
part 'finance_api.payments.dart';
part 'finance_api.schedules.dart';

class FinanceApi extends _FinanceApiCore
    with
        _FinanceBudgetApi,
        _FinanceCostsApi,
        _FinancePaymentsApi,
        _FinanceSchedulesApi {
  const FinanceApi(
    this._apiClient, {
    OfflineSyncService? offline,
    LocalFinancePlanContextLoader? localPlanContextLoader,
  }) : _offline = offline,
       _localPlanContextLoader = localPlanContextLoader;

  @override
  final ApiClient _apiClient;

  @override
  final OfflineSyncService? _offline;

  @override
  final LocalFinancePlanContextLoader? _localPlanContextLoader;

  Future<MoneySummary> getMoneySummary(String planId) async {
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      final context = await _localPlanContextLoader?.call(planId);
      return _local.moneySummary(
        planId,
        estimatedBudget: context?.estimatedBudget,
        currency: context?.currency,
      );
    }
    try {
      final json = await _apiClient.getJson(
        '/api/v1/wedding-plans/$planId/money-summary',
      );
      final summary = MoneySummary.fromJson(json);
      await _cacheSummary(summary, planId);
      // D86 (C2): the server's whole answer is the phone's copy. Without
      // the server the picture is this answer, never a sum the phone makes
      // from a partial cache; what waits on the phone is counted apart.
      await _offline?.database.setMeta(_summaryKey(planId), jsonEncode(json));
      return summary;
    } on Object catch (error) {
      if (!CachePolicy.shouldUseCache(error) || _offline == null) rethrow;
      await _offline.noteNetworkFailure((error as ApiException).message);
      final cached = await cachedMoneySummary(planId);
      if (cached == null) rethrow;
      OfflineReads.noteCopyServed();
      return cached;
    }
  }

  /// D85/D86: the money picture without the server: the server's last
  /// answer for an account plan (null before the first one); the phone's
  /// own sum only for a plan kept on the phone without an account.
  Future<MoneySummary?> cachedMoneySummary(String planId) async {
    if (_offline == null) return null;
    if (FinanceLocalDataSource.isLocalGuestPlanId(planId)) {
      final context = await _localPlanContextLoader?.call(planId);
      return _local.moneySummary(
        planId,
        estimatedBudget: context?.estimatedBudget,
        currency: context?.currency,
      );
    }
    final raw = await _offline.database.getMeta(_summaryKey(planId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? MoneySummary.fromJson(Map<String, dynamic>.from(decoded))
          : null;
    } on FormatException {
      await _offline.database.deleteMeta(_summaryKey(planId));
      return null;
    }
  }

  /// D86: how many money changes of this plan still wait on the phone
  /// (queued or refused), shown beside the server's numbers.
  Future<int> pendingMoneyChangeCount(String planId) async {
    final database = _offline?.database;
    if (database == null) return 0;
    const money = {
      'cost',
      'cost_payment',
      'payment_schedule',
      'budget_category',
      'money_budget',
      'funding_source',
    };
    final items = [
      ...await database.pendingSyncItems(),
      ...await database.blockedSyncItems(),
    ];
    return items
        .where(
          (item) => item.planId == planId && money.contains(item.entityType),
        )
        .length;
  }

  static String _summaryKey(String planId) => 'money-summary:$planId';

  /// a06 for a saved plan (b01's mahr step): the owner records the mahr
  /// once; the server files it as the groom's agreement with the bride's
  /// family or the bride's money coming in (C1) and answers with the
  /// summary. A plan kept on the phone carries it in its draft instead.
  Future<MoneySummary> recordMahr(
    String planId, {
    required String total,
    required String settled,
    DateTime? remainingDueDate,
  }) async {
    // A write is sent once with its request id (retries reconcile).
    final json = await _mutation('POST', '/api/v1/wedding-plans/$planId/mahr', {
      'total': total,
      'settled': settled,
      if (remainingDueDate != null)
        'remainingDueDate': planDayToJson(remainingDueDate),
    }).send();
    final summary = MoneySummary.fromJson(json);
    await _cacheSummary(summary, planId);
    return summary;
  }
}

// The state FinanceApi's constructor provides and the infrastructure every
// resource mixin shares: caching, queued offline mutations, list reads.
abstract class _FinanceApiCore {
  const _FinanceApiCore();

  ApiClient get _apiClient;
  OfflineSyncService? get _offline;
  LocalFinancePlanContextLoader? get _localPlanContextLoader;

  FinanceLocalDataSource get _local => FinanceLocalDataSource(_offline);

  Future<void> _cacheSummary(MoneySummary summary, String planId) async {
    await _local.saveBudgetMetadata(
      planId: planId,
      totalBudget: summary.budget.total,
      currency: summary.currency,
    );
  }

  Future<List<Map<String, dynamic>>> _getJsonMapList(String path) async {
    try {
      final list = await _apiClient.getJsonList(path);
      return list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on ApiException catch (error) {
      if (error.statusCode != null || error.isNetworkFailure) rethrow;
      final json = await _apiClient.getJson(path);
      for (final key in const ['items', 'data', 'results']) {
        final value = json[key];
        if (value is List) return _listOfMaps(value);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>?> _cachedListOnNetworkFailure(
    Object error, {
    required String table,
    required String planId,
  }) async {
    if (!CachePolicy.shouldUseCache(error) || _offline == null) return null;
    await _offline.noteNetworkFailure((error as ApiException).message);
    final cached = await _readCachedPlanList(table, planId);
    if (cached.isEmpty) return null;
    OfflineReads.noteCopyServed();
    return cached;
  }

  Future<List<Map<String, dynamic>>> _readCachedPlanList(
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

  Future<void> _cache(String table, Map<String, dynamic> json) async {
    await _offline?.database.saveCachedItem(table: table, json: json);
  }

  String _requiredPlanId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      throw const FormatException(
        'Plan-scoped finance row is missing weddingPlanId',
      );
    }
    return normalized;
  }

  Future<void> _queue({
    required String entityType,
    required String operation,
    required _FinanceMutation mutation,
    required String localId,
    required String planId,
  }) async {
    final offline = _offline;
    if (offline == null) return;
    await offline.database.enqueueSync(
      entityType: entityType,
      operation: operation,
      endpoint: mutation.endpoint,
      method: mutation.method,
      payload: mutation.payload,
      planId: planId,
      localEntityId: localId,
      clientRequestId: mutation.clientRequestId,
    );
    await offline.refreshStatus();
  }

  _FinanceMutation _mutation(
    String method,
    String endpoint,
    Map<String, dynamic> payload,
  ) => _FinanceMutation(_apiClient, method, endpoint, payload, _uuidV4());
}

class _FinanceMutation {
  const _FinanceMutation(
    this.apiClient,
    this.method,
    this.endpoint,
    this.payload,
    this.clientRequestId,
  );

  final ApiClient apiClient;
  final String method;
  final String endpoint;
  final Map<String, dynamic> payload;
  final String clientRequestId;

  Future<Map<String, dynamic>> send() => apiClient.mutateJson(
    endpoint,
    payload,
    method: method,
    clientRequestId: clientRequestId,
  );
}

class FinancePage<T> {
  const FinancePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory FinancePage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return FinancePage(
      items: _listOfMaps(json['items']).map(fromJson).toList(),
      page: intOrNull(json['page']) ?? 1,
      pageSize: intOrNull(json['pageSize']) ?? 0,
      total: intOrNull(json['total']) ?? 0,
      totalPages: intOrNull(json['totalPages']) ?? 1,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

FinancePage<WeddingCost> _localCostPage(
  List<Map<String, dynamic>> raw, {
  required int page,
  required int limit,
  String? status,
  String? categoryId,
  String? search,
  String? payer,
}) {
  final query = search?.trim().toLowerCase();
  final items = raw.map(WeddingCost.fromJson).where((cost) {
    if (_nullableTrimmed(status) != null && cost.status != status) return false;
    if (_nullableTrimmed(payer) != null && cost.payer != payer) return false;
    if (_nullableTrimmed(categoryId) != null &&
        cost.budgetCategoryId != categoryId) {
      return false;
    }
    if (query != null && query.isNotEmpty) {
      // Folded, so «قاعه» finds «قاعة» and «احمد» finds «أحمد».
      final needle = arabicSearchKey(query);
      final title = arabicSearchKey(cost.title);
      final party = arabicSearchKey(cost.partyLabel ?? '');
      if (!title.contains(needle) && !party.contains(needle)) return false;
    }
    return true;
  }).toList();
  return _localPage(items, page: page, limit: limit);
}

FinancePage<T> _localPage<T>(
  List<T> items, {
  required int page,
  required int limit,
}) {
  final safePage = page < 1 ? 1 : page;
  final safeLimit = limit.clamp(1, 100);
  final start = (safePage - 1) * safeLimit;
  final end = (start + safeLimit).clamp(0, items.length);
  final pageItems = start >= items.length ? <T>[] : items.sublist(start, end);
  final pages = items.isEmpty ? 1 : (items.length / safeLimit).ceil();
  return FinancePage(
    items: pageItems,
    page: safePage,
    pageSize: safeLimit,
    total: items.length,
    totalPages: pages,
  );
}

List<PaymentSchedule> _dueSchedules(List<Map<String, dynamic>> items) {
  final today = appNow();
  final end = DateTime(
    today.year,
    today.month,
    today.day,
  ).add(const Duration(days: 30));
  return items
      .map(PaymentSchedule.fromJson)
      .where(
        (schedule) =>
            schedule.isPending &&
            (schedule.isOverdue || !schedule.dueDate.isAfter(end)),
      )
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}

bool _isServerCategoryId(String? value) {
  final id = _nullableTrimmed(value);
  return id != null && !id.startsWith('local-');
}

const _localCategoryPrefix = 'local-budget-category-';

String _clientIdForLocalCategory(String? id) {
  final value = _nullableTrimmed(id);
  if (value != null && value.startsWith(_localCategoryPrefix)) {
    final candidate = value.substring(_localCategoryPrefix.length);
    if (_uuidV4Pattern.hasMatch(candidate)) return candidate;
  }
  return _uuidV4();
}

String _localCategoryId(String? clientId) {
  final value = _nullableTrimmed(clientId);
  if (value == null || !_uuidV4Pattern.hasMatch(value)) {
    throw const ApiException(
      'تعذر حفظ التصنيف الجديد: معرّف المزامنة غير صالح.',
    );
  }
  return '$_localCategoryPrefix$value';
}

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

Map<String, dynamic> _budgetCategoryJson(BudgetCategory category) {
  return {
    'id': category.id,
    'weddingPlanId': category.weddingPlanId,
    'name': category.name,
    'allocatedAmount': category.allocatedAmount,
    'confirmedCost': category.confirmedCost,
    'paid': category.paid,
    'outstanding': category.outstanding,
    'remainingAllocation': category.remainingAllocation,
    'costsCount': category.costsCount,
    'createdAt': category.createdAt?.toIso8601String(),
    'updatedAt': category.updatedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _paymentScheduleJson(
  PaymentSchedule schedule, {
  required String status,
  required DateTime? paidAt,
  required DateTime updatedAt,
}) {
  return {
    'id': schedule.id,
    'costId': schedule.costId,
    'weddingPlanId': schedule.weddingPlanId,
    'budgetCategoryId': schedule.budgetCategoryId,
    'categoryName': schedule.categoryName,
    'providerId': schedule.providerId,
    'providerName': schedule.providerName,
    'costTitle': schedule.costTitle,
    'amount': schedule.amount,
    'dueDate': schedule.dueDate.toIso8601String(),
    'status': status,
    'paidAt': paidAt?.toIso8601String(),
    'note': schedule.note,
    'createdAt': schedule.createdAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

String? _nullableTrimmed(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
