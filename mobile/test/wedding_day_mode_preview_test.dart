@Tags(['golden'])
library;

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/wedding_day/widgets/wedding_day_mode_view.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('wedding day mode — one-hand command view (390)', (tester) async {
    var completed = 0;
    await _pump(
      tester,
      size: const Size(390, 900),
      onComplete: (_) => completed += 1,
    );

    expect(find.text('يومكم هنا، بهدوء ووضوح'), findsOneWidget);
    expect(find.text('تأكيد وصول القاعة'), findsWidgets);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/wedding_day_mode.png'),
    );

    await tester.tap(find.byTooltip('إنجاز تأكيد وصول القاعة'));
    expect(completed, 1);
  });

  testWidgets('wedding day mode stays safe at 320px and 1.3 text', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(320, 760),
      textScale: 1.3,
      onComplete: (_) {},
    );

    expect(find.text('ما يحتاجك الآن'), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required ValueChanged<WeddingTask> onComplete,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('اليوم الكبير')),
          body: WeddingDayModeView(
            summary: _summary,
            tasks: _tasks,
            now: _now,
            onRefresh: () async {},
            onCompleteTask: onComplete,
            onCopyPhone: (_) {},
            onOpenTasks: () {},
            onOpenGuests: () {},
            onOpenProviders: () {},
            onOpenProvider: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _now = DateTime(2026, 8, 9, 10);

final _summary = DashboardSummary(
  planId: 'plan-wedding-day',
  title: 'عرس ريان وسارة',
  status: 'PLANNING',
  progressPercentage: 88,
  weddingDate: DateTime(2026, 8, 9, 20),
  city: 'صنعاء',
  location: const {'fullLabel': 'قاعة النخبة · شارع حدة'},
  daysRemaining: 0,
  totalTasks: 8,
  completedTasks: 5,
  overdueTasks: 1,
  todayTasks: 2,
  guestCount: 120,
  confirmedGuests: 96,
  providerCount: 2,
  quoteRequestsCount: 2,
  unreadNotificationsCount: 0,
  importantItems: const [],
  planProviders: const [
    DashboardProviderPreview(
      id: 'plan-provider-1',
      providerId: 'provider-1',
      businessName: 'قاعة النخبة',
      categoryName: 'صالات',
      serviceTitle: 'الباقة الرئيسية',
      ratingAverage: '4.8',
      ratingCount: 80,
      status: 'ACTIVE',
    ),
  ],
  importantNotifications: const [],
  permissions: const DashboardPermissionSummary(
    isOwner: true,
    canViewMoney: true,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: true,
    canManageMoney: true,
    canManagePlan: true,
  ),
);

final _tasks = [
  WeddingTask(
    id: 'task-today',
    weddingPlanId: 'plan-wedding-day',
    title: 'تأكيد وصول القاعة',
    dueDate: DateTime(2026, 8, 9, 12),
    responsibleName: 'أحمد',
    responsiblePhone: '+967777123456',
    status: 'TODO',
    priority: 'URGENT',
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  ),
  WeddingTask(
    id: 'task-overdue',
    weddingPlanId: 'plan-wedding-day',
    title: 'استلام تنسيق الطاولات',
    dueDate: DateTime(2026, 8, 8),
    responsibleName: 'سارة',
    status: 'IN_PROGRESS',
    priority: 'HIGH',
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  ),
];
