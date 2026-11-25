import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/task_details_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-MO-360: a reminder set is the first reason to say what the alerts are
// for (and to ask the phone); one that was not saved is not.

const _plan = 'plan-1';

void main() {
  testWidgets('a reminder set is the moment to say what the alerts are for', (
    tester,
  ) async {
    final push = await _pump(tester, saves: true);
    expect(push.hasPendingPermissionExplanation, isFalse);

    await _setReminder(tester);

    expect(push.hasPendingPermissionExplanation, isTrue);
  });

  testWidgets('a reminder that was not saved is not', (tester) async {
    final push = await _pump(tester, saves: false);

    await _setReminder(tester);

    expect(push.hasPendingPermissionExplanation, isFalse);
  });
}

Future<void> _setReminder(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('task-detail-reminder')));
  await tester.pumpAndSettle();
  // The day (the task's own, offered first), then the time (nine): the
  // picker's confirm button is the last of its two.
  for (final _ in [0, 1]) {
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
  }
}

Future<PushNotificationsController> _pump(
  WidgetTester tester, {
  required bool saves,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final stored = await SharedPreferences.getInstance();
  final push = PushNotificationsController(
    preferences: stored,
    gateway: _Gateway(),
    registrationApi: _Registry(),
  );
  addTearDown(push.dispose);
  await push.initialize();
  await push.bindAuthenticatedUser('user-1');
  final task = WeddingTask(
    id: 'task-1',
    weddingPlanId: _plan,
    title: 'حجز القاعة',
    dueDate: DateTime(2030, 1, 14),
    status: 'TODO',
    priority: 'MEDIUM',
    createdAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
  );
  final provider = TaskTimelineProvider(_OneTask(task, saves: saves));
  await provider.load(_plan);
  final router = GoRouter(
    initialLocation: '/task',
    routes: [
      GoRoute(
        path: '/task',
        builder: (context, state) =>
            TaskDetailsScreen(weddingPlanId: _plan, taskId: 'task-1'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: AuthStorage(stored)),
        ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
        ChangeNotifierProvider<PushNotificationsController>.value(value: push),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return push;
}

class _OneTask extends TaskTimelineApi {
  _OneTask(this.task, {required this.saves})
    : super(ApiClient(tokenProvider: () async => null));

  final WeddingTask task;
  final bool saves;

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => [task];

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);

  @override
  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    if (!saves) throw const ApiException('ما قدرنا نحفظ التذكير');
    return task.copyWith(
      reminderAt: DateTime.parse(data['reminderAt'] as String),
    );
  }
}

class _Gateway implements PushMessagingGateway {
  @override
  bool get isAvailable => true;

  @override
  Stream<void> get tokenChanges => const Stream<void>.empty();

  @override
  Stream<PushNotificationTap> get notificationTaps =>
      const Stream<PushNotificationTap>.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      const Stream<PushForegroundNotification>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.notDetermined;

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.authorized;

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async => 'fid-1';

  @override
  Future<PushNotificationTap?> consumeInitialNotificationTap() async => null;
}

class _Registry implements PushInstallationRegistry {
  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {}

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {}
}
