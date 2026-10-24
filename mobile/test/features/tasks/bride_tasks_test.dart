import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_checklist_section.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_postpone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The bride's tasks (bride_profile/out d01, d04, x16): the groom's tasks
// in her rose and her feminine address, from the plan's one profile.

Future<void> _pump(
  WidgetTester tester,
  JourneyProfile profile,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(384, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: JourneyProfileScope(
        profile: profile,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _task = WeddingTask(
  id: 't1',
  weddingPlanId: 'plan-1',
  title: 'حجز الكوافير',
  status: 'TODO',
  priority: 'MEDIUM',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

Widget _checklist() => TaskChecklistSection(
  items: const [],
  saving: false,
  onAdd: (_) async => true,
  onToggle: (_, _) {},
  onRename: (_, _) {},
  onRemove: (_) {},
);

void main() {
  testWidgets('her postpone sheet asks her, and its picker is rose', (
    tester,
  ) async {
    await _pump(tester, JourneyProfile.bride, TaskPostponeSheet(task: _task));

    expect(find.text('لمتى تأجلينها؟'), findsOneWidget);
    expect(find.text('اختاري يوم'), findsOneWidget);
    final pick = tester.widget<JourneyListRow>(
      find.byKey(const ValueKey('task-postpone-pick')),
    );
    expect(pick.color, AarastV3Color.rose);
  });

  testWidgets('her steps invite her to add and split', (tester) async {
    await _pump(tester, JourneyProfile.bride, _checklist());

    expect(find.text('أضيفي خطوة'), findsOneWidget);
    expect(
      find.text('قسّميها على خطوات صغيرة تخلصينها وحدة وحدة.'),
      findsOneWidget,
    );
  });

  testWidgets('the groom keeps his words and his teal', (tester) async {
    await _pump(tester, JourneyProfile.groom, TaskPostponeSheet(task: _task));

    expect(find.text('لمتى تأجلها؟'), findsOneWidget);
    final pick = tester.widget<JourneyListRow>(
      find.byKey(const ValueKey('task-postpone-pick')),
    );
    expect(pick.color, AarastV3Color.primary);
  });
}
