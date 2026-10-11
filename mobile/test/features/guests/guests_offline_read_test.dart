import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 3.4: a plan's guest list, groups and summary still open without a
// connection from the last copy saved on the device.
void main() {
  late _GuestServer server;
  late GuestsApi api;
  late JsonLocalDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final apiClient = ApiClient(tokenProvider: () async => 'token');
    server = _GuestServer();
    apiClient.dio.httpClientAdapter = server;
    database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );
    api = GuestsApi(apiClient, offline: offline);
  });

  test(
    'guests, groups and summary open offline after one online load',
    () async {
      await api.getGuests('plan-1');
      await api.getGroups('plan-1');

      server.online = false;
      final guests = await api.getGuests('plan-1');
      final groups = await api.getGroups('plan-1');
      final summary = await api.getSummary(weddingPlanId: 'plan-1');

      expect(guests.map((guest) => guest.name), ['خالد']);
      expect(groups.map((group) => group.name), ['الأهل']);
      expect(summary.totalGuests, 1);
    },
  );

  test(
    'offline with nothing saved reports the failure, not an empty list',
    () async {
      server.online = false;

      await expectLater(
        api.getGuests('plan-1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isNetworkFailure,
            'network',
            isTrue,
          ),
        ),
      );
    },
  );

  test(
    'removing a plan from the device removes its saved guests and groups',
    () async {
      await api.getGuests('plan-1');
      await api.getGroups('plan-1');

      await database.deletePlanGraph('plan-1');
      server.online = false;

      await expectLater(api.getGuests('plan-1'), throwsA(isA<ApiException>()));
      expect(await database.getMeta('guest-groups:plan-1'), isNull);
    },
  );

  test('a deleted guest leaves the saved copy', () async {
    await api.getGuests('plan-1');
    await api.deleteGuest('guest-1');

    server.online = false;

    await expectLater(api.getGuests('plan-1'), throwsA(isA<ApiException>()));
  });
}

class _GuestServer implements HttpClientAdapter {
  bool online = true;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!online) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final path = options.uri.path;
    final Object body = switch (path) {
      '/api/v1/wedding-plans/plan-1/guests' => [
        {
          'id': 'guest-1',
          'weddingPlanId': 'plan-1',
          'groupId': 'family',
          'name': 'خالد',
          'side': 'GROOM',
          'status': 'INVITED',
          'seatsCount': 1,
          'createdAt': '2026-10-01T00:00:00.000Z',
          'updatedAt': '2026-10-01T00:00:00.000Z',
        },
      ],
      '/api/v1/wedding-plans/plan-1/guest-groups' => [
        {'id': 'family', 'weddingPlanId': 'plan-1', 'name': 'الأهل'},
      ],
      '/api/v1/guests/guest-1' => {'id': 'guest-1', 'deleted': true},
      _ => throw StateError('unexpected $path'),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
