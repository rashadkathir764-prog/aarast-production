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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

const _planId = 'shared-plan';

void main() {
  testWidgets('q21: a participant reads the plan\'s notices plainly', (
    tester,
  ) async {
    final harness = await _pump(tester, role: AccountContextRole.contributor);

    expect(find.text('التنبيهات'), findsOneWidget);
    expect(find.text('من عرس محمد'), findsOneWidget);
    expect(find.text('رتّب سيارات الزفة · قبل 15 يناير'), findsOneWidget);
    expect(find.text('ذكّر آل الحمدي اللي ما ردّوا'), findsOneWidget);
    // One teal dot for the one new notice; no time, no archive button.
    expect(
      find.byKey(const ValueKey('notification-unread-dot')),
      findsOneWidget,
    );
    expect(find.byTooltip('أرشفة التنبيه'), findsNothing);
    expect(find.text('اليوم'), findsNothing);
    expect(find.text('قراءة الكل'), findsNothing);
    expect(
      find.byKey(const ValueKey('participant-notifications-note')),
      findsOneWidget,
    );
    expect(
      find.text(
        'توصلك بس الأشياء اللي تخصك، وعلى شاشة القفل تطلع بدون أسماء ولا مبالغ.',
      ),
      findsOneWidget,
    );
    expect(harness.api.planIds, [_planId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the owner keeps the grouped list with times and archiving', (
    tester,
  ) async {
    await _pump(tester, role: AccountContextRole.owner);

    expect(find.text('من عرس محمد'), findsNothing);
    expect(find.byTooltip('أرشفة التنبيه'), findsWidgets);
    expect(
      find.byKey(const ValueKey('participant-notifications-note')),
      findsNothing,
    );
  });
}

Future<({_Api api})> _pump(
  WidgetTester tester, {
  required AccountContextRole role,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  await storage.saveSession(
    accessToken: 'token',
    user: const SafeUser(
      id: 'saleh',
      name: 'صالح',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );
  final selected = accountContext(
    role: role,
    planId: _planId,
    displayName: 'عرس محمد',
  );
  final controller = AccountContextController(
    contextsApi: _Gateway(selected),
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh(allowInitialSingleContext: true);
  addTearDown(controller.dispose);
  final api = _Api();
  final notifications = NotificationsProvider(api);
  addTearDown(notifications.dispose);
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
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const NotificationsScreen(weddingPlanId: _planId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (api: api);
}

class _Api extends NotificationsApi {
  _Api() : super(ApiClient(tokenProvider: () async => 'token'));

  final List<String?> planIds = [];

  AarastNotification _notice(
    String id,
    String type,
    String title,
    String body, {
    bool unread = false,
  }) {
    final at = DateTime.now().subtract(const Duration(hours: 2));
    return AarastNotification(
      id: id,
      userId: 'saleh',
      weddingPlanId: _planId,
      type: type,
      title: title,
      body: body,
      createdAt: at,
      updatedAt: at,
      readAt: unread ? null : at,
    );
  }

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async {
    planIds.add(weddingPlanId);
    return NotificationsPage(
      items: [
        _notice(
          'n1',
          'TASK_ASSIGNED_TEST',
          'محمد عطاك مهمة',
          'رتّب سيارات الزفة · قبل 15 يناير',
          unread: true,
        ),
        _notice(
          'n2',
          'TASK_DUE_SOON_TEST',
          'مهمتك بكرة',
          'ذكّر آل الحمدي اللي ما ردّوا',
        ),
      ],
      page: page,
      limit: limit,
      total: 2,
      totalPages: 1,
      hasMore: false,
    );
  }

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async => 1;
}

class _Gateway implements AccountContextsGateway {
  const _Gateway(this.context);

  final AccountContext context;

  @override
  Future<List<AccountContext>> listContexts() async => [context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => context;
}
