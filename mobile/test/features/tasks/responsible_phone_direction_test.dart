import 'package:aarast_mobile/features/tasks/widgets/create_task_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'phone-only responsible stays LTR in both manual task fields at 320px',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);

      final nameController = TextEditingController(text: '+967 777 123 456');
      final phoneController = TextEditingController(text: '+967777123456');
      addTearDown(nameController.dispose);
      addTearDown(phoneController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: CreateTaskResponsibleSection(
                    choices: const [('me', 'أنا')],
                    selected: createTaskOtherPerson,
                    onSelected: (_) {},
                    otherNameController: nameController,
                    otherPhoneController: phoneController,
                    onDraftChanged: (_) {},
                    canInvite: false,
                    onInvite: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_editableTextDirection(tester, nameController), TextDirection.ltr);
      expect(
        _editableTextDirection(tester, phoneController),
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

TextDirection? _editableTextDirection(
  WidgetTester tester,
  TextEditingController controller,
) {
  final editableText = find.byWidgetPredicate(
    (widget) =>
        widget is EditableText && identical(widget.controller, controller),
  );
  return tester.widget<EditableText>(editableText).textDirection;
}
