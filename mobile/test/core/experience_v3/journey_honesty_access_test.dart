import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/forms/aarast_form_draft_store.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/widgets/auth_wedding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

// RA-MO-27: what the review of the old branch's fixes (section 1.2) proved
// still wrong on main: a white letter on saffron, a made-up letter for a
// person without a name, a field whose label does not open the keyboard,
// a hint drawn like a typed value, a draft line that read as «no need to
// save», and a 40-point password eye.

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AarastV3Space.x4),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('an avatar letter takes the colour that reads on its fill', () {
    expect(JourneyAvatar.onFill(AarastV3Color.saffron), AarastV3Color.ink);
    expect(JourneyAvatar.onFill(AarastV3Color.ink), AarastV3Color.onPrimary);
    expect(
      JourneyAvatar.onFill(AarastV3Color.danger),
      AarastV3Color.onPrimary,
    );
  });

  testWidgets('a person without a name shows a person, not a letter', (
    tester,
  ) async {
    await _pump(
      tester,
      const Row(
        children: [
          JourneyAvatar(
            key: ValueKey('named'),
            letter: 'م',
            color: AarastV3Color.saffron,
          ),
          JourneyAvatar(
            key: ValueKey('unnamed'),
            letter: '',
            color: AarastV3Color.saffron,
          ),
        ],
      ),
    );
    final letter = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('named')),
        matching: find.text('م'),
      ),
    );
    expect(letter.style?.color, AarastV3Color.ink);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('unnamed')),
        matching: find.byIcon(LucideIcons.user),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('unnamed')),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('the whole field opens the keyboard; its hint is not bold', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      JourneyTextField(label: 'اسمك', hint: 'محمد', controller: controller),
    );
    EditableText editable() =>
        tester.widget<EditableText>(find.byType(EditableText));
    expect(editable().focusNode.hasFocus, isFalse);

    await tester.tap(find.text('اسمك'));
    await tester.pump();
    expect(editable().focusNode.hasFocus, isTrue);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintStyle?.fontWeight, isNot(FontWeight.w700));
    expect(field.decoration?.hintStyle?.fontWeight, isNot(FontWeight.w800));
  });

  testWidgets('the draft line speaks of a draft on the phone', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          AarastV3DraftStatusLine(status: AarastFormDraftStatus.idle),
          AarastV3DraftStatusLine(status: AarastFormDraftStatus.saved),
          AarastV3DraftStatusLine(status: AarastFormDraftStatus.failed),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('نحفظ المسودة على جوالك وأنت تكتب'), findsOneWidget);
    expect(find.text('المسودة محفوظة على جوالك'), findsOneWidget);
    expect(find.text('ما قدرنا نحفظ المسودة على جوالك'), findsOneWidget);
    expect(find.textContaining('تلقائيًا'), findsNothing);
    final failure = tester.widget<Icon>(find.byIcon(LucideIcons.alertCircle));
    expect(failure.color, AarastV3Color.danger);
  });

  testWidgets('the password eye is a 48 target', (tester) async {
    await _pump(
      tester,
      Center(
        child: AuthObscureToggle(
          key: const ValueKey('eye'),
          obscured: true,
          onPressed: () {},
        ),
      ),
    );
    final size = tester.getSize(find.byKey(const ValueKey('eye')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
