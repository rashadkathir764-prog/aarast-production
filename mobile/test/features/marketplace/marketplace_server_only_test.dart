import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D90: what reaches the provider now (a decision on his offer, a booking,
// a review) cannot wait on the phone; without the server the failure
// names the measured cause and why.
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

void main() {
  test(
    'accepting an offer without the server says why it cannot wait',
    () async {
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
      final api = MarketplaceApi(apiClient, offline: offline);

      Object? failure;
      try {
        await api.acceptQuoteOffer(
          quoteRequestId: 'q1',
          quoteOfferId: 'o1',
          versionNo: 1,
        );
      } on Object catch (error) {
        failure = error;
      }
      final exception = failure! as ApiException;
      expect(exception.isNetworkFailure, isTrue);
      expect(exception.message, contains('يوصل المزود'));
    },
  );
}
