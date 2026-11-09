import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
import '../models/funding_source.dart';
import 'finance_local_data_source.dart';

/// Funding sources and loan repayments.
///
/// D85: the list is the phone's copy when the server is out of reach, and
/// every change is kept on the phone and sent when the server answers. A
/// repayment on a loan the server has not named yet stays on the phone
/// with its loan's create; its own status waits for that create.
///
/// A plan kept on the phone (a guest's, before an account) has no plan on
/// the server: its sources are the phone's alone, read and written there,
/// online or not (asking the server answered 401 and lost them). Saving the
/// plan to an account carries them (RA-MO-43).
class FundingApi {
  FundingApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _offline = offline,
      _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineSyncService? _offline;
  final OfflineReads _reads;
  final OfflineWrites _writes;

  static bool _onPhone(String? planId) =>
      FinanceLocalDataSource.isLocalGuestPlanId(planId);

  /// A row of a plan kept on the phone: written as it is, nothing to send.
  Future<Map<String, dynamic>> _keep(Map<String, dynamic> json) async {
    await _offline?.database.saveCachedItem(table: _table, json: json);
    return json;
  }

  static const _table = OfflineTables.cachedFundingSources;

  String _base(String weddingPlanId) =>
      '/api/v1/wedding-plans/$weddingPlanId/funding-sources';

  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async {
    if (_onPhone(weddingPlanId)) return cachedFundingSources(weddingPlanId);
    final items = await _reads.list(
      _base(weddingPlanId),
      table: _table,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return items.map(FundingSource.fromJson).toList();
  }

  /// The phone's copy alone.
  Future<List<FundingSource>> cachedFundingSources(String weddingPlanId) async {
    final rows = await _reads.cachedList(
      _table,
      parentColumn: 'planId',
      parentId: weddingPlanId,
    );
    return rows.map(FundingSource.fromJson).toList();
  }

  Future<FundingSource> createFundingSource({
    required String weddingPlanId,
    required String kind,
    required String sourceName,
    required String amount,
    required String status,
    String? sourcePhone,
    String? note,
    DateTime? expectedAt,
    String? contributorName,
  }) async {
    final payload = {
      'kind': kind,
      'sourceName': sourceName.trim(),
      'amount': amount,
      'status': status,
      'sourcePhone': ?_trimmedOrNull(sourcePhone),
      // D108: who gave or promised it.
      'contributorName': ?_trimmedOrNull(contributorName),
      'note': ?_trimmedOrNull(note),
      'expectedAt': ?_date(expectedAt),
    };
    if (_onPhone(weddingPlanId)) {
      return FundingSource.fromJson(
        await _keep({
          'id': 'local-funding-${DateTime.now().microsecondsSinceEpoch}',
          'weddingPlanId': weddingPlanId,
          ...payload,
          'repayments': const [],
        }),
      );
    }
    final localId = OfflineWrites.localId('funding');
    final json = await _writes.queued(
      entityType: 'funding_source',
      operation: 'create',
      method: 'POST',
      endpoint: _base(weddingPlanId),
      payload: payload,
      table: _table,
      localJson: {
        'id': localId,
        'weddingPlanId': weddingPlanId,
        ...payload,
        'repayments': const [],
      },
      planId: weddingPlanId,
      localEntityId: localId,
    );
    return FundingSource.fromJson(json);
  }

  Future<FundingSource> updateFundingSource(
    FundingSource source, {
    required String kind,
    required String sourceName,
    required String amount,
    required String status,
    String? sourcePhone,
    String? note,
    DateTime? expectedAt,
    // D108: who it is from, sent when the form named them; null keeps it
    // (an edit that does not ask, «وصلت؟»).
    String? contributorName,
  }) async {
    final payload = {
      'kind': kind,
      'sourceName': sourceName.trim(),
      'amount': amount,
      'status': status,
      'sourcePhone': _trimmedOrNull(sourcePhone),
      'contributorName': ?_trimmedOrNull(contributorName),
      'note': _trimmedOrNull(note),
      // D59: the promised day is the whole field: null clears it.
      'expectedAt': _date(expectedAt),
    };
    final localJson = {...source.toJson(), ...payload};
    if (_onPhone(source.weddingPlanId)) {
      return FundingSource.fromJson(await _keep(localJson));
    }
    final json = await _writes.queued(
      entityType: 'funding_source',
      operation: 'update',
      method: 'PATCH',
      endpoint: '/api/v1/funding-sources/${source.id}',
      payload: payload,
      table: _table,
      localJson: localJson,
      planId: source.weddingPlanId,
      localEntityId: source.id,
      replacePendingForEntity: true,
      pendingCreate: PendingCreate(
        endpoint: _base(source.weddingPlanId),
        payload: {
          for (final entry in payload.entries)
            if (entry.value != null) entry.key: entry.value,
        },
      ),
    );
    return FundingSource.fromJson(json);
  }

  Future<void> deleteFundingSource(FundingSource source) async {
    if (_onPhone(source.weddingPlanId)) {
      await _offline?.database.discardLocalEntity(
        table: _table,
        entityType: 'funding_source',
        entityId: source.id,
      );
      return;
    }
    await _writes.queued(
      entityType: 'funding_source',
      operation: 'delete',
      method: 'DELETE',
      endpoint: '/api/v1/funding-sources/${source.id}',
      payload: const {},
      table: _table,
      localJson: source.toJson(),
      planId: source.weddingPlanId,
      localEntityId: source.id,
      replacePendingForEntity: true,
    );
  }

  /// Returns the loan with its updated repayment schedule.
  Future<FundingSource> addRepayment(
    FundingSource loan, {
    required String amount,
    DateTime? dueDate,
  }) async {
    final payload = {'amount': amount, 'dueDate': ?_date(dueDate)};
    final localJson = {
      ...loan.toJson(),
      'repayments': [
        for (final item in loan.repayments) item.toJson(),
        {
          'id': OfflineWrites.localId('repayment'),
          'fundingSourceId': loan.id,
          'amount': amount,
          'status': 'PLANNED',
          'dueDate': _date(dueDate),
        },
      ],
    };
    final json = await _queuedOnLoan(
      loan,
      operation: 'repayment_add',
      method: 'POST',
      endpoint: '/api/v1/funding-sources/${loan.id}/repayments',
      payload: payload,
      localJson: localJson,
    );
    return FundingSource.fromJson(json);
  }

  /// [status] PAID records the repayment; PLANNED reopens it.
  Future<FundingSource> setRepaymentStatus(
    LoanRepayment repayment,
    String status,
  ) async {
    final loan = await _loanOf(repayment);
    final localJson = {
      ...loan,
      'repayments': [
        for (final item in loan['repayments'] as List? ?? const [])
          if (item is Map)
            item['id']?.toString() == repayment.id
                ? {...Map<String, dynamic>.from(item), 'status': status}
                : Map<String, dynamic>.from(item),
      ],
    };
    final json = await _queuedOnLoan(
      FundingSource.fromJson(loan),
      operation: 'repayment_status',
      method: 'PATCH',
      endpoint: '/api/v1/loan-repayments/${repayment.id}',
      payload: {'status': status},
      localJson: localJson,
      queueKey: repayment.id,
    );
    return FundingSource.fromJson(json);
  }

  Future<FundingSource> deleteRepayment(LoanRepayment repayment) async {
    final loan = await _loanOf(repayment);
    final localJson = {
      ...loan,
      'repayments': [
        for (final item in loan['repayments'] as List? ?? const [])
          if (item is Map && item['id']?.toString() != repayment.id)
            Map<String, dynamic>.from(item),
      ],
    };
    final json = await _queuedOnLoan(
      FundingSource.fromJson(loan),
      operation: 'repayment_delete',
      method: 'DELETE',
      endpoint: '/api/v1/loan-repayments/${repayment.id}',
      payload: const {},
      localJson: localJson,
      queueKey: repayment.id,
    );
    return FundingSource.fromJson(json);
  }

  /// A repayment change is a change to its loan's row: the loan is what the
  /// server returns and what the phone keeps.
  Future<Map<String, dynamic>> _queuedOnLoan(
    FundingSource loan, {
    required String operation,
    required String method,
    required String endpoint,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> localJson,
    String? queueKey,
  }) async {
    if (_onPhone(loan.weddingPlanId)) return _keep(localJson);
    if (OfflineWrites.isLocalId(loan.id) ||
        (queueKey != null && OfflineWrites.isLocalId(queueKey))) {
      // The loan (or the repayment) is still the phone's: its create carries
      // what it can when it is sent; only the phone's copy changes now.
      await _reads.putRow(_table, localJson);
      return localJson;
    }
    return _writes.queued(
      entityType: 'funding_source',
      operation: operation,
      method: method,
      endpoint: endpoint,
      payload: payload,
      table: _table,
      localJson: localJson,
      planId: loan.weddingPlanId,
      localEntityId: queueKey ?? loan.id,
    );
  }

  Future<Map<String, dynamic>> _loanOf(LoanRepayment repayment) async {
    final cached = await _reads.cachedItem(_table, repayment.fundingSourceId);
    if (cached != null) return cached;
    throw const ApiException(
      'ما لقينا القرض على الجوال. افتح المال مرة ثانية.',
    );
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _date(DateTime? value) => value == null
      ? null
      : DateTime.utc(value.year, value.month, value.day).toIso8601String();
}
