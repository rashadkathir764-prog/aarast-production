import 'package:aarast_mobile/core/forms/aarast_form_success.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('success receipt exposes one useful non-dialog next action', (
    tester,
  ) async {
    var nextCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AarastFormSuccess.show(
                context,
                message: 'تم الحفظ.',
                nextLabel: 'إضافة أخرى',
                onNext: () => nextCalls += 1,
              ),
              child: const Text('حفظ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('تم الحفظ.'), findsOneWidget);
    expect(find.text('إضافة أخرى'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.text('إضافة أخرى'));
    await tester.pump();
    expect(nextCalls, 1);
  });
}
