import 'package:aarast_mobile/core/widgets/aarast_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showAarastBottomSheet is RTL safe and returns its result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    bool? result;
    var sawRtl = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAarastBottomSheet<bool>(
                  context: context,
                  builder: (sheetContext) {
                    sawRtl =
                        Directionality.of(sheetContext) == TextDirection.rtl;
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('تأكيد'),
                        ),
                      ),
                    );
                  },
                );
              },
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    expect(sawRtl, isTrue);
    expect(find.text('تأكيد'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
