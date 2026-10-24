// Full-screen visual preview for the guests tab (e01): the summary, the
// invite card and the families.
// The second golden keeps the existing add-guest sheet covered.
// Regenerate with:
//   flutter test test/guests_screen_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/preview_fonts.dart';

const _planId = 'guest-plan-preview';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('guests screen — dashboard language (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1400);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );
    await offline.refreshStatus();
    final api = GuestsApi(apiClient, offline: offline);

    await api.createGuest(
      weddingPlanId: _planId,
      name: 'محمد علي',
      phone: '777123456',
      side: 'GROOM',
      status: 'CONFIRMED',
      seatsCount: 3,
      companionsCount: 2,
    );
    await api.createGuest(
      weddingPlanId: _planId,
      name: 'ليلى سالم',
      phone: '777654321',
      side: 'BRIDE',
      status: 'PENDING',
      seatsCount: 1,
    );
    await api.createGuest(
      weddingPlanId: _planId,
      name: 'ضيف بدون رقم',
      side: 'GROOM',
      status: 'INVITED',
      seatsCount: 1,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
          ChangeNotifierProvider<GuestsProvider>(
            create: (_) => GuestsProvider(api),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const GuestListScreen(weddingPlanId: _planId),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(seconds: 2));

    // e01: the root lists the families; the names open inside a family.
    expect(find.byKey(const ValueKey('guest-group-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-add')), findsOneWidget);

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/guests_screen.png'),
    );
  });

  testWidgets('add guest sheet — chip pickers (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1400);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(
      database: database,
      apiClient: apiClient,
    );
    await offline.refreshStatus();
    final api = GuestsApi(apiClient, offline: offline);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: authStorage),
          ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
          ChangeNotifierProvider<GuestsProvider>(
            create: (_) => GuestsProvider(api),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const GuestListScreen(weddingPlanId: _planId),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    // D32: guests add from their header «+».
    await tester.tap(find.byKey(const ValueKey('guests-add')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));

    // e06 «ضيف جديد» (GuestWords.newGuest).
    expect(find.text('ضيف جديد'), findsWidgets);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/guests_add_sheet.png'),
    );
  });
}
