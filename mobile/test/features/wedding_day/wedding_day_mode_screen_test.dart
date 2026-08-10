import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/wedding_day/screens/wedding_day_mode_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('wedding day completion keeps offline data and supports undo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final summary = _summary(now);
    final taskProvider = _DayTaskProvider(_task(now));
    final dashboardProvider = _StaticDashboardProvider(summary);
    addTearDown(taskProvider.dispose);
    addTearDown(dashboardProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskTimelineProvider>.value(
            value: taskProvider,
          ),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboardProvider,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: WeddingDayModeScreen(
            weddingPlanId: summary.planId,
            initialSummary: summary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('نعرض ما هو محفوظ على الجهاز'), findsOneWidget);
    expect(find.text('تأكيد وصول القاعة'), findsWidgets);

    await tester.tap(find.byTooltip('إنجاز تأكيد وصول القاعة'));
    await tester.pumpAndSettle();

    expect(taskProvider.completeCalls, 1);
    expect(find.text('تم إنجاز المهمة.'), findsOneWidget);
    expect(find.text('تراجع'), findsOneWidget);

    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();

    expect(taskProvider.reopenCalls, 1);
    expect(taskProvider.tasks.single.status, 'TODO');
    expect(tester.takeException(), isNull);
  });
}

class _StaticDashboardProvider extends DashboardSummaryProvider {
  _StaticDashboardProvider(this.value)
    : super(
        weddingPlansApi: WeddingPlansApi(
          ApiClient(tokenProvider: () async => null),
        ),
      );

  final DashboardSummary value;

  @override
  DashboardSummary? get summary => value;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadDashboard(
    String weddingPlanId, {
    dynamic sharedMember,
  }) async {}
}

class _DayTaskProvider extends TaskTimelineProvider {
  _DayTaskProvider(WeddingTask task)
    : _items = [task],
      super(TaskTimelineApi(ApiClient(tokenProvider: () async => null)));

  List<WeddingTask> _items;
  int completeCalls = 0;
  int reopenCalls = 0;

  @override
  List<WeddingTask> get tasks => _items;

  @override
  TaskSummary get summary => TaskSummary.fromTasks(
    weddingPlanId: 'plan-day',
    tasks: _items,
    now: DateTime.now(),
  );

  @override
  bool get isLoading => false;

  @override
  bool get isSubmitting => false;

  @override
  String? get errorMessage => 'لا يوجد اتصال';

  @override
  Future<void> load(String weddingPlanId) async {}

  @override
  Future<bool> markTaskDone(String weddingPlanId, WeddingTask task) async {
    completeCalls += 1;
    _items = [task.copyWith(status: 'DONE')];
    notifyListeners();
    return true;
  }

  @override
  Future<bool> reopenTask(String weddingPlanId, WeddingTask task) async {
    reopenCalls += 1;
    _items = [task.copyWith(status: 'TODO')];
    notifyListeners();
    return true;
  }
}

DashboardSummary _summary(DateTime now) {
  return DashboardSummary(
    planId: 'plan-day',
    title: 'عرس ريان وسارة',
    status: 'PLANNING',
    progressPercentage: 80,
    weddingDate: now,
    city: 'صنعاء',
    daysRemaining: 0,
    totalTasks: 1,
    completedTasks: 0,
    overdueTasks: 0,
    todayTasks: 1,
    guestCount: 20,
    confirmedGuests: 15,
    providerCount: 0,
    quoteRequestsCount: 0,
    unreadNotificationsCount: 0,
    importantItems: const [],
    planProviders: const [],
    importantNotifications: const [],
    permissions: const DashboardPermissionSummary(
      isOwner: true,
      canViewMoney: true,
      canManageTasks: true,
      canManageMoney: true,
      canManagePlan: true,
    ),
  );
}

WeddingTask _task(DateTime now) {
  return WeddingTask(
    id: 'task-day',
    weddingPlanId: 'plan-day',
    title: 'تأكيد وصول القاعة',
    dueDate: now,
    status: 'TODO',
    priority: 'URGENT',
    createdAt: now,
    updatedAt: now,
  );
}
