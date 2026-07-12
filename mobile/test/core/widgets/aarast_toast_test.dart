import 'package:aarast_mobile/core/widgets/aarast_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Iterable<String?> semanticLabels(WidgetTester tester) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .map((widget) => widget.properties.label);

  testWidgets('AarastToast announces feedback and replaces the current toast', (
    tester,
  ) async {
    const first = 'تعذر حفظ التغيير';
    const second = 'تم الحفظ بنجاح';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => AarastToast.showError(context, first),
                  child: const Text('خطأ'),
                ),
                TextButton(
                  onPressed: () => AarastToast.showSuccess(context, second),
                  child: const Text('نجاح'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('خطأ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(semanticLabels(tester), contains(first));

    await tester.tap(find.text('نجاح'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(semanticLabels(tester), isNot(contains(first)));
    expect(semanticLabels(tester), contains(second));
  });
}
