import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/brand/aarast_premium_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('premium brand mark is accessible and narrow-screen safe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: AarastPremiumBrandMark())),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('اعّرست'), findsOneWidget);
    expect(find.text('كل ما يخص الزفاف في مكان واحد'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(AarastPremiumBrandMark)).label,
      AarastPremiumBrandMark.semanticsLabel,
    );
  });
}
