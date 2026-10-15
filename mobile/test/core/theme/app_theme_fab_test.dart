import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Field test Q10: the theme's circular FAB shape clipped the extended
// "إضافة مصدر" button on the funding screen down to "إضافة م".

void main() {
  testWidgets('an extended FAB keeps its whole label inside its shape', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('إضافة مصدر'),
          ),
        ),
      ),
    );

    final shape = tester
        .widget<RawMaterialButton>(find.byType(RawMaterialButton))
        .shape;
    expect(shape, isA<StadiumBorder>());

    final button = tester.getRect(find.byType(FloatingActionButton));
    final label = tester.getRect(find.text('إضافة مصدر'));
    expect(button.width, greaterThan(button.height));
    expect(button.contains(label.centerLeft), isTrue);
    expect(button.contains(label.centerRight), isTrue);
  });
}
