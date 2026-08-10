import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_attendance_brief.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/widgets/tasks_progress_brief.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  testWidgets('tasks shared transition never constrains the summary card', (
    tester,
  ) async {
    const summary = TaskSummary(
      weddingPlanId: 'plan-1',
      total: 8,
      completed: 3,
      pendingInProgress: 5,
      overdue: 1,
      dueToday: 2,
      highPriority: 2,
    );

    await _verifyTransition(
      tester,
      label: 'المهام',
      heroTag: 'plan-1-tasks',
      icon: LucideIcons.listChecks,
      destination: const TasksProgressBrief(
        summary: summary,
        heroTag: 'plan-1-tasks',
      ),
    );
  });

  testWidgets('guests shared transition never constrains the summary card', (
    tester,
  ) async {
    final guests = [
      Guest(
        id: 'guest-1',
        weddingPlanId: 'plan-1',
        name: 'ضيف تجريبي',
        phone: '+967777123456',
        side: 'GROOM',
        status: 'PENDING',
        attendanceStatus: 'PENDING',
        seatsCount: 1,
        createdAt: DateTime(2026, 8, 9),
        updatedAt: DateTime(2026, 8, 9),
      ),
    ];
    final summary = GuestSummary.fromGuests(
      weddingPlanId: 'plan-1',
      guests: guests,
      groups: const [],
    );

    await _verifyTransition(
      tester,
      label: 'الضيوف',
      heroTag: 'plan-1-guests',
      icon: LucideIcons.users,
      destination: GuestAttendanceBrief(
        summary: summary,
        heroTag: 'plan-1-guests',
      ),
    );
  });
}

Future<void> _verifyTransition(
  WidgetTester tester, {
  required String label,
  required Object heroTag,
  required IconData icon,
  required Widget destination,
}) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: AarastV3MetricGrid(
                items: [
                  AarastV3MetricGridData(
                    icon: icon,
                    label: label,
                    value: '3',
                    detail: 'يحتاج انتباهك',
                    heroTag: heroTag,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Directionality(
                          textDirection: TextDirection.rtl,
                          child: Scaffold(
                            body: Padding(
                              padding: const EdgeInsets.all(20),
                              child: destination,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text(label));
  await tester.pump();
  for (final duration in const [
    Duration(milliseconds: 40),
    Duration(milliseconds: 80),
    Duration(milliseconds: 120),
  ]) {
    await tester.pump(duration);
    expect(tester.takeException(), isNull);
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
