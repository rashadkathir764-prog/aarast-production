import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter_test/flutter_test.dart';

/// RA-MO-361: every button a screen reader reaches can be pressed. A node
/// that says «زر» without a tap of its own is double-tapped into nothing, or
/// into the button around it. A button that says it is off is let be.
void expectEveryButtonActs() {
  final dead = find.semantics.byPredicate((node) {
    final data = node.getSemanticsData();
    return data.flagsCollection.isButton &&
        data.flagsCollection.isEnabled != Tristate.isFalse &&
        !data.hasAction(SemanticsAction.tap);
  });
  expect(
    [for (final node in dead.evaluate()) '«${node.label}» at ${node.rect}'],
    isEmpty,
    reason: 'buttons a screen reader cannot press',
  );
}

/// RA-MO-361: the control drawn at [control] is a node of its own that a
/// screen reader reads as [label] (or, for an icon, its [tooltip]) and
/// presses with its own tap. A control hidden in its row's one label reads
/// as the row, and its double tap is the row's.
Future<void> pressSpoken(
  WidgetTester tester,
  Finder control, {
  String? label,
  String? tooltip,
}) async {
  final node = tester.getSemantics(control);
  if (label != null) expect(node.label, label);
  if (tooltip != null) expect(node.tooltip, tooltip);
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: '«${node.label}» has no tap of its own',
  );
  tester.semantics.tap(find.semantics.byPredicate((each) => each == node));
  await tester.pumpAndSettle();
}
