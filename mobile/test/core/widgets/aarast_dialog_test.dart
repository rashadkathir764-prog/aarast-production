import 'package:aarast_mobile/core/widgets/aarast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AarastDialog stays RTL and actionable on a 320px screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AarastDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text('هل تريد حذف السجل؟'),
            actions: [
              TextButton(onPressed: () {}, child: const Text('إلغاء')),
              FilledButton(
                onPressed: () => confirmed = true,
                child: const Text('حذف'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('تأكيد الحذف'), findsOneWidget);
    expect(find.text('هل تريد حذف السجل؟'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('حذف'));
    expect(confirmed, isTrue);
  });
}
