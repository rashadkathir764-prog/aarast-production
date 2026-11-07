import 'package:aarast_mobile/core/offline/local_database_mobile.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-30 on the phone's own queue: the encrypted SQLite database
// (sqflite_sqlcipher) that Android uses, where the unit tests run the JSON
// one. Run on a device or emulator:
//   flutter test integration_test/offline_queue_sqlite_android_test.dart -d <id>
// It wipes the app's local data on that device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a sent create is never rewritten nor dropped', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final database = SqliteLocalDatabase(preferences: preferences);
    await database.initialize();
    await database.wipeAll();

    Future<SyncQueueItem> only(String id) async => [
      ...await database.pendingSyncItems(),
      ...await database.blockedSyncItems(),
    ].singleWhere((item) => item.id == id);
    Future<SyncQueueItem> addGuest(String localId) => database.enqueueSync(
      entityType: 'guest',
      operation: 'create',
      endpoint: '/api/v1/wedding-plans/plan-1/guests',
      method: 'POST',
      payload: {'name': 'أحمد'},
      planId: 'plan-1',
      localEntityId: localId,
    );
    Future<bool> rewrite(String localId) => database.rewriteUnsentSyncItem(
      entityType: 'guest',
      operation: 'create',
      localEntityId: localId,
      planId: 'plan-1',
      endpoint: '/api/v1/wedding-plans/plan-1/guests',
      payload: {'name': 'أحمد علي'},
    );
    Future<bool> discard(String localId) => database.discardUnsentLocalEntity(
      table: OfflineTables.cachedGuests,
      entityType: 'guest',
      entityId: localId,
    );

    // Never sent: rewritten in place (same id), and it can be dropped.
    final first = await addGuest('queued-guest-a');
    expect(await rewrite('queued-guest-a'), isTrue);
    expect((await only(first.id)).payload['name'], 'أحمد علي');

    // On the wire: sent; no rewrite, no drop.
    expect(await database.markSyncItemSending(first.id), isTrue);
    expect((await only(first.id)).status, SyncQueueItem.sent);
    expect(await database.markSyncItemSending(first.id), isFalse);
    expect(await rewrite('queued-guest-a'), isFalse);
    expect(await discard('queued-guest-a'), isFalse);
    expect((await only(first.id)).payload['name'], 'أحمد علي');

    // Its answer lost: failed, still not rewritten; sent again from failed.
    await database.markSyncItemFailed(first.id, 'answer lost');
    expect((await only(first.id)).mayBeOnServer, isTrue);
    expect(await rewrite('queued-guest-a'), isFalse);
    expect(await database.markSyncItemSending(first.id), isTrue);

    // Refused after that failure, then retried by the person: still marked.
    await database.markSyncItemBlocked(first.id, 'refused');
    expect(await database.requeueBlockedSyncItems(), 1);
    final requeued = await only(first.id);
    expect(requeued.status, SyncQueueItem.failed);
    expect(requeued.retryCount, 0);
    expect(await rewrite('queued-guest-a'), isFalse);

    // Refused on its only attempt: nothing on the server; rewrite and drop.
    final second = await addGuest('queued-guest-b');
    expect(await database.markSyncItemSending(second.id), isTrue);
    await database.markSyncItemBlocked(second.id, 'refused');
    expect(await rewrite('queued-guest-b'), isTrue);
    expect((await only(second.id)).status, SyncQueueItem.queued);
    expect(await discard('queued-guest-b'), isTrue);
    expect(
      (await database.pendingSyncItems()).map((item) => item.id),
      isNot(contains(second.id)),
    );

    await database.wipeAll();
  });
}
