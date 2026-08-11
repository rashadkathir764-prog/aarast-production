import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/brand/aarast_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand mark exposes one Arabic image label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: AarastBrandMark())),
      ),
    );

    final data = tester.getSemantics(find.byType(AarastBrandMark));
    expect(data.label, AarastBrandMark.semanticsLabel);
    expect(find.text('اعّرست'), findsOneWidget);
    expect(find.text('كل ما يخص الزفاف في مكان واحد'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
