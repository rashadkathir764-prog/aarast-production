import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D99 (RA-BE-62): a plan holds up to 5000 guests. The phone has the plan's
// whole list, so it stops an add past the limit itself, in the server's own
// words; and a queued add the server refuses says the server's reason.

const _full = 'الخطة تشيل 5000 اسم بالكثير، وفيها الحين 5000.';

List<Guest> _guests(String planId, int count) => [
  for (var i = 0; i < count; i++)
    Guest(
      id: 'guest-$i',
      weddingPlanId: planId,
      name: 'ضيف $i',
      side: 'OTHER',
      status: 'INVITED',
      seatsCount: 1,
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),
];

/// The plan's list as the server (or the phone, for a local plan) has it;
/// every add that reaches here is counted.
class _Api extends GuestsApi {
  _Api(this.guests) : super(ApiClient(tokenProvider: () async => null));

  final List<Guest> guests;
  var adds = 0;

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => guests;

  @override
  Future<List<Guest>> cachedGuests(String weddingPlanId) async => const [];

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];

  @override
  Future<GuestSummary> getSummary({
    required String weddingPlanId,
    List<Guest>? localGuests,
    List<GuestGroup>? localGroups,
  }) async => GuestSummary.fromGuests(
    weddingPlanId: weddingPlanId,
    guests: localGuests ?? guests,
  );

  @override
  Future<Guest> createGuest({
    required String weddingPlanId,
    required String name,
    String? phone,
    String? groupId,
    required String side,
    required String status,
    String? attendanceStatus,
    required int seatsCount,
    int? companionsCount,
    String? notes,
    List<String>? eventIds,
  }) async {
    adds++;
    return _guests(weddingPlanId, 1).single;
  }

  @override
  Future<
    ({
      List<Guest> created,
      List<({String name, String? phone})> refused,
      String? reason,
    })
  >
  createGuestsBulk({
    required String weddingPlanId,
    required List<({String name, String? phone})> people,
    String? groupId,
  }) async {
    adds += people.length;
    return (
      created: _guests(weddingPlanId, people.length),
      refused: const <({String name, String? phone})>[],
      reason: null,
    );
  }
}

Future<bool> _addOne(GuestsProvider provider, String planId) {
  return provider.createGuest(
    weddingPlanId: planId,
    name: 'ضيف زائد',
    side: 'OTHER',
    status: 'INVITED',
    seatsCount: 1,
  );
}

class _Server implements HttpClientAdapter {
  _Server(this.routes);

  final Map<String, (int, Object?)> routes;
  bool down = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (down) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('Connection refused'),
      );
    }
    final (status, body) =
        routes['${options.method} ${options.uri.path}'] ??
        (404, {'message': 'not found'});
    return ResponseBody.fromString(
      jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('the form stops a guest past the limit', () async {
    final api = _Api(_guests('plan-1', 5000));
    final provider = GuestsProvider(api);
    await provider.loadGuests('plan-1');

    expect(await _addOne(provider, 'plan-1'), isFalse);
    expect(provider.errorMessage, _full);
    expect(api.adds, 0);
  });

  test('a contacts list past the limit adds none', () async {
    final api = _Api(_guests('plan-1', 4999));
    final provider = GuestsProvider(api);
    await provider.loadGuests('plan-1');

    final people = [(name: 'أ', phone: null), (name: 'ب', phone: null)];
    expect(
      await provider.addGuests(weddingPlanId: 'plan-1', people: people),
      0,
    );
    expect(
      provider.errorMessage,
      'الخطة تشيل 5000 اسم بالكثير، وفيها الحين 4999.',
    );
    expect(api.adds, 0);

    // The last place still takes one.
    expect(
      await provider.addGuests(weddingPlanId: 'plan-1', people: [people.first]),
      1,
    );
    expect(api.adds, 1);
  });

  test('a plan kept on the phone stops at the same limit', () async {
    final api = _Api(_guests('guest-plan-local', 5000));
    final provider = GuestsProvider(api);
    await provider.loadGuests('guest-plan-local');

    expect(await _addOne(provider, 'guest-plan-local'), isFalse);
    expect(provider.errorMessage, _full);
    expect(api.adds, 0);
  });

  test('a queued add the server refuses says the server\'s reason', () async {
    SharedPreferences.setMockInitialValues({});
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    final reachability = ServerReachability();
    final client = ApiClient(
      tokenProvider: () async => 'token',
      reachability: reachability,
    );
    final server = _Server({
      // Another phone filled the plan while this one was offline.
      'POST /api/v1/wedding-plans/plan-a/guests': (
        422,
        {'statusCode': 422, 'code': 'PLAN_GUESTS_LIMIT', 'message': _full},
      ),
    })..down = true;
    client.dio.httpClientAdapter = server;
    final offline = OfflineSyncService(
      database: database,
      apiClient: client,
      reachability: reachability,
    );
    await offline.refreshStatus();
    await offline.ensureCacheOwner('u1');
    await GuestsApi(client, offline: offline).createGuest(
      weddingPlanId: 'plan-a',
      name: 'خالد',
      side: 'OTHER',
      status: 'INVITED',
      seatsCount: 1,
    );

    server.down = false;
    await offline.syncPendingChanges();

    final change = (await offline.loadPendingChanges()).single;
    expect(change.blocked, isTrue);
    expect(change.reason, contains(_full));
  });
}
