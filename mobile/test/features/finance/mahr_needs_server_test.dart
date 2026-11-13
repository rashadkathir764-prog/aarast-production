import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Down implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const SocketException('Connection refused'),
    );
  }

  @override
  void close({bool force = false}) {}
}

// RA-MO-173 (batch 4): recording the mahr was a bare request; with no
// network it failed with no word of why it cannot wait on the phone (D85).
void main() {
  test('the mahr without the server says why it cannot wait', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final reachability = ServerReachability();
    final apiClient = ApiClient(
      tokenProvider: () async => 'token',
      reachability: reachability,
    );
    apiClient.dio.httpClientAdapter = _Down();
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
      reachability: reachability,
    );
    await offline.refreshStatus();
    final api = FinanceApi(apiClient, offline: offline);

    Object? failure;
    try {
      await api.recordMahr('plan-1', total: '1000000', settled: '0');
    } on Object catch (error) {
      failure = error;
    }

    final exception = failure! as ApiException;
    expect(exception.isNetworkFailure, isTrue);
    expect(exception.message, contains('المهر يحسبه الخادم'));
  });
}
