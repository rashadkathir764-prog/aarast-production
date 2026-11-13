import 'dart:async';

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

  // RA-MO-150: the page waited for the notice to be marked read (two trips
  // to the server, no sign of it), and a second tap sent it again.
  testWidgets('a notice opens at once, and a second tap sends nothing', (
    tester,
  ) async {
    final api = _Api(failWrites: true)..holdMarkRead = Completer<void>();
    await _pump(tester, api);

    await tester.tap(find.text('محمد عطاك مهمة'));
    await tester.tap(find.text('محمد عطاك مهمة'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('opened tasks'), findsOneWidget);
    expect(api.markReadCalls, 1);
    api.holdMarkRead!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a notice for the groom\'s other plan opens that plan', (
    tester,
  ) async {
    final other = accountContext(
      role: AccountContextRole.owner,
      planId: 'plan-2',
    );
    final controller = await _pump(
      tester,
      _Api(target: '/wedding-plans/plan-2/tasks'),
      others: [other],
    );

    await tester.tap(find.text('محمد عطاك مهمة'));
    await tester.pumpAndSettle();

    expect(controller.selectedContext?.weddingPlanId, 'plan-2');
    expect(find.text('opened tasks'), findsOneWidget);
    // RA-MO-151: the switch to another plan is said, by its name.
    expect(find.text('فتحنا «Plan plan-2»'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  // RA-MO-151: the account's list mixed two plans' notices, none named.
  testWidgets('the account\'s list names each notice\'s plan', (tester) async {
    await _pump(
      tester,
      _Api(),
      others: [accountContext(role: AccountContextRole.owner, planId: 'p-2')],
      accountWide: true,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('notification-plan'))).data,
      'Plan plan-1',
    );
  });

  // D112 (Q-21): a plan in the memories keeps reminding of its payment
  // dates, and its owner reads it. The notice answered «خطة ما عاد توصل
  // لها» and stayed unread; it now opens that plan to read, on its page.
  testWidgets(
    'a notice for the owner\'s plan in the memories opens it to read',
    (tester) async {
      final memory = accountContext(
        role: AccountContextRole.owner,
        planId: 'plan-2',
        lifecycle: 'ARCHIVED',
        accessMode: AccountContextAccessMode.readOnly,
        isAvailable: false,
        unavailableReason: 'PLAN_ARCHIVED',
      );
      final controller = await _pump(
        tester,
        _Api(target: '/wedding-plans/plan-2/tasks'),
        others: [memory],
      );

      await tester.tap(find.text('محمد عطاك مهمة'));
      await tester.pumpAndSettle();

      expect(controller.selectedContext?.weddingPlanId, 'plan-2');
      expect(controller.selectedContext?.isOwnerMemory, isTrue);
      expect(find.text('opened tasks'), findsOneWidget);
      expect(
        find.text('هذا التنبيه لخطة ما عاد توصل لها من هذا الحساب.'),
        findsNothing,
      );
    },
  );

  testWidgets('a notice for a plan no longer reachable says so', (
    tester,
  ) async {
    await _pump(tester, _Api(target: '/wedding-plans/plan-gone/tasks'));

    await tester.tap(find.text('محمد عطاك مهمة'));
    await tester.pumpAndSettle();

    expect(
      find.text('هذا التنبيه لخطة ما عاد توصل لها من هذا الحساب.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an archive that fails says so', (tester) async {
    await _pump(tester, _Api(failWrites: true));

    await tester.tap(find.byTooltip('أرشفة التنبيه').first);
    await tester.pumpAndSettle();

    expect(find.text('ما وصلنا'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

Future<AccountContextController> _pump(
  WidgetTester tester,
  _Api api, {
  List<AccountContext> others = const [],

  /// The account's list, every plan's notices together.
  bool accountWide = false,
}) async {
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
    contextsApi: _Gateway([selected, ...others]),
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
        builder: (_, _) =>
            NotificationsScreen(weddingPlanId: accountWide ? null : _planId),
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
  return controller;
}

class _Api extends NotificationsApi {
  _Api({this.failWrites = false, this.target = '/wedding-plans/$_planId/tasks'})
    : super(ApiClient(tokenProvider: () async => 'token'));

  final bool failWrites;
  final String target;

  /// Holds marking read until completed (RA-MO-150).
  Completer<void>? holdMarkRead;
  int markReadCalls = 0;

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
          routeTarget: target,
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
    markReadCalls += 1;
    await holdMarkRead?.future;
    throw const ApiException('ما وصلنا', isNetworkFailure: true);
  }

  @override
  Future<AarastNotification> archiveNotification(String id) async {
    if (!failWrites) throw StateError('unexpected archive');
    throw const ApiException('ما وصلنا', isNetworkFailure: true);
  }
}

class _Gateway implements AccountContextsGateway {
  const _Gateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async =>
      contexts.firstWhere((path) => path.contextKey == contextKey);
}
