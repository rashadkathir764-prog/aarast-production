import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/contributor_permissions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F04: with every right listed, a short screen and large text, each right
// and the close action must stay reachable.
void main() {
  testWidgets('every right and the close action stay reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const labels = [
      'عرض الخطة والتحديثات',
      'إدارة المهام',
      'إدارة المال',
      'إدارة الضيوف',
      'إدارة الموردين والعروض',
      'إدارة المشاركين',
      'تعديل بيانات الخطة',
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showContributorPermissionsSheet(context, labels: labels),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final label in labels) {
      await tester.ensureVisible(find.text(label));
    }
    final close = find.widgetWithText(FilledButton, 'تم');
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(find.text('صلاحياتك في هذه الخطة'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
