import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/finance/data/budget_expense_api.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/screens/budget_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const localPlanId = 'guest-plan-budget-setup';

  testWidgets('budget setup saves selected local categories without login', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1100);
    addTearDown(tester.view.reset);

    final harness = await _createHarness();
    final router = GoRouter(
      initialLocation: AppRouter.budgetSetup(localPlanId),
      routes: [
        GoRoute(
          path: AppRouter.budgetSetup(localPlanId),
          builder: (context, state) =>
              const BudgetSetupScreen(weddingPlanId: localPlanId),
        ),
        GoRoute(
          path: AppRouter.finance(localPlanId),
          builder: (context, state) =>
              const Scaffold(body: Text('تم فتح المال')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: harness.authStorage),
          ChangeNotifierProvider<OfflineSyncService>.value(
            value: harness.offline,
          ),
          ChangeNotifierProvider<FinanceProvider>(
            create: (_) => FinanceProvider(
              BudgetExpenseApi(harness.apiClient, offline: harness.offline),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('إعداد الميزانية'), findsOneWidget);
    expect(find.text('الصالة'), findsOneWidget);

    await tester.tap(find.text('مسح'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).first);
    await tester.enterText(find.byType(TextField).first, '300000');
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('حفظ 1 بند'), findsOneWidget);
    await tester.tap(find.text('حفظ 1 بند'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(router.state.uri.path, AppRouter.finance(localPlanId));
    final cached = await harness.offline.database.readCachedList(
      table: OfflineTables.cachedBudgetCategories,
      parentColumn: 'planId',
      parentId: localPlanId,
    );
    expect(cached, hasLength(1));
    expect(cached.first['name'], 'الصالة');
    expect(cached.first['targetAmount'], '300000');
  });
}

Future<_Harness> _createHarness() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: authStorage.readAccessToken);
  final database = JsonLocalDatabase(preferences);
  await database.initialize();
  final offline = OfflineSyncService(database: database, apiClient: apiClient);
  await offline.refreshStatus();
  return _Harness(
    authStorage: authStorage,
    apiClient: apiClient,
    offline: offline,
  );
}

class _Harness {
  const _Harness({
    required this.authStorage,
    required this.apiClient,
    required this.offline,
  });

  final AuthStorage authStorage;
  final ApiClient apiClient;
  final OfflineSyncService offline;
}
