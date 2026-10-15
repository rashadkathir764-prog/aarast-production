import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Field test Q04: after the governorate sheet or the date picker closed, the
// plan title field took focus back and the keyboard reopened, so the next tap
// typed into the title.

void main() {
  Future<FocusNode> pumpFieldWithSheetOpener(WidgetTester tester) async {
    final titleFocus = FocusNode();
    addTearDown(titleFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(key: const Key('title'), focusNode: titleFocus),
                TextButton(
                  key: const Key('open-sheet'),
                  onPressed: () => showAarastBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => TextButton(
                      key: const Key('pick'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('صنعاء'),
                    ),
                  ),
                  child: const Text('المحافظة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return titleFocus;
  }

  testWidgets('closing an Aarast sheet does not refocus the edited field', (
    tester,
  ) async {
    final titleFocus = await pumpFieldWithSheetOpener(tester);
    await tester.tap(find.byKey(const Key('title')));
    await tester.pump();
    expect(titleFocus.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('open-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick')));
    await tester.pumpAndSettle();

    expect(titleFocus.hasFocus, isFalse);
  });

  testWidgets('a released field stays released after a dialog closes', (
    tester,
  ) async {
    final titleFocus = FocusNode();
    addTearDown(titleFocus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(key: const Key('title'), focusNode: titleFocus),
                TextButton(
                  key: const Key('open-dialog'),
                  onPressed: () {
                    releaseFieldFocus();
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => TextButton(
                        key: const Key('close'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('تم'),
                      ),
                    );
                  },
                  child: const Text('التاريخ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('title')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close')));
    await tester.pumpAndSettle();

    expect(titleFocus.hasFocus, isFalse);
  });
}
