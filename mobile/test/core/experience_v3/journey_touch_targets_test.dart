import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_pressable.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/widgets/task_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

// DESIGN_SYSTEM: touch targets are at least 48. The look stays: a round
// button is still a 44 circle, touched in a 48 square.

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  testWidgets('a round button is a 44 circle touched in 48', (tester) async {
    await _pump(
      tester,
      JourneyRoundButton(
        key: const ValueKey('round'),
        icon: LucideIcons.bell,
        tooltip: 'التنبيهات',
        onPressed: () {},
      ),
    );
    final target = tester.getSize(find.byKey(const ValueKey('round')));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a text action and a small button are 48 tall', (tester) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          JourneyTextAction(
            key: const ValueKey('text'),
            label: 'بعدين',
            onPressed: () {},
          ),
          JourneyButton(
            key: const ValueKey('small'),
            label: 'اتصل',
            onPressed: () {},
          ),
        ],
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('text'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('small'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a task\'s finish circle is touched in 48', (tester) async {
    final task = WeddingTask(
      id: 't1',
      weddingPlanId: 'p1',
      title: 'احجز القاعة',
      status: 'TODO',
      priority: 'MEDIUM',
      createdAt: DateTime(2026, 6, 28),
      updatedAt: DateTime(2026, 6, 28),
    );
    await _pump(tester, TaskRow(task: task, onToggle: () {}, onOpen: () {}));
    final circle = find.byType(AarastPressable).last;
    final size = tester.getSize(circle);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
