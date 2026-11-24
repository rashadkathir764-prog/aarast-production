import 'dart:math' as math;

import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3_foundations.dart';
import 'package:aarast_mobile/core/theme/aarast_design_tokens.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-367 (D124): the two «فيروز» neutrals that carry meaning are pinned by
// WCAG 2.x relative luminance, not by eye: faint text 4.5:1 (1.4.3) and the
// field stroke 3:1 (1.4.11), each against both surfaces it sits on.

double _channel(double value) => value <= 0.03928
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('the contrast maths matches WCAG\'s own anchors', () {
    expect(_contrast(Colors.black, Colors.white), closeTo(21, 1e-9));
    expect(_contrast(Colors.white, Colors.white), closeTo(1, 1e-9));
  });

  test('faint text reads at 4.5:1 on the canvas and on paper', () {
    expect(
      _contrast(AarastV3Color.textFaint, AarastV3Color.canvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AarastV3Color.textFaint, AarastV3Color.paper),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('faint text stays a step lighter than muted text', () {
    expect(
      _luminance(AarastV3Color.textFaint),
      greaterThan(_luminance(AarastV3Color.textMuted)),
    );
  });

  test('the field stroke is 3:1 against both paper and the canvas', () {
    expect(
      _contrast(AarastV3Color.lineStrong, AarastV3Color.paper),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrast(AarastV3Color.lineStrong, AarastV3Color.canvas),
      greaterThanOrEqualTo(3),
    );
  });

  test('the theme draws every field at rest with that stroke', () {
    final decoration = AppTheme.light().inputDecorationTheme;
    for (final border in [decoration.border, decoration.enabledBorder]) {
      final side = (border! as OutlineInputBorder).borderSide;
      expect(side.color, AarastV3Color.lineStrong);
      expect(side.width, greaterThanOrEqualTo(1));
    }
  });

  testWidgets('the app\'s own field box rests on that stroke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: JourneyFieldBox(child: Text('حقل'))),
      ),
    );

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(JourneyFieldBox),
        matching: find.byType(Container),
      ),
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AarastV3Color.lineStrong);
  });

  test('the semantic roles follow the pinned tokens', () {
    expect(AarastSemanticTokens.textDisabled, AarastV3Color.textFaint);
    expect(AarastSemanticTokens.borderStrong, AarastV3Color.lineStrong);
  });
}
