import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
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

void main() {
  testWidgets(
    'mismatched plan notification is neither opened nor marked read',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      await authStorage.saveSession(
        accessToken: 'test-token',
        user: const SafeUser(
          id: 'user-1',
          name: 'مستخدم الاختبار',
          role: 'CUSTOMER',
          status: 'ACTIVE',
        ),
      );

      final selectedContext = accountContext(
        role: AccountContextRole.owner,
        planId: 'plan-selected',
      );
      final contextController = AccountContextController(
        contextsApi: _StaticContextsGateway(selectedContext),
        authStorage: authStorage,
        setActiveWeddingPlan: (_) async {},
      );
      await contextController.refresh(allowInitialSingleContext: true);
      addTearDown(contextController.dispose);

      final api = _MismatchNotificationsApi();
      final notifications = NotificationsProvider(api);
      addTearDown(notifications.dispose);
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/wedding-plans/:planId/tasks',
            builder: (_, _) => const Scaffold(key: Key('opened-plan-route')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>.value(value: authStorage),
            ChangeNotifierProvider<AccountContextController>.value(
              value: contextController,
            ),
            ChangeNotifierProvider<NotificationsProvider>.value(
              value: notifications,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تنبيه خطة أخرى'), findsOneWidget);
      await tester.tap(find.text('تنبيه خطة أخرى'));
      await tester.pump();

      expect(api.markReadCalls, 0);
      expect(notifications.notifications.single.isUnread, isTrue);
      expect(find.byKey(const Key('opened-plan-route')), findsNothing);
      expect(find.text('تنبيه خطة أخرى'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    },
  );
}

class _MismatchNotificationsApi extends NotificationsApi {
  _MismatchNotificationsApi()
    : super(ApiClient(tokenProvider: () async => 'test-token'));

  int markReadCalls = 0;

  AarastNotification get notification => AarastNotification(
    id: 'notification-old-plan',
    userId: 'user-1',
    weddingPlanId: 'plan-old',
    type: 'CONTEXT_MISMATCH_TEST',
    title: 'تنبيه خطة أخرى',
    body: 'هذا التنبيه يعود إلى خطة غير محددة.',
    routeTarget: '/wedding-plans/plan-old/tasks',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    return NotificationsPage(
      items: [notification],
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
    markReadCalls += 1;
    return notification.copyWith(readAt: DateTime(2026, 1, 2));
  }
}

class _StaticContextsGateway implements AccountContextsGateway {
  const _StaticContextsGateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}
