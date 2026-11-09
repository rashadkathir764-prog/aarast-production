import 'package:aarast_mobile/app.dart' show AarastPlanProfileScope;
import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/shell/main_shell.dart';
import 'package:aarast_mobile/features/shell/screens/participant_locked_screen.dart';
import 'package:aarast_mobile/features/shell/widgets/aarast_plan_chrome.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_quick_add_sheet.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/participant_tasks_screen.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/guests/screens/participant_guests_screen.dart';
import 'package:aarast_mobile/features/marketplace/screens/participant_providers_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_read_view.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/plan_read_view_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/participant_home_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

const _planId = 'shared-plan';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'x06: the participant opens on their own home inside the five tabs',
    (tester) async {
      final logSink = _CollectingLogSink();
      AppLogger.installGlobal(
        AppLogger(
          redactor: LogRedactor(installationSalt: 'participant-shell-test'),
          sinks: [logSink],
        ),
      );
      addTearDown(AppLogger.clearGlobal);
      final harness = await _Harness.create(
        tasks: [
          _task('t1', 'رتّب الغداء مع أبو علي', days: 2, mine: true),
          _task('t2', 'ذكّر آل الحمدي اللي ما ردّوا', days: 5),
          _task('t3', 'رتّب سيارات الزفة', days: 20),
        ],
      );
      await harness.pump(tester);

      expect(find.byType(ParticipantHomeScreen), findsOneWidget);
      expect(find.byType(AarastPlanNavigationBar), findsOneWidget);
      expect(find.byType(WeddingPlanDashboardScreen), findsNothing);
      // No floating «+» on a participant's tabs (the design draws none).
      expect(find.byType(PlanQuickAddButton), findsNothing);

      expect(find.text('أهلًا صالح'), findsOneWidget);
      expect(find.text('عرس محمد ·'), findsOneWidget);
      expect(find.text('أنت مساعد'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('يوم على العرس'), findsOneWidget);
      // The next step is the nearest open task, finished from here.
      expect(find.textContaining('الخطوة الجاية'), findsOneWidget);
      expect(find.text('رتّب الغداء مع أبو علي'), findsOneWidget);
      expect(find.text('هذي المهمة عليك'), findsOneWidget);
      expect(find.text('مهامك'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('ذكّر آل الحمدي اللي ما ردّوا'), findsOneWidget);
      // Privacy: nothing of the money, only that it is hidden.
      expect(find.text('المال مخفي عنك.'), findsOneWidget);
      expect(find.textContaining('ر.ي'), findsNothing);
      expect(find.textContaining('اطلب من'), findsNothing);
      expect(tester.takeException(), isNull);

      expect(
        logSink.events.where(
          (event) =>
              event.name == 'dashboard_built' &&
              event.category == AppLogCategory.contributor,
        ),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        logSink.events.where(
          (event) =>
              event.name == 'dashboard_disposed' &&
              event.category == AppLogCategory.contributor,
        ),
        hasLength(1),
      );
    },
  );

  testWidgets('x06: «خلصت» finishes the next task', (tester) async {
    final harness = await _Harness.create(
      tasks: [_task('t1', 'رتّب الغداء مع أبو علي', days: 2)],
    );
    await harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('participant-next-done')));
    await tester.pumpAndSettle();

    expect(harness.tasksApi.updates, [
      {'status': 'DONE'},
    ]);
  });

  testWidgets(
    'q07: money without the right is a calm lock; q16: the providers are read',
    (tester) async {
      final harness = await _Harness.create();
      await harness.pump(tester);

      await _openTab(tester, 'المال');
      expect(find.byType(ParticipantLockedScreen), findsOneWidget);
      expect(find.text('المال خاص بالعريس'), findsOneWidget);
      // V-03: a lock says why, and who opens it, from the screen's real
      // name (J2-18).
      expect(
        find.text(
          'ما عندك صلاحية تشوف المال في هذي الخطة. '
          'يفتحها لك العريس من «المشاركين».',
        ),
        findsOneWidget,
      );
      expect(find.text('عرس محمد · أنت مساعد'), findsOneWidget);
      // Asking for the right waits for q13.
      expect(find.text('اطلب من محمد'), findsNothing);
      expect(harness.wedding.moneyRequests, 0);

      // D52: without the providers right the plan's bookings are read (q16),
      // never locked away.
      await _openTab(tester, 'المزودين');
      expect(find.byType(ParticipantProvidersScreen), findsOneWidget);
      expect(find.byType(ParticipantLockedScreen), findsNothing);
      expect(find.text('عرس محمد · تشوف بس'), findsOneWidget);
      expect(
        find.text('المواعيد ومين محجوز. الأسعار والعروض عند العريس.'),
        findsOneWidget,
      );
      expect(find.text('قاعة سبأ'), findsOneWidget);
      expect(find.text('محجوز'), findsOneWidget);
      expect(find.text('ضوء صنعاء'), findsOneWidget);
      expect(find.text('ينتظر تأكيدهم'), findsOneWidget);
      expect(find.text('ينتظر'), findsOneWidget);
      expect(find.textContaining('ر.ي'), findsNothing);
      expect(find.text('اطلب صلاحية'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('q05: «لي» and «كل مهام الخطة», only one\'s own tasks edited', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tasks: [
        _task('t1', 'رتّب الغداء مع أبو علي', days: 2),
        _task('t4', 'استلم البدلة', days: -1, done: true),
      ],
    );
    await harness.pump(tester);
    await _openTab(tester, 'المهام');

    expect(find.byType(ParticipantTasksScreen), findsOneWidget);
    // RA-MO-57: what is still theirs to do, not the one they finished.
    expect(find.text('عرس محمد · معك 1'), findsOneWidget);
    expect(find.text('لي'), findsOneWidget);
    expect(find.text('كل مهام الخطة'), findsOneWidget);
    expect(find.text('لك'), findsOneWidget);
    expect(find.text('استلم البدلة'), findsOneWidget);
    expect(
      find.text(
        'المهام اللي ما هي لك تشوفها في «كل مهام الخطة»، وما تقدر تعدّلها.',
      ),
      findsOneWidget,
    );
    // C27: a participant with the tasks right adds tasks.
    expect(find.byKey(const Key('participant-tasks-add')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('participant-task-toggle-t1')));
    await tester.pumpAndSettle();
    expect(harness.tasksApi.updates, [
      {'status': 'DONE'},
    ]);

    // D52: the plan's tasks are read; none of them has a control.
    await tester.tap(find.byKey(const ValueKey('participant-tasks-plan')));
    await tester.pumpAndSettle();
    expect(harness.wedding.readViewCalls, greaterThan(0));
    expect(find.text('1 من 4'), findsOneWidget);
    expect(find.text('حدد موعد عقد القران'), findsOneWidget);
    expect(find.text('متأخرة'), findsOneWidget);
    expect(find.text('خلصت'), findsWidgets);
    expect(
      find.byKey(const ValueKey('participant-plan-task-p1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('participant-task-toggle-p1')),
      findsNothing,
    );
    expect(find.textContaining('ر.ي'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'D52: «يشوف بس» reads the plan\'s tasks, guests and bookings, edits nothing',
    (tester) async {
      final harness = await _Harness.create(
        role: 'VIEWER',
        userName: 'الوالد',
        canManageTasks: false,
        canManageGuests: false,
      );
      await harness.pump(tester);

      // x06 without its controls: the plan's next step and who does it.
      expect(find.text('أهلًا الوالد'), findsOneWidget);
      expect(find.text('أنت تتابع بس'), findsOneWidget);
      expect(find.text('أنت يشوف بس'), findsNothing);
      expect(find.textContaining('الخطوة الجاية'), findsOneWidget);
      expect(find.text('حدد موعد عقد القران'), findsOneWidget);
      expect(find.text('على محمد'), findsOneWidget);
      expect(find.text('مهام الخطة'), findsOneWidget);
      expect(find.text('خلصت 1 من 4'), findsOneWidget);
      expect(find.byKey(const ValueKey('participant-next-done')), findsNothing);
      expect(find.text('المال مخفي عنك.'), findsOneWidget);
      expect(harness.tasksApi.listCalls, 0);

      await _openTab(tester, 'المهام');
      expect(find.byType(ParticipantTasksScreen), findsOneWidget);
      expect(find.text('عرس محمد · خلصت 1 من 4'), findsOneWidget);
      expect(
        find.text('تتابع المهام وين وصلت. الإضافة والتعديل عند العريس.'),
        findsOneWidget,
      );
      expect(find.text('رتّب الغداء'), findsOneWidget);
      expect(find.text('كل مهام الخطة'), findsNothing);
      expect(find.byKey(const Key('participant-tasks-add')), findsNothing);
      expect(
        find.byKey(const ValueKey('participant-task-toggle-p1')),
        findsNothing,
      );
      expect(find.text('المهام عند العريس'), findsNothing);
      expect(harness.tasksApi.listCalls, 0);

      await _openTab(tester, 'الضيوف');
      expect(find.byType(ParticipantGuestsScreen), findsOneWidget);
      expect(find.text('3 مدعو · 1 أكدوا · 1 ما ردّوا'), findsOneWidget);
      expect(find.text('عبدالله الحمدي'), findsOneWidget);
      expect(find.text('أكّد'), findsOneWidget);
      expect(find.text('اعتذر'), findsOneWidget);
      expect(find.text('ما ردّ'), findsOneWidget);
      expect(
        find.text(
          'تشوف الأسماء والردود. أرقام الجوالات والإضافة والتعديل عند العريس.',
        ),
        findsOneWidget,
      );
      // No phone, no add, no reminder.
      expect(find.textContaining('777'), findsNothing);
      expect(find.textContaining('ذكّر'), findsNothing);
      expect(find.text('الضيوف عند العريس'), findsNothing);

      await _openTab(tester, 'المزودين');
      expect(find.byType(ParticipantProvidersScreen), findsOneWidget);
      expect(find.text('قاعة سبأ'), findsOneWidget);

      await _openTab(tester, 'المال');
      expect(find.text('المال خاص بالعريس'), findsOneWidget);
      expect(find.textContaining('ر.ي'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('D52: in a bride\'s plan «يشوف بس» is spoken to a woman', (
    tester,
  ) async {
    final harness = await _Harness.create(
      role: 'VIEWER',
      persona: AccountContextPersona.bride,
      title: 'عرس سلمى',
      userName: 'الوالدة',
      canManageTasks: false,
      canManageGuests: false,
    );
    await harness.pump(tester);

    expect(find.text('أنتِ تتابعين بس'), findsOneWidget);
    expect(find.text('على العروسة'), findsNothing);

    await _openTab(tester, 'المهام');
    expect(
      find.text('تتابعين المهام وين وصلت. الإضافة والتعديل عند العروسة.'),
      findsOneWidget,
    );

    await _openTab(tester, 'الضيفات');
    expect(find.text('أكّدت'), findsOneWidget);

    await _openTab(tester, 'المزودين');
    expect(find.text('عرس سلمى · تشوفين بس'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('q17: a bride\'s plan speaks in her colour to a woman', (
    tester,
  ) async {
    final harness = await _Harness.create(
      persona: AccountContextPersona.bride,
      title: 'عرس سلمى',
      userName: 'نورة',
    );
    await harness.pump(tester);

    expect(find.text('أهلًا نورة'), findsOneWidget);
    expect(find.text('أنتِ مساعدة'), findsOneWidget);
    expect(
      find.text(
        'الخطة بألوان صاحبتها. لو عندك خطة أنتِ، تبدّلين لها من «حسابي».',
      ),
      findsOneWidget,
    );
    final hero = tester.widget<JourneyBox>(
      find.byKey(const ValueKey('participant-count-hero')),
    );
    expect(hero.color, AarastV3Color.rose);

    await _openTab(tester, 'المال');
    expect(find.text('المال خاص بالعروسة'), findsOneWidget);
    expect(find.text('عرس سلمى · أنتِ مساعدة'), findsOneWidget);
  });

  testWidgets('B5: a groom helping in the bride\'s plan sees her colours and '
      'is spoken to as a man', (tester) async {
    final harness = await _Harness.create(
      persona: AccountContextPersona.bride,
      title: 'عرس سلمى',
      userName: 'محمد',
      role: 'VIEWER',
      userPersona: 'GROOM',
      canManageTasks: false,
      canManageGuests: false,
    );
    await harness.pump(tester);

    expect(find.text('أنت تتابع بس'), findsOneWidget);
    expect(find.text('أنتِ تتابعين بس'), findsNothing);
    final hero = tester.widget<JourneyBox>(
      find.byKey(const ValueKey('participant-count-hero')),
    );
    expect(hero.color, AarastV3Color.rose);
    expect(
      find.text('الخطة بألوان صاحبتها. لو عندك خطة أنت، تبدّل لها من «حسابي».'),
      findsOneWidget,
    );

    // Her guests stay women whoever reads: the tab is hers.
    await _openTab(tester, 'الضيفات');
    expect(find.text('أكّدت'), findsOneWidget);

    await _openTab(tester, 'المزودين');
    expect(find.text('عرس سلمى · تشوف بس'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-63: «7 يوم على العرس».
  testWidgets('a week out the count reads «أيام»', (tester) async {
    final harness = await _Harness.create(daysRemaining: 7);
    await harness.pump(tester);

    expect(find.text('7'), findsOneWidget);
    expect(find.text('أيام على العرس'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('q18: on the day the home is the wedding and today\'s tasks', (
    tester,
  ) async {
    final harness = await _Harness.create(
      daysRemaining: 0,
      tasks: [
        _task('t1', 'استلام الغداء من أبو علي', days: 0),
        _task('t2', 'رتّب سيارات الزفة', days: 3),
      ],
    );
    await harness.pump(tester);

    expect(find.byKey(const ValueKey('participant-day-hero')), findsOneWidget);
    final hero = find.byKey(const ValueKey('participant-day-hero'));
    expect(
      find.descendant(of: hero, matching: find.text('اليوم')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.text('يوم العرس')),
      findsOneWidget,
    );
    expect(find.text('عليك اليوم'), findsOneWidget);
    expect(find.text('استلام الغداء من أبو علي'), findsOneWidget);
    // Only today's tasks; the programme waits for the wedding's events.
    expect(find.text('رتّب سيارات الزفة'), findsNothing);
    expect(find.text('برنامج اليوم'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('participant-today-done-t1')));
    await tester.pumpAndSettle();
    expect(harness.tasksApi.updates, [
      {'status': 'DONE'},
    ]);
  });

  testWidgets('q18: every member reads the day\'s programme (D52, D65)', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    String day(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final harness = await _Harness.create(
      daysRemaining: 0,
      events: [
        {
          'id': 'm',
          'type': 'MAQEEL',
          'date': day(today),
          'timeSlot': 'AFTER_ASR',
          'placeLabel': 'بيت الوالد',
        },
        {
          'id': 'w',
          'type': 'WEDDING',
          'date': day(today),
          'timeSlot': 'AFTER_MAGHRIB',
          'placeLabel': 'قاعة سبأ',
        },
        {
          'id': 's',
          'type': 'SAMRA',
          'date': day(today.subtract(const Duration(days: 2))),
          'timeSlot': 'AFTER_ISHA',
        },
      ],
    );
    await harness.pump(tester);

    expect(find.text('برنامج اليوم'), findsOneWidget);
    expect(find.text('المقيل'), findsOneWidget);
    expect(find.text('بعد العصر · بيت الوالد'), findsOneWidget);
    expect(find.text('الزفاف'), findsOneWidget);
    expect(find.text('السمرة'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'q12: a right the owner opened is told once, from the kept path',
    (tester) async {
      final harness = await _Harness.create(keptCanViewMoney: false);
      // The server now gives the money.
      harness.contexts.replaceGateway(canViewMoney: true);
      await harness.controller.refresh();
      expect(harness.controller.permissionChange, isNotNull);

      await harness.pump(tester);

      expect(find.text('العريس فتح لك المال'), findsOneWidget);
      expect(
        find.text('تقدر الآن تشوف المال. المصادر والسلف تبقى خاصة فيه.'),
        findsOneWidget,
      );
      // Taken by the home: it is told once.
      expect(harness.controller.permissionChange, isNull);
      // The custody step and the removal note are not shown.
      expect(find.textContaining('العهدة'), findsNothing);
      expect(find.textContaining('شالك'), findsNothing);
    },
  );

  for (final (persona, opener) in [
    (JourneyProfile.groom, 'يفتحها لك العريس من «المشاركين».'),
    (JourneyProfile.bride, 'تفتحها لك العروسة من «المشاركين».'),
  ]) {
    testWidgets('J2-18: every lock says who opens it ($opener)', (
      tester,
    ) async {
      for (final section in [
        JourneySection.money,
        JourneySection.tasks,
        JourneySection.guests,
        JourneySection.providers,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: JourneyProfileScope(
              profile: persona,
              child: ParticipantLockedScreen(
                section: section,
                planTitle: 'عرس محمد',
                roleTag: 'أنت مساعد',
                owner: persona.isBride ? 'العروسة' : 'العريس',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(opener),
          findsOneWidget,
          reason: section.name,
        );
        expect(find.textContaining('«المشاركة»'), findsNothing);
      }
    });
  }

  testWidgets('J2-20: q12 speaks to a woman in her words', (tester) async {
    final harness = await _Harness.create(
      keptCanViewMoney: false,
      userPersona: 'BRIDE',
    );
    harness.contexts.replaceGateway(canViewMoney: true);
    await harness.controller.refresh();
    await harness.pump(tester);

    expect(
      find.text('تقدرين الآن تشوفين المال. المصادر والسلف تبقى خاصة فيه.'),
      findsOneWidget,
    );
    expect(find.textContaining('تقدر الآن'), findsNothing);
  });

  testWidgets('q12: the same rights tell nothing', (tester) async {
    final harness = await _Harness.create();
    await harness.controller.refresh();
    await harness.pump(tester);

    expect(harness.controller.permissionChange, isNull);
    expect(
      find.byKey(const ValueKey('participant-rights-changed')),
      findsNothing,
    );
  });

  testWidgets('the participant home fits 320px at 1.3 text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = await _Harness.create(
      tasks: [
        _task('t1', 'رتّب الغداء مع أبو علي في بيت الوالد', days: 2),
        _task('t2', 'ذكّر آل الحمدي', days: 5),
      ],
    );
    await harness.pump(tester, textScale: 1.3, tall: false);
    expect(tester.takeException(), isNull);
    await _openTab(tester, 'المال');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AarastPlanNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

WeddingTask _task(
  String id,
  String title, {
  required int days,
  bool mine = false,
  bool done = false,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  return WeddingTask(
    id: id,
    weddingPlanId: _planId,
    title: title,
    status: done ? 'DONE' : 'TODO',
    priority: 'MEDIUM',
    dueDate: today.add(Duration(days: days)),
    assigneeUserId: mine ? 'saleh' : null,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  );
}

/// D52: the plan as every member reads it; nothing of money or phones.
PlanReadView _readView() {
  final today = DateUtils.dateOnly(DateTime.now());
  String day(int days) => today.add(Duration(days: days)).toIso8601String();
  return PlanReadView.fromJson({
    'weddingPlanId': _planId,
    'tasks': {
      'total': 4,
      'done': 1,
      'items': [
        {
          'id': 'p1',
          'title': 'حدد موعد عقد القران',
          'status': 'TODO',
          'dueDate': day(-7),
          'assignee': {'kind': 'OWNER', 'firstName': 'محمد'},
        },
        {
          'id': 'p2',
          'title': 'رتّب الغداء',
          'status': 'TODO',
          'dueDate': day(3),
          'assignee': {'kind': 'MEMBER', 'firstName': 'صالح'},
        },
        {
          'id': 'p4',
          'title': 'حجز سيارات الزفة',
          'status': 'TODO',
          'dueDate': day(30),
          'assignee': {'kind': 'PERSON', 'firstName': 'الوالد'},
        },
        {
          'id': 'p3',
          'title': 'احجز القاعة',
          'status': 'DONE',
          'dueDate': day(-60),
          'assignee': null,
        },
      ],
    },
    'guests': {
      'total': 3,
      'confirmed': 1,
      'pending': 1,
      'declined': 1,
      'items': [
        {'id': 'g1', 'name': 'عبدالله الحمدي', 'attendanceStatus': 'CONFIRMED'},
        {'id': 'g2', 'name': 'ياسر الأهدل', 'attendanceStatus': 'DECLINED'},
        {'id': 'g3', 'name': 'يحيى السنيدار', 'attendanceStatus': 'PENDING'},
      ],
    },
    'bookings': {
      'items': [
        {
          'id': 'b1',
          'businessName': 'قاعة سبأ',
          'categoryName': 'قاعات',
          'serviceTitle': 'قاعة الأفراح',
          'status': 'CONFIRMED',
          'eventDate': '2027-01-21',
        },
        {
          'id': 'b2',
          'businessName': 'ضوء صنعاء',
          'categoryName': 'تصوير',
          'serviceTitle': null,
          'status': 'REQUESTED',
          'eventDate': '2027-01-21',
        },
      ],
    },
  });
}

class _EventsApi extends PlanEventsApi {
  _EventsApi(super.apiClient, this.items);

  final List<Map<String, dynamic>> items;

  @override
  Future<PlanEventsView> list(String weddingPlanId) async =>
      PlanEventsView.fromJson({
        'weddingPlanId': weddingPlanId,
        'canEdit': false,
        'items': items,
        'suggestions': const [],
      });
}

class _Harness {
  _Harness({
    required this.controller,
    required this.contexts,
    required this.auth,
    required this.wedding,
    required this.dashboard,
    required this.planView,
    required this.tasksApi,
    required this.tasks,
    this.events,
  });

  /// D65: the plan's events, when the test gives them (q18's programme).
  final PlanEventsProvider? events;

  final AccountContextController controller;
  final _Gateway contexts;
  final AuthController auth;
  final _WeddingPlansApi wedding;
  final DashboardSummaryProvider dashboard;
  final PlanReadViewProvider planView;
  final _TasksApi tasksApi;
  final TaskTimelineProvider tasks;

  static Future<_Harness> create({
    AccountContextPersona persona = AccountContextPersona.groom,
    String title = 'عرس محمد',
    String userName = 'صالح الحمدي',
    String role = 'HELPER',
    int daysRemaining = 96,
    bool canManageTasks = true,
    bool canManageGuests = true,
    bool keptCanViewMoney = false,
    List<WeddingTask> tasks = const [],
    String? userPersona,
    List<Map<String, dynamic>>? events,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final user = SafeUser(
      id: 'saleh',
      name: userName,
      phone: '+967771554220',
      role: 'USER',
      status: 'ACTIVE',
      persona: userPersona,
    );
    await storage.saveSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: user,
    );
    final apiClient = ApiClient(tokenProvider: () async => 'token');
    apiClient.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'controlled participant shell test failure',
          ),
        ),
      ),
    );
    final gateway = _Gateway(
      persona: persona,
      title: title,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canViewMoney: keptCanViewMoney,
      // The server speaks to the account's persona first (addressFormOf).
      readerForm: switch (userPersona) {
        'GROOM' => 'MASCULINE',
        'BRIDE' => 'FEMININE',
        _ => null,
      },
    );
    final controller = AccountContextController(
      contextsApi: gateway,
      authStorage: storage,
      setActiveWeddingPlan: (_) async {},
    );
    await controller.refresh();
    expect(await controller.select('plan:$_planId:contributor'), isTrue);
    final repository = _AuthRepository(apiClient, storage, user);
    final auth = AuthController(repository);
    await auth.restoreSession();
    final wedding = _WeddingPlansApi(
      apiClient,
      _summary(
        title: title,
        role: role,
        daysRemaining: daysRemaining,
        canManageTasks: canManageTasks,
        canManageGuests: canManageGuests,
      ),
    );
    final tasksApi = _TasksApi(apiClient, tasks);
    return _Harness(
      controller: controller,
      contexts: gateway,
      auth: auth,
      wedding: wedding,
      dashboard: DashboardSummaryProvider(weddingPlansApi: wedding),
      planView: PlanReadViewProvider(weddingPlansApi: wedding),
      tasksApi: tasksApi,
      tasks: TaskTimelineProvider(tasksApi),
      events: events == null
          ? null
          : PlanEventsProvider(api: _EventsApi(apiClient, events)),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    double textScale = 1,
    bool tall = true,
  }) async {
    if (tall) {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountContextController>.value(
            value: controller,
          ),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<DashboardSummaryProvider>.value(
            value: dashboard,
          ),
          ChangeNotifierProvider<PlanReadViewProvider>.value(value: planView),
          ChangeNotifierProvider<TaskTimelineProvider>.value(value: tasks),
          if (events case final events?)
            ChangeNotifierProvider<PlanEventsProvider>.value(value: events),
        ],
        // The app's root profile (B5): the plan's colours, the reader's
        // voice, as `AarastApp` provides them.
        child: AarastPlanProfileScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const MainShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

DashboardSummary _summary({
  required String title,
  required String role,
  required int daysRemaining,
  required bool canManageTasks,
  required bool canManageGuests,
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  return DashboardSummary(
    planId: _planId,
    title: title,
    status: 'PLANNING',
    progressPercentage: 35,
    weddingDate: today.add(Duration(days: daysRemaining)),
    daysRemaining: daysRemaining,
    currency: 'YER',
    totalTasks: 3,
    completedTasks: 0,
    overdueTasks: 0,
    todayTasks: 0,
    guestCount: 0,
    confirmedGuests: 0,
    providerCount: 0,
    quoteRequestsCount: 0,
    participantCount: 3,
    unreadNotificationsCount: 0,
    importantItems: const [],
    planProviders: const [],
    importantNotifications: const [],
    permissions: DashboardPermissionSummary(
      isOwner: false,
      role: role,
      canViewMoney: false,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: false,
      canManageMembers: false,
      canManageMoney: false,
      canManagePlan: false,
    ),
  );
}

class _Gateway implements AccountContextsGateway {
  _Gateway({
    required this.persona,
    required this.title,
    required this.canManageTasks,
    required this.canManageGuests,
    required this.canViewMoney,
    this.readerForm,
  });

  final AccountContextPersona persona;
  final String title;

  /// The server's resolved form for this reader (D59), when the test's
  /// reader is known; otherwise the plan's side.
  final String? readerForm;
  bool canManageTasks;
  bool canManageGuests;
  bool canViewMoney;

  void replaceGateway({required bool canViewMoney}) {
    this.canViewMoney = canViewMoney;
  }

  AccountContext get _context {
    final json = accountContextJson(
      role: AccountContextRole.contributor,
      planId: _planId,
      displayName: title,
      persona: persona,
      readerForm: readerForm,
    );
    final permissions = Map<String, dynamic>.from(json['permissions'] as Map)
      ..['canManageTasks'] = canManageTasks
      ..['canManageGuests'] = canManageGuests
      ..['canViewMoney'] = canViewMoney;
    return AccountContext.fromJson({...json, 'permissions': permissions});
  }

  @override
  Future<List<AccountContext>> listContexts() async => [_context];

  @override
  Future<AccountContext> validateContext(String contextKey) async => _context;
}

class _WeddingPlansApi extends WeddingPlansApi {
  _WeddingPlansApi(super.apiClient, this.summary);

  final DashboardSummary summary;
  int moneyRequests = 0;
  int readViewCalls = 0;

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async => summary;

  @override
  Future<PlanReadView> getPlanReadView(String planId) async {
    readViewCalls += 1;
    return _readView();
  }
}

class _TasksApi extends TaskTimelineApi {
  _TasksApi(super.apiClient, List<WeddingTask> tasks) : _tasks = [...tasks];

  final List<WeddingTask> _tasks;
  final List<Map<String, dynamic>> updates = [];
  int listCalls = 0;

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async {
    listCalls += 1;
    return _tasks;
  }

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);

  @override
  Future<WeddingTask> updateTask(String id, Map<String, dynamic> data) async {
    updates.add(data);
    final index = _tasks.indexWhere((task) => task.id == id);
    final updated = WeddingTask(
      id: id,
      weddingPlanId: _planId,
      title: _tasks[index].title,
      status: data['status']?.toString() ?? _tasks[index].status,
      priority: 'MEDIUM',
      dueDate: _tasks[index].dueDate,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 2),
    );
    _tasks[index] = updated;
    return updated;
  }
}

class _AuthRepository extends AuthRepository {
  _AuthRepository(super.apiClient, super.authStorage, this.user);

  final SafeUser user;

  @override
  SafeUser? readCachedUser() => user;

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  Future<SafeUser> me() async => user;
}

class _CollectingLogSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) => events.add(event);
}
