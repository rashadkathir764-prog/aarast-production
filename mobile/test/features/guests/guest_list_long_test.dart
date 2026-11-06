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

/// RA-MO-16: a long guest list is one list. Every name is reached by
/// scrolling; none waits behind a «باقي» button. The groom walk added a
/// guest whose name sorts late and could not find them under the first
/// fifty.
void main() {
  testWidgets('every guest of a long list is reached by scrolling', (
    tester,
  ) async {
    final guests = [
      for (var index = 0; index < 119; index++)
        _guest('guest-$index', 'بدر ضيف ${index.toString().padLeft(3, '0')}'),
      // «ي» sorts after every other name here: the last row of the list.
      _guest('guest-last', 'ياسين آخر واحد'),
    ];
    await _pump(tester, guests);

    await tester.tap(find.byKey(const ValueKey('guest-group-all')));
    await tester.pumpAndSettle();
    expect(find.text('كل الضيوف · 120 ضيف'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('ياسين آخر واحد'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ياسين آخر واحد'), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-more-rows')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-16: a family opened from low on the overview starts at its top,
  // with its title, its way back and its answer chips, not in the middle of
  // its rows where the overview had been scrolled.
  testWidgets('a family opens at its top, wherever the overview was', (
    tester,
  ) async {
    // A short phone: the family rows sit below the summary, so the overview
    // is scrolled before «كل الضيوف» can be tapped.
    await _pump(tester, [
      for (var index = 0; index < 60; index++)
        _guest('guest-$index', 'سالم رقم ${index.toString().padLeft(3, '0')}'),
    ], height: 480);
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('guest-group-all')),
      120,
      scrollable: page,
    );
    await tester.pumpAndSettle();
    final scrolled = tester.state<ScrollableState>(page).position.pixels;
    expect(scrolled, greaterThan(200), reason: 'the overview was scrolled');
    await tester.tap(find.byKey(const ValueKey('guest-group-all')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guest-group-back')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('كل الضيوف · 60 ضيف'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guest-filter-all')).hitTestable(),
      findsOneWidget,
    );
  });

  // RA-TS-03: the family the reader opened and the search are states of one
  // screen; Android back undoes each, then leaves.
  testWidgets('android back closes the family, then the search, then leaves', (
    tester,
  ) async {
    await _pump(tester, [
      _guest('guest-1', 'أحمد علي'),
      _guest('guest-2', 'بدر سالم'),
    ]);

    await tester.tap(find.byKey(const ValueKey('guest-group-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guest-group-back')), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guest-group-back')), findsNothing);
    expect(find.byKey(const ValueKey('guest-group-all')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('guests-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'أحمد');
    await tester.pumpAndSettle();
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('أحمد علي'), findsNothing, reason: 'the search is gone');

    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('a search lists every match the same way', (tester) async {
    final guests = [
      for (var index = 0; index < 80; index++)
        _guest('guest-$index', 'سعيد رقم ${index.toString().padLeft(3, '0')}'),
    ];
    await _pump(tester, guests);

    await tester.tap(find.byKey(const ValueKey('guests-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'سعيد');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('سعيد رقم 079'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('سعيد رقم 079'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Guest _guest(String id, String name) => Guest(
  id: id,
  weddingPlanId: _planId,
  name: name,
  side: 'GROOM',
  status: 'INVITED',
  attendanceStatus: 'PENDING',
  invitationStatus: 'SENT',
  seatsCount: 1,
  companionsCount: 0,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

const _planId = 'plan-long-list';

class _CachedGuestsApi extends GuestsApi {
  _CachedGuestsApi(super.apiClient, this.cached, {super.offline});

  final List<Guest> cached;

  @override
  Future<List<Guest>> getGuests(String weddingPlanId) async => cached;

  @override
  Future<List<GuestGroup>> getGroups(String weddingPlanId) async => const [];
}

Future<void> _pump(
  WidgetTester tester,
  List<Guest> guests, {
  double height = 900,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final offline = OfflineSyncService(database: database, apiClient: apiClient);
  await offline.refreshStatus();
  final api = _CachedGuestsApi(apiClient, guests, offline: offline);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(384, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
        ChangeNotifierProvider<GuestsProvider>(
          create: (_) => GuestsProvider(api),
        ),
      ],
      child: const MaterialApp(home: GuestListScreen(weddingPlanId: _planId)),
    ),
  );
  await tester.pumpAndSettle();
}
