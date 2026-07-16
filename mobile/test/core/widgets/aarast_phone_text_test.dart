import 'package:aarast_mobile/core/widgets/aarast_phone_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formats and keeps the phone LTR inside a narrow RTL surface', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: Align(
                alignment: AlignmentDirectional.topStart,
                child: AarastPhoneText(phone: '+967777758200'),
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('+967 777 758 200'));
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.right);
    expect(
      tester.getSemantics(find.text('+967 777 758 200')).label,
      '+967 777 758 200',
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
