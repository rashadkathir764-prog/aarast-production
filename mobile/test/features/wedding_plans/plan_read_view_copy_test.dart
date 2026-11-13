import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/plan_read_view_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers the plan's view while [up], else the connection fails.
class _Server implements HttpClientAdapter {
  bool up = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!up) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection refused'),
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'weddingPlanId': 'plan-1',
        'tasks': {'items': const [], 'total': 3, 'done': 1},
        'guests': {'items': const [], 'total': 120},
        'bookings': const [],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// RA-MO-258 (batch 7): a participant's plan pages had no copy on the phone,
// so with no network every open was an error. D112 (Q-17): the participant
// reads the phone's copy, marked old, until the server withdraws the right.
void main() {
  test('the plan view is kept, served offline as old, and goes with the '
      'plan', () async {
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
    final view = PlanReadViewProvider(
      weddingPlansApi: WeddingPlansApi(apiClient, offline: offline),
    );

    await view.load('plan-1');
    expect(view.viewOf('plan-1')?.guestsTotal, 120);
    expect(view.isStale, isFalse);

    server.up = false;
    await view.load('plan-1');
    expect(view.viewOf('plan-1')?.guestsTotal, 120);
    expect(view.isStale, isTrue);
    expect(view.errorMessage, isNull);

    // Taken off the plan: its copy goes with it (a page opened afresh).
    await database.deletePlanGraph('plan-1');
    final afresh = PlanReadViewProvider(
      weddingPlansApi: WeddingPlansApi(apiClient, offline: offline),
    );
    await afresh.load('plan-1');
    expect(afresh.viewOf('plan-1'), isNull);
    expect(afresh.errorMessage, isNotNull);
  });
}
