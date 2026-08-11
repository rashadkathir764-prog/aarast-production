import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Iterable<String?> semanticLabels(WidgetTester tester) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .map((widget) => widget.properties.label);

  testWidgets('feedback is compact at the top, replaces itself, and expires', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const first = 'تعذر حفظ التغيير';
    const second = 'تم الحفظ بنجاح';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => AarastToast.showError(context, first),
                  child: const Text('خطأ'),
                ),
                TextButton(
                  onPressed: () => AarastToast.showSuccess(context, second),
                  child: const Text('نجاح'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('خطأ'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(semanticLabels(tester), contains(first));
    final firstRect = tester.getRect(find.byKey(const Key('aarast-top-toast')));
    expect(firstRect.top, lessThan(40));
    expect(firstRect.height, lessThan(90));
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('نجاح'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(semanticLabels(tester), isNot(contains(first)));
    expect(semanticLabels(tester), contains(second));

    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.byKey(const Key('aarast-top-toast')), findsNothing);
  });

  testWidgets('compact top feedback keeps its optional action at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var actionCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AarastToast.showSuccess(
                context,
                'تمت إضافة المهمة.',
                action: SnackBarAction(
                  label: 'إضافة أخرى',
                  onPressed: () => actionCalls += 1,
                ),
              ),
              child: const Text('حفظ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('حفظ'));
    await tester.pump(const Duration(milliseconds: 220));

    final rect = tester.getRect(find.byKey(const Key('aarast-top-toast')));
    expect(rect.top, lessThan(40));
    expect(rect.height, lessThan(130));
    expect(find.text('إضافة أخرى'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('إضافة أخرى'));
    await tester.pump(const Duration(milliseconds: 180));
    expect(actionCalls, 1);
    expect(find.byKey(const Key('aarast-top-toast')), findsNothing);
  });

  testWidgets('foreground push uses a titled top notification', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AarastToast.showNotification(
                context,
                title: 'أعرست',
                message: 'لديك تحديث جديد في الخطة.',
              ),
              child: const Text('إشعار'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('إشعار'));
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('أعرست'), findsOneWidget);
    expect(find.text('لديك تحديث جديد في الخطة.'), findsOneWidget);
    expect(find.byKey(const Key('aarast-top-toast')), findsOneWidget);
  });
}
