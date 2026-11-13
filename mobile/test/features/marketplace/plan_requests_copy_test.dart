import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers the plan's requests with [requests].
class _Server implements HttpClientAdapter {
  List<Map<String, Object?>> requests = const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(requests),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _request(String id, String planId) => {
  'id': id,
  'providerId': 'provider-$id',
  'weddingPlanId': planId,
  'status': 'RESPONDED',
  'offers': const [],
};

// RA-MO-261 (batch 7): the phone's copy of a plan's requests was only ever
// added to. A request the reader no longer sees (money rights withdrawn,
// the request removed) stayed with its amounts and showed with no network.
void main() {
  test('the plan\'s copy is the server\'s last list', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final reachability = ServerReachability();
    final apiClient = ApiClient(
      tokenProvider: () async => 'token',
      reachability: reachability,
    );
    final server = _Server();
    apiClient.dio.httpClientAdapter = server;
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
      reachability: reachability,
    );
    await offline.refreshStatus();
    final api = MarketplaceApi(apiClient, offline: offline);

    // Another plan's request is not this plan's to drop.
    await database.saveCachedItem(
      table: OfflineTables.cachedBookings,
      json: _request('other-1', 'plan-2'),
    );
    server.requests = [_request('q1', 'plan-1'), _request('q2', 'plan-1')];
    await api.getPlanQuoteRequests('plan-1');
    expect(
      (await api.cachedPlanQuoteRequests('plan-1')).map((item) => item.id),
      unorderedEquals(['q1', 'q2']),
    );

    server.requests = [_request('q1', 'plan-1')];
    await api.getPlanQuoteRequests('plan-1');

    expect(
      (await api.cachedPlanQuoteRequests('plan-1')).map((item) => item.id),
      ['q1'],
    );
    expect(
      (await api.cachedPlanQuoteRequests('plan-2')).map((item) => item.id),
      ['other-1'],
    );
  });
}
