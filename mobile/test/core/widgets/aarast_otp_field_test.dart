import 'package:aarast_mobile/core/widgets/aarast_otp_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {double textScale = 1}) {
  return MaterialApp(
    builder: (context, materialChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: materialChild!,
    ),
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('pasting a full code fills the boxes and fires onCompleted', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? completed;
    final hapticTypes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          hapticTypes.add(call.arguments?.toString() ?? '');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      _wrap(
        AarastOtpField(
          controller: controller,
          fieldKey: const Key('test-otp-field'),
          onCompleted: (code) => completed = code,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('test-otp-field')), '123456');
    await tester.pumpAndSettle();

    expect(completed, '123456');
    expect(hapticTypes, contains('HapticFeedbackType.selectionClick'));
    for (final digit in const ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digit), findsOneWidget);
    }
  });

  testWidgets('non-digit input is rejected by the field', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        AarastOtpField(
          controller: controller,
          fieldKey: const Key('test-otp-field'),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('test-otp-field')), 'ab12');
    await tester.pumpAndSettle();

    expect(controller.text, '12');
  });

  testWidgets('error state shakes then auto-clears the code for retry', (
    tester,
  ) async {
    final controller = TextEditingController(text: '999999');
    addTearDown(controller.dispose);
    var state = AarastOtpFieldState.idle;
    late StateSetter rebuild;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return AarastOtpField(
              controller: controller,
              state: state,
              fieldKey: const Key('test-otp-field'),
            );
          },
        ),
      ),
    );

    rebuild(() => state = AarastOtpFieldState.error);
    await tester.pump();
    expect(controller.text, '999999');

    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
  });

  testWidgets('success state disables further input', (tester) async {
    final controller = TextEditingController(text: '123456');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        AarastOtpField(
          controller: controller,
          state: AarastOtpFieldState.success,
          fieldKey: const Key('test-otp-field'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('test-otp-field')),
    );
    expect(field.enabled, isFalse);
  });

  testWidgets('success panel renders unified title, subtitle, and badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AarastOtpSuccessPanel(subtitle: 'تم التحقق من الرمز.')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp-success-panel')), findsOneWidget);
    expect(find.text('تم التحقق بنجاح'), findsOneWidget);
    expect(find.text('تم التحقق من الرمز.'), findsOneWidget);
  });

  testWidgets('successHold is zero when animations are disabled', (
    tester,
  ) async {
    late Duration reduced;
    late Duration normal;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = AarastOtpField.successHold(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            normal = AarastOtpField.successHold(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(reduced, Duration.zero);
    expect(normal.inMilliseconds, greaterThan(0));
  });

  testWidgets('field remains overflow-free at 320px and 1.3 text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '123456');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(AarastOtpField(controller: controller), textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final digit in const ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digit), findsOneWidget);
    }
  });
}
