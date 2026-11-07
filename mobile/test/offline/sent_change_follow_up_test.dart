import 'dart:convert';
import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-30: a queued change the server may already have (sent, and its
// answer lost; or still on the wire) is never rewritten or dropped on the
// phone. An edit goes after it as its own change, a deletion as a delete.
// RA-MO-31: two waiting edits of one row merge; the second never drops the
// first one's fields.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a guest added on the phone', () {
    test(
      'edited after its add reached the server unanswered: one guest, edited',
      () async {
        final h = await _Harness.create();
        final guest = await h.addGuest('أحمد');
        h.server.online = true;
        h.server.loseNextAnswer = true;
        await h.offline.syncPendingChanges();
        expect(
          h.server.guests,
          hasLength(1),
          reason: 'the server kept the add',
        );

        h.server.online = false;
        await h.guests.updateGuest(id: guest.id, name: 'أحمد علي');
        h.server.online = true;
        await h.syncUntilQuiet();

        expect(h.server.guests.values.map((g) => g['name']), ['أحمد علي']);
        expect(h.offline.blockedCount, 0);
        expect(await h.database.pendingSyncItems(), isEmpty);
      },
    );

    test('edited while its add is on the wire: one guest, edited', () async {
      final h = await _Harness.create();
      final guest = await h.addGuest('سالم');
      h.server.online = true;
      h.server.whileNextAddIsOnTheWire = () async {
        await h.guests.updateGuest(id: guest.id, name: 'سالم محمد');
      };
      await h.syncUntilQuiet();

      expect(h.server.guests.values.map((g) => g['name']), ['سالم محمد']);
      expect(h.offline.blockedCount, 0);
      expect(await h.database.pendingSyncItems(), isEmpty);
    });

    test(
      'deleted after its add reached the server unanswered: gone there too',
      () async {
        final h = await _Harness.create();
        final guest = await h.addGuest('خالد');
        h.server.online = true;
        h.server.loseNextAnswer = true;
        await h.offline.syncPendingChanges();

        h.server.online = false;
        await h.guests.deleteGuest(guest.id);
        h.server.online = true;
        await h.syncUntilQuiet();

        expect(h.server.guests, isEmpty);
        expect(await h.database.pendingSyncItems(), isEmpty);
        final rows = await h.database.readCachedList(
          table: OfflineTables.cachedGuests,
          parentColumn: 'planId',
          parentId: 'plan-1',
        );
        expect(rows.where((row) => row['deletedLocally'] != true), isEmpty);
      },
    );

    test('its edit waits while its add fails with a server error', () async {
      final h = await _Harness.create();
      final guest = await h.addGuest('مازن');
      h.server.online = true;
      h.server.loseNextAnswer = true;
      await h.offline.syncPendingChanges();
      h.server.online = false;
      await h.guests.updateGuest(id: guest.id, name: 'مازن صالح');

      h.server.online = true;
      h.server.failNextWith500 = true;
      await h.offline.syncPendingChanges();
      expect(
        h.offline.blockedCount,
        0,
        reason: 'the edit never went with a local id',
      );
      expect(
        h.server.requests.where((r) => r.path.contains('queued-')),
        isEmpty,
      );

      await h.syncUntilQuiet();
      expect(h.server.guests.values.map((g) => g['name']), ['مازن صالح']);
    });

    test(
      'edited before its add was ever sent: one add, already edited',
      () async {
        final h = await _Harness.create();
        final guest = await h.addGuest('ناصر');
        await h.guests.updateGuest(id: guest.id, name: 'ناصر سعيد');
        h.server.online = true;
        await h.syncUntilQuiet();

        expect(h.server.requests.map((r) => r.method).toList(), ['POST']);
        expect(h.server.guests.values.single['name'], 'ناصر سعيد');
      },
    );
  });

  test(
    'two waiting edits of a guest keep both: the name and the answer',
    () async {
      final h = await _Harness.create();
      h.server.online = true;
      final guest = await h.guests.createGuest(
        weddingPlanId: 'plan-1',
        name: 'فهد',
        side: 'GROOM',
        status: 'INVITED',
        seatsCount: 1,
      );
      h.server.online = false;
      await h.guests.updateGuest(id: guest.id, name: 'فهد عبدالله');
      await h.guests.updateGuest(
        id: guest.id,
        status: 'CONFIRMED',
        attendanceStatus: 'ATTENDING',
      );
      h.server.online = true;
      await h.syncUntilQuiet();

      final row = h.server.guests[guest.id]!;
      expect(row['name'], 'فهد عبدالله');
      expect(row['status'], 'CONFIRMED');
    },
  );

  group('a task', () {
    test(
      'added on the phone and edited after its add reached the server unanswered',
      () async {
        final h = await _Harness.create();
        final task = await h.tasks.createTask(
          weddingPlanId: 'plan-1',
          title: 'القاعة',
        );
        h.server.online = true;
        h.server.loseNextAnswer = true;
        await h.offline.syncPendingChanges();

        h.server.online = false;
        await h.tasks.updateTask(task.id, {'title': 'حجز القاعة'});
        h.server.online = true;
        await h.syncUntilQuiet();

        expect(h.server.tasks.values.map((t) => t['title']), ['حجز القاعة']);
        expect(
          h.offline.blockedCount,
          0,
          reason: 'no 409 for one key, two bodies',
        );
        expect(await h.database.pendingSyncItems(), isEmpty);
      },
    );

    test(
      'edited twice, the first edit reached the server unanswered',
      () async {
        final h = await _Harness.create();
        h.server.online = true;
        final task = await h.tasks.createTask(
          weddingPlanId: 'plan-1',
          title: 'الكوشة',
        );
        h.server.online = false;
        await h.tasks.updateTask(task.id, {'title': 'الكوشة والورد'});
        h.server.online = true;
        h.server.loseNextAnswer = true;
        await h.offline.syncPendingChanges();

        h.server.online = false;
        await h.tasks.updateTask(task.id, {'priority': 'HIGH'});
        h.server.online = true;
        await h.syncUntilQuiet();

        final row = h.server.tasks[task.id]!;
        expect(row['title'], 'الكوشة والورد');
        expect(row['priority'], 'HIGH');
        expect(h.offline.blockedCount, 0);
      },
    );
  });
}

class _Harness {
  _Harness(this.database, this.offline, this.guests, this.tasks, this.server);

  final JsonLocalDatabase database;
  final OfflineSyncService offline;
  final GuestsApi guests;
  final TaskTimelineApi tasks;
  final _Server server;

  static Future<_Harness> create() async {
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final client = ApiClient(tokenProvider: () async => 'token');
    final server = _Server();
    client.dio.httpClientAdapter = server;
    final offline = OfflineSyncService(database: database, apiClient: client);
    await offline.ensureCacheOwner('user-1');
    return _Harness(
      database,
      offline,
      GuestsApi(client, offline: offline),
      TaskTimelineApi(client, offline: offline),
      server,
    );
  }

  Future<dynamic> addGuest(String name) => guests.createGuest(
    weddingPlanId: 'plan-1',
    name: name,
    side: 'GROOM',
    status: 'INVITED',
    seatsCount: 1,
  );

  Future<void> syncUntilQuiet() async {
    for (var pass = 0; pass < 4; pass++) {
      await offline.syncPendingChanges();
      if ((await database.pendingSyncItems()).isEmpty) return;
    }
  }
}

/// The server's rules for a queued change: one effect per request key, a
/// replay for the same key and body, a 409 for the same key and another body.
class _Server implements HttpClientAdapter {
  bool online = false;
  bool loseNextAnswer = false;
  bool failNextWith500 = false;
  Future<void> Function()? whileNextAddIsOnTheWire;
  final Map<String, Map<String, dynamic>> guests = {};
  final Map<String, Map<String, dynamic>> tasks = {};
  final List<RequestOptions> requests = [];
  final Map<
    String,
    ({String fingerprint, int status, Map<String, dynamic> body})
  >
  _keys = {};
  var _next = 0;

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
    requests.add(options);
    if (failNextWith500) {
      failNextWith500 = false;
      return _json(500, {
        'statusCode': 500,
        'message': 'Internal server error',
      });
    }
    final body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};
    final key = options.headers['X-Client-Request-Id']?.toString();
    final fingerprint = '${options.method} ${options.path} ${jsonEncode(body)}';
    if (key != null && _keys[key] != null) {
      final seen = _keys[key]!;
      if (seen.fingerprint != fingerprint) {
        return _json(409, {
          'statusCode': 409,
          'message': 'key reused for another request',
        });
      }
      return _json(seen.status, seen.body);
    }
    final (status, answer) = _handle(options.method, options.path, body);
    if (key != null && status < 300) {
      _keys[key] = (fingerprint: fingerprint, status: status, body: answer);
    }
    if (options.method == 'POST' && whileNextAddIsOnTheWire != null) {
      final edit = whileNextAddIsOnTheWire!;
      whileNextAddIsOnTheWire = null;
      await edit();
    }
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'answer lost',
      );
    }
    return _json(status, answer);
  }

  (int, Map<String, dynamic>) _handle(
    String method,
    String path,
    Map<String, dynamic> body,
  ) {
    for (final (collection, base, prefix) in [
      (guests, '/api/v1/wedding-plans/plan-1/guests', '/api/v1/guests/'),
      (tasks, '/api/v1/wedding-plans/plan-1/tasks', '/api/v1/tasks/'),
    ]) {
      if (method == 'POST' && path == base) {
        final id = 'remote-${prefix.split('/')[3]}-${++_next}';
        final row = {
          'id': id,
          'weddingPlanId': 'plan-1',
          ...body,
          'createdAt': '2026-11-07T00:00:00.000Z',
          'updatedAt': '2026-11-07T00:00:00.000Z',
        };
        collection[id] = row;
        return (201, row);
      }
      if (path.startsWith(prefix)) {
        final id = path.substring(prefix.length);
        final row = collection[id];
        if (row == null) {
          return (404, {'statusCode': 404, 'message': 'not found'});
        }
        if (method == 'DELETE') {
          collection.remove(id);
          return (200, {'id': id});
        }
        row.addAll(body);
        return (200, row);
      }
    }
    return (404, {'statusCode': 404, 'message': 'no route'});
  }

  ResponseBody _json(int status, Map<String, dynamic> body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}
