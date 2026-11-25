import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
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
import '../../../integration_test/journeys/support/journey_harness.dart';
import '../../support/app_route_table.dart';

// Offline, a notice cannot be marked read; it still opens what it points to.
// An archive that fails says so.

const _planId = 'plan-1';

void main() {
  testWidgets(
    'the journey returns from a pushed notice before opening the next',
    (tester) async {
      await _pump(
        tester,
        _Api(count: 2, target: '/wedding-plans/$_planId/tasks/task-1'),
      );
      final walk = _WidgetWalk(tester);
      await walk.step('open-notices', 'open every notice', () async {
        await walk.openEachNotice(
          keyPrefix: 'notification-',
          home: '/notifications',
        );
      }, screenshot: false);
      expect(walk.steps.single.problems, isEmpty);
      expect(
        walk.steps.single.notes.where((note) => note.contains('→')),
        hasLength(2),
      );
    },
  );
  // RA-MO-357: a tap on a push opens the inbox naming its notice; the notice
  // opens as a tap on its row does (the same guards), and is marked read.
  testWidgets('a push tap opens its notice and marks it read', (tester) async {
    final api = _Api(failWrites: true);
    await _pump(tester, api, openId: 'n1');

    expect(find.text('opened tasks'), findsOneWidget);
    expect(api.markReadCalls, 1);
    // The server hears the push was opened (and marks it read itself).
    expect(api.opened, ['n1']);
  });

  // The notice was looked for in the first page alone: an older one, or one
  // pushed out by twenty newer, opened nothing.
  testWidgets('a push tap for a notice past the first page opens it', (
    tester,
  ) async {
    final api = _Api(failWrites: true);
    final at = DateTime.utc(2026, 1, 1);
    api.older['n-old'] = AarastNotification(
      id: 'n-old',
      userId: 'u1',
      weddingPlanId: _planId,
      type: 'TASK_ASSIGNED_TEST',
      title: 'مهمة قديمة',
      body: 'رتّب القاعة',
      routeTarget: '/wedding-plans/$_planId/tasks',
      createdAt: at,
      updatedAt: at,
    );
    await _pump(tester, api, openId: 'n-old');

    expect(find.text('opened tasks'), findsOneWidget);
    expect(api.opened, ['n-old']);
  });

  testWidgets('a push tap for a notice gone says so, on the inbox', (
    tester,
  ) async {
    final api = _Api(failWrites: true);
    await _pump(tester, api, openId: 'gone');

    expect(find.text('opened tasks'), findsNothing);
    expect(find.text('محمد عطاك مهمة'), findsOneWidget);
    expect(find.text('لم يعد هذا متاحًا'), findsOneWidget);
    expect(api.markReadCalls, 0);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('offline, a push tap opens the phone\'s copy of its notice', (
    tester,
  ) async {
    final api = _Api(failWrites: true)..unreachable = true;
    await _pump(tester, api, openId: 'n1');

    expect(find.text('opened tasks'), findsOneWidget);
  });

  testWidgets('offline with no copy of it, the inbox says why it did not '
      'open', (tester) async {
    final api = _Api(failWrites: true)..unreachable = true;
    await _pump(tester, api, openId: 'n-elsewhere');

    expect(find.text('opened tasks'), findsNothing);
    expect(find.textContaining('لا اتصال بالشبكة'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a push tap whose target the guards refuse stays on the inbox', (
    tester,
  ) async {
    final api = _Api(failWrites: true, target: 'https://elsewhere.example/x');
    await _pump(tester, api, openId: 'n1');

    expect(find.text('opened tasks'), findsNothing);
    expect(api.markReadCalls, 0);
  });

  testWidgets('a push tap for another plan\'s notice opens that plan', (
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
      openId: 'n1',
    );

    expect(controller.selectedContext?.weddingPlanId, 'plan-2');
    expect(find.text('opened tasks'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

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

    // Changed on purpose (critique ت3): archiving is the row's swipe.
    await tester.drag(
      find
          .byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'notification-swipe-',
                ),
          )
          .first,
      // Toward the row's start, which is the right in Arabic.
      const Offset(500, 0),
    );
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

  /// The notice a push tap named.
  String? openId,
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
        path: appRoute('/notifications'),
        builder: (_, _) => NotificationsScreen(
          weddingPlanId: accountWide ? null : _planId,
          openNotificationId: openId,
        ),
      ),
      GoRoute(
        path: appRoute('/wedding-plans/:id/tasks'),
        builder: (_, _) => const Scaffold(body: Text('opened tasks')),
      ),
      GoRoute(
        path: appRoute('/wedding-plans/:id/tasks/:taskId'),
        builder: (_, _) =>
            Scaffold(appBar: AppBar(), body: const Text('opened tasks')),
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
  _Api({
    this.failWrites = false,
    this.target = '/wedding-plans/$_planId/tasks',
    this.count = 1,
  }) : super(ApiClient(tokenProvider: () async => 'token'));

  final bool failWrites;
  final String target;
  final int count;

  /// Holds marking read until completed (RA-MO-150).
  Completer<void>? holdMarkRead;
  int markReadCalls = 0;

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    final at = appNow().subtract(const Duration(hours: 2));
    return NotificationsPage(
      items: [
        for (var index = 1; index <= count; index++)
          AarastNotification(
            id: 'n$index',
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
      total: count,
      totalPages: 1,
      hasMore: false,
    );
  }

  /// Notices past the first page: the server has them, the list does not.
  final Map<String, AarastNotification> older = {};

  /// The server is out of reach for the notice asked by its id.
  bool unreachable = false;
  final List<String> opened = [];

  @override
  Future<AarastNotification> getNotification(String id) async {
    if (unreachable) {
      throw const ApiException('ما وصلنا', isNetworkFailure: true);
    }
    final listed = (await getNotifications()).items
        .where((item) => item.id == id)
        .firstOrNull;
    final notice = listed ?? older[id];
    if (notice == null) {
      throw const ApiException('غير موجود', statusCode: 404);
    }
    return notice;
  }

  @override
  Future<void> markOpened(String id) async => opened.add(id);

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

// Unit bindings use fake async; real screenshots and file IO belong to the
// integration run. Keep the same navigation and notice-opening code here.
class _WidgetWalk extends JourneyWalk {
  _WidgetWalk(WidgetTester tester)
    : super(tester, 'notification-return-contract');

  @override
  Future<String> capture(String name) async => name;

  @override
  Future<void> settle({double seconds = 1.5}) async {
    await tester.pumpAndSettle();
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
