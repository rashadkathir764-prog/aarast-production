import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:aarast_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

// Offline, a notice cannot be marked read; it still opens what it points to.
// An archive that fails says so.

const _planId = 'plan-1';

void main() {
  testWidgets('a notice opens even when marking it read fails', (tester) async {
    await _pump(tester, _Api(failWrites: true));

    await tester.tap(find.text('محمد عطاك مهمة'));
    await tester.pumpAndSettle();

    expect(find.text('opened tasks'), findsOneWidget);
  });

  testWidgets('an archive that fails says so', (tester) async {
    await _pump(tester, _Api(failWrites: true));

    await tester.tap(find.byTooltip('أرشفة التنبيه').first);
    await tester.pumpAndSettle();

    expect(find.text('ما وصلنا'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

Future<void> _pump(WidgetTester tester, _Api api) async {
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  await storage.saveSession(
    accessToken: 'token',
    user: const SafeUser(
      id: 'u1',
      name: 'محمد',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );
  final selected = accountContext(
    role: AccountContextRole.owner,
    planId: _planId,
  );
  final controller = AccountContextController(
    contextsApi: _Gateway(selected),
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh(allowInitialSingleContext: true);
  addTearDown(controller.dispose);
  final notifications = NotificationsProvider(api);
  addTearDown(notifications.dispose);
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(weddingPlanId: _planId),
      ),
      GoRoute(
        path: '/wedding-plans/:id/tasks',
        builder: (_, _) => const Scaffold(body: Text('opened tasks')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: storage),
        ChangeNotifierProvider<AccountContextController>.value(
          value: controller,
        ),
        ChangeNotifierProvider<NotificationsProvider>.value(
          value: notifications,
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _Api extends NotificationsApi {
  _Api({this.failWrites = false})
    : super(ApiClient(tokenProvider: () async => 'token'));

  final bool failWrites;

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    final at = DateTime.now().subtract(const Duration(hours: 2));
    return NotificationsPage(
      items: [
        AarastNotification(
          id: 'n1',
          userId: 'u1',
          weddingPlanId: _planId,
          type: 'TASK_ASSIGNED_TEST',
          title: 'محمد عطاك مهمة',
          body: 'رتّب سيارات الزفة',
          routeTarget: '/wedding-plans/$_planId/tasks',
          createdAt: at,
          updatedAt: at,
        ),
      ],
      page: page,
      limit: limit,
      total: 1,
      totalPages: 1,
      hasMore: false,
    );
  }

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async => 1;

  @override
  Future<AarastNotification> markRead(String id) async {
    throw const ApiException('ما وصلنا', isNetworkFailure: true);
  }

  @override
  Future<AarastNotification> archiveNotification(String id) async {
    throw const ApiException('ما وصلنا', isNetworkFailure: true);
  }
}

class _Gateway implements AccountContextsGateway {
  const _Gateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}
