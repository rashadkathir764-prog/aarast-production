import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the field keeps phone input LTR inside an RTL form', (
    tester,
  ) async {
    final controller = TextEditingController(text: '+967777123456');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: JourneyTextField(
              controller: controller,
              label: 'رقم الهاتف',
              keyboardType: TextInputType.phone,
            ),
          ),
        ),
      ),
    );

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.textDirection, TextDirection.ltr);
  });

  testWidgets('the field keeps ordinary Arabic input RTL', (tester) async {
    final controller = TextEditingController(text: 'رشاد');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: JourneyTextField(controller: controller, label: 'الاسم'),
          ),
        ),
      ),
    );

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.textDirection, TextDirection.rtl);
  });
}
