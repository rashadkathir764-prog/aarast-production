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
