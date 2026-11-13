import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
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

// RA-MO-195 (batch 5): an event added with no network stayed among the
// copy's suggestions, so it was offered and added again (the server
// refuses the second, which stuck the queue), and the wedding stood twice.
void main() {
  test(
    'an event added offline leaves the suggestions, and stands once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = JsonLocalDatabase(await SharedPreferences.getInstance());
      await database.initialize();
      final reachability = ServerReachability();
      final client = ApiClient(
        tokenProvider: () async => 'token',
        reachability: reachability,
      );
      client.dio.httpClientAdapter = _Down();
      final offline = OfflineSyncService(
        database: database,
        apiClient: client,
        reachability: reachability,
      );
      await offline.ensureCacheOwner('user-1');
      await database.setMeta(
        'plan-events:plan-1',
        jsonEncode({
          'weddingPlanId': 'plan-1',
          'canEdit': true,
          // The wedding before it has a row of its own.
          'items': [
            {'id': null, 'type': 'WEDDING', 'weddingPlanId': 'plan-1'},
          ],
          'suggestions': ['MAQEEL', 'SAMRA'],
        }),
      );
      final api = PlanEventsApi(client, offline: offline);

      await api.create(
        'plan-1',
        PlanEventType.maqeel,
        PlanEventDraft(date: DateTime(2027, 1, 20)),
      );
      await api.create(
        'plan-1',
        PlanEventType.wedding,
        const PlanEventDraft(placeLabel: 'قاعة سبأ'),
      );

      final view = await api.cachedView('plan-1');
      expect(view!.suggestions, [PlanEventType.samra]);
      expect(
        view.items.where((item) => item.type == PlanEventType.maqeel),
        hasLength(1),
      );
      expect(
        view.items.where((item) => item.type == PlanEventType.wedding),
        hasLength(1),
      );
      expect(
        view.items
            .singleWhere((item) => item.type == PlanEventType.wedding)
            .placeLabel,
        'قاعة سبأ',
      );
    },
  );
}
