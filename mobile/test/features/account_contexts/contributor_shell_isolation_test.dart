import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/shell/main_shell.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:aarast_mobile/features/tasks/screens/task_timeline_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_management_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'contributor shell builds one workspace without navigation tabs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final storage = AuthStorage(await SharedPreferences.getInstance());
      final apiClient = ApiClient(tokenProvider: () async => 'test-token');
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'controlled test network failure',
            ),
          ),
        ),
      );
      final weddingPlansApi = WeddingPlansApi(apiClient);
      final contributor = accountContext(
        role: AccountContextRole.contributor,
        planId: 'shared-plan',
      );
      final contexts = AccountContextController(
        contextsApi: _SingleContextGateway(contributor),
        authStorage: storage,
        setActiveWeddingPlan: (_) async {},
      );
      await contexts.refresh();
      expect(await contexts.select(contributor.contextKey), isTrue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountContextController>.value(
              value: contexts,
            ),
            ChangeNotifierProvider(
              create: (_) => AuthController(AuthRepository(apiClient, storage)),
            ),
            ChangeNotifierProvider(
              create: (_) => WeddingPlansProvider(weddingPlansApi),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  DashboardSummaryProvider(weddingPlansApi: weddingPlansApi),
            ),
          ],
          child: const MaterialApp(home: MainShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('contributor-workspace-${contributor.contextKey}')),
        findsOneWidget,
      );
      expect(find.byType(PlanCenterScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(IndexedStack), findsNothing);
      expect(
        find.byKey(
          ValueKey('contributor-navigation-${contributor.contextKey}'),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('contributor-tab-money')), findsNothing);
      expect(
        find.byKey(const ValueKey('contributor-tab-guests')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('contributor-tab-providers')),
        findsNothing,
      );
      expect(find.byType(WeddingPlanDashboardScreen), findsNothing);
      expect(find.byType(PlanShellChrome), findsNothing);
      expect(find.byType(TaskTimelineScreen), findsNothing);

      await tester.tap(find.byKey(const Key('contributor-account-action')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contributor-account-sheet')),
        findsOneWidget,
      );
      expect(find.text('الخروج من المساحة'), findsOneWidget);
      expect(find.text('تسجيل الخروج من الحساب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SingleContextGateway implements AccountContextsGateway {
  const _SingleContextGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    if (contextKey != context.contextKey) {
      throw StateError('Unknown context');
    }
    return context;
  }
}
