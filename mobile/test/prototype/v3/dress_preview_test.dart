// Large preview of the dress drawing, to judge it at photo size.
//   flutter test test/prototype/v3/dress_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lights.dart' show Dress;

void main() {
  testWidgets('dress', (t) async {
    t.view.physicalSize = const Size(800, 1000);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(const CustomPaint(painter: Dress(), size: Size(400, 500)));
    await expectLater(find.byType(CustomPaint), matchesGoldenFile('out/dress_preview.png'));
  });
}
