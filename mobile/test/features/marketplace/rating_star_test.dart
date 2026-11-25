import 'package:aarast_mobile/features/marketplace/widgets/rating_star.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// UX critique: a given star and an empty one differed by colour only, which
// a reader who does not tell the colours apart cannot read. An empty star
// is an outline, a given one is filled.
void main() {
  testWidgets('a given star is filled, an empty one is an outline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            RatingStar(key: ValueKey('given'), filled: true, size: 16),
            RatingStar(key: ValueKey('empty'), filled: false, size: 16),
          ],
        ),
      ),
    );

    PaintingStyle style(String key) {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(CustomPaint),
        ),
      );
      return (paint.painter! as RatingStarPainter).style;
    }

    expect(style('given'), PaintingStyle.fill);
    expect(style('empty'), PaintingStyle.stroke);
  });
}
