import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AarastPageScaffold renders premium shell at small width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AarastPageScaffold(
          title: 'أعرست',
          subtitle: 'نظام تصميم موحد',
          child: Center(child: Text('محتوى الشاشة')),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('أعرست'), findsOneWidget);
    expect(find.text('نظام تصميم موحد'), findsOneWidget);
    expect(find.text('محتوى الشاشة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AarastScaffold and loading state share the premium surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AarastScaffold(
          child: AarastScreenLoading(label: 'Loading'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AarastScreenFrame supports flexible production screen bodies', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AarastScreenFrame(
          maxWidth: 420,
          child: ListView(children: const [Text('شاشة إنتاجية')]),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('شاشة إنتاجية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
