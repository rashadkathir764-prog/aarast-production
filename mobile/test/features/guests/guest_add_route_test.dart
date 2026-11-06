import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/providers/guests_provider.dart';
import 'package:aarast_mobile/features/guests/screens/guest_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _planId = 'guest-plan-add-route';

/// RA-MO-26: the plan's «+» adds a guest on /guests/add, which goes back to
/// the list as soon as the guest is saved. Its receipt still offered «أضف
/// ثاني», bound to the screen that had just closed: tapping it threw and
/// opened nothing (the groom walk, e06).
void main() {
  testWidgets('«أضف ثاني» after the add route closes opens the form again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final offline = OfflineSyncService(database: database, apiClient: apiClient);
    await offline.refreshStatus();
    final api = GuestsApi(apiClient, offline: offline);
    final router = GoRouter(
      initialLocation: '/wedding-plans/$_planId/guests/add',
      routes: [
        GoRoute(
          path: '/wedding-plans/:id/guests',
          builder: (context, state) =>
              const GuestListScreen(weddingPlanId: _planId),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const GuestListScreen(
                weddingPlanId: _planId,
                openAddOnStart: true,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(384, 900);
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ضيف جديد'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'ضيف أول');
    await tester.tap(find.byKey(const ValueKey('guest-form-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(router.state.uri.path, '/wedding-plans/$_planId/guests');
    expect(find.text('ضيف جديد'), findsNothing);

    await tester.tap(find.text('أضف ثاني'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ضيف جديد'), findsOneWidget);
  });
}
