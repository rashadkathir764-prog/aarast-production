import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// D75: the number reads in threes as it is typed, and a fix in its middle
// keeps the caret where the finger is.
void main() {
  Future<TextEditingController> pump(WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: JourneyPhoneField(controller: controller)),
        ),
      ),
    );
    return controller;
  }

  testWidgets('a local number reads 777 123 456', (tester) async {
    final controller = await pump(tester);
    await tester.enterText(find.byType(TextField), '777123456');
    expect(controller.text, '777 123 456');
  });

  testWidgets('a digit typed in the middle keeps the caret after it', (
    tester,
  ) async {
    final controller = await pump(tester);
    await tester.enterText(find.byType(TextField), '77712345');
    expect(controller.text, '777 123 45');
    // Type «9» after the fourth digit («7771|2345»).
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '777 1923 45',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();
    expect(controller.text, '777 192 345');
    expect(controller.selection.baseOffset, 6);
  });

  testWidgets('a number with its code is left as typed', (tester) async {
    final controller = await pump(tester);
    await tester.enterText(find.byType(TextField), '+967777123456');
    expect(controller.text, '+967777123456');
  });
}
