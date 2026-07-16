import 'package:aarast_mobile/features/auth/widgets/auth_wedding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  testWidgets('AuthTextField keeps phone input LTR inside an RTL form', (
    tester,
  ) async {
    final controller = TextEditingController(text: '+967777123456');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AuthTextField(
              controller: controller,
              label: 'رقم الهاتف',
              icon: LucideIcons.phone,
              keyboardType: TextInputType.phone,
            ),
          ),
        ),
      ),
    );

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.textDirection, TextDirection.ltr);
  });

  testWidgets('AuthTextField keeps ordinary Arabic input RTL', (tester) async {
    final controller = TextEditingController(text: 'رشاد');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: AuthTextField(
              controller: controller,
              label: 'الاسم',
              icon: LucideIcons.user,
            ),
          ),
        ),
      ),
    );

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.textDirection, TextDirection.rtl);
  });
}
