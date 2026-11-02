import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/funding_source.dart';

/// Funding sources and loan repayments. Changes need a connection; the last
/// list read from the server is kept on this (encrypted) device so the
/// owner's money picture still opens offline.
class FundingApi {
  const FundingApi(this._apiClient, {OfflineSyncService? offline})
    : _offline = offline;

  final ApiClient _apiClient;
  final OfflineSyncService? _offline;

  static String cacheKey(String weddingPlanId) => 'funding:$weddingPlanId';

  Future<List<FundingSource>> getFundingSources(String weddingPlanId) async {
    try {
      final items = (await _apiClient.getJsonList(
        '/api/v1/wedding-plans/$weddingPlanId/funding-sources',
      )).whereType<Map>().map((item) => Map<String, dynamic>.from(item));
      final list = items.toList();
      await _offline?.database.setMeta(
        cacheKey(weddingPlanId),
        jsonEncode(list),
      );
      return list.map(FundingSource.fromJson).toList();
    } on Object catch (error) {
      final offline = _offline;
      if (!CachePolicy.shouldUseCache(error) || offline == null) rethrow;
      await offline.noteNetworkFailure((error as ApiException).message);
      final raw = await offline.database.getMeta(cacheKey(weddingPlanId));
      final decoded = raw == null ? null : jsonDecode(raw);
      // No saved copy: report the failure instead of an empty list.
      if (decoded is! List) rethrow;
      return [
        for (final item in decoded)
          if (item is Map)
            FundingSource.fromJson(Map<String, dynamic>.from(item)),
      ];
    }
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
  }) async {
    final json = await _apiClient
        .postJson('/api/v1/wedding-plans/$weddingPlanId/funding-sources', {
          'kind': kind,
          'sourceName': sourceName.trim(),
          'amount': amount,
          'status': status,
          'sourcePhone': ?_trimmedOrNull(sourcePhone),
          'note': ?_trimmedOrNull(note),
          'expectedAt': ?_date(expectedAt),
        });
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
  }) async {
    final json = await _apiClient.patchJson(
      '/api/v1/funding-sources/${source.id}',
      {
        'kind': kind,
        'sourceName': sourceName.trim(),
        'amount': amount,
        'status': status,
        'sourcePhone': _trimmedOrNull(sourcePhone),
        'note': _trimmedOrNull(note),
        // D59: the promised day is the whole field: null clears it.
        'expectedAt': _date(expectedAt),
      },
    );
    return FundingSource.fromJson(json);
  }

  Future<void> deleteFundingSource(FundingSource source) async {
    await _apiClient.deleteJson('/api/v1/funding-sources/${source.id}');
  }

  /// Returns the loan with its updated repayment schedule.
  Future<FundingSource> addRepayment(
    FundingSource loan, {
    required String amount,
    DateTime? dueDate,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/funding-sources/${loan.id}/repayments',
      {'amount': amount, 'dueDate': ?_date(dueDate)},
    );
    return FundingSource.fromJson(json);
  }

  /// [status] PAID records the repayment; PLANNED reopens it.
  Future<FundingSource> setRepaymentStatus(
    LoanRepayment repayment,
    String status,
  ) async {
    final json = await _apiClient.patchJson(
      '/api/v1/loan-repayments/${repayment.id}',
      {'status': status},
    );
    return FundingSource.fromJson(json);
  }

  Future<FundingSource> deleteRepayment(LoanRepayment repayment) async {
    final json = await _apiClient.deleteJson(
      '/api/v1/loan-repayments/${repayment.id}',
    );
    return FundingSource.fromJson(json);
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _date(DateTime? value) => value == null
      ? null
      : DateTime.utc(value.year, value.month, value.day).toIso8601String();
}
