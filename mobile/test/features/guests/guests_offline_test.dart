import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// w29: what «بدون نت» means on the guests tab.
void main() {
  testWidgets('a plan kept on the phone keeps adding guests offline', (
    tester,
  ) async {
    final harness = await _harness(planId: 'guest-plan-offline');
    await harness.api.createGuest(
      weddingPlanId: 'guest-plan-offline',
      name: 'محمد علي',
      side: 'GROOM',
      status: 'INVITED',
      seatsCount: 1,
    );
    await harness.offline.noteNetworkFailure();

    await _pump(tester, harness, planId: 'guest-plan-offline');

    // Nothing in this plan waits for a connection, so nothing says it does.
    expect(find.byKey(const ValueKey('guests-offline')), findsNothing);
    expect(find.byKey(const ValueKey('guests-add')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an account plan offline shows its copy and waits to add', (
    tester,
  ) async {
    final harness = await _harness(
      planId: 'plan-account-1',
      cached: [
        Guest(
          id: 'guest-1',
          weddingPlanId: 'plan-account-1',
          name: 'عبدالله الحمدي',
          side: 'GROOM',
          status: 'CONFIRMED',
          attendanceStatus: 'CONFIRMED',
          invitationStatus: 'SENT',
          seatsCount: 1,
          companionsCount: 0,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      ],
    );
    await harness.offline.noteNetworkFailure();

    await _pump(tester, harness, planId: 'plan-account-1');

    expect(find.byKey(const ValueKey('guests-offline')), findsOneWidget);
    expect(
      find.textContaining('الإضافة والدعوات لما يرجع النت'),
      findsOneWidget,
    );
    // Adding would only fail now, so its button waits too.
    expect(find.byKey(const ValueKey('guests-add')), findsNothing);
    expect(find.byKey(const ValueKey('guests-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each «+» request from the home shell opens the add sheet once', (
    tester,
  ) async {
    // D33: the owner shell keeps the guests tab alive and raises a request.
    final harness = await _harness(planId: 'guest-plan-request');
    await _pump(tester, harness, planId: 'guest-plan-request');
    expect(find.text('ضيف جديد'), findsNothing);

    Future<void> request(int value) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: harness.authStorage),
            ChangeNotifierProvider<OfflineSyncService>.value(
              value: harness.offline,
            ),
            ChangeNotifierProvider<GuestsProvider>(
              create: (_) => GuestsProvider(harness.api),
            ),
          ],
          child: MaterialApp(
            home: GuestListScreen(
              weddingPlanId: 'guest-plan-request',
              openAddRequest: value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await request(1);
    expect(find.text('ضيف جديد'), findsOneWidget);
    Navigator.of(tester.element(find.text('ضيف جديد'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('ضيف جديد'), findsNothing);

    // The same request again opens nothing; a new one opens it again.
    await request(1);
    expect(find.text('ضيف جديد'), findsNothing);
    await request(2);
    expect(find.text('ضيف جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CachedGuestsApi extends GuestsApi {
  _CachedGuestsApi(super.apiClient, this.cached, {super.offline});

  final List<Guest> cached;

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async {
    if (weddingPlanId.startsWith('guest-plan-')) {
      return super.getGuests(weddingPlanId);
    }
    return cached;
  }

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];
}

class _Harness {
  const _Harness(this.authStorage, this.offline, this.api);

  final AuthStorage authStorage;
  final OfflineSyncService offline;
  final GuestsApi api;
}

Future<_Harness> _harness({
  required String planId,
  List<Guest> cached = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final offline = OfflineSyncService(database: database, apiClient: apiClient);
  await offline.refreshStatus();
  return _Harness(
    authStorage,
    offline,
    _CachedGuestsApi(apiClient, cached, offline: offline),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Harness harness, {
  required String planId,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(384, 1000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: harness.authStorage),
        ChangeNotifierProvider<OfflineSyncService>.value(
          value: harness.offline,
        ),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(harness.api),
        ),
      ],
      child: MaterialApp(home: GuestListScreen(weddingPlanId: planId)),
    ),
  );
  await tester.pumpAndSettle();
}
