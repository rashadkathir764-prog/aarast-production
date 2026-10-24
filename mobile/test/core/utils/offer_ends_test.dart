import 'package:aarast_mobile/core/utils/offer_ends.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 24, 15, 30);

  test('counts calendar days, not whole 24-hour spans', () {
    // Six days ahead at an earlier hour is still the sixth day.
    expect(offerEndsLabel(DateTime(2026, 10, 30, 9), now), 'ينتهي بعد 6 أيام');
    expect(offerEndsLabel(DateTime(2026, 10, 30, 23), now), 'ينتهي بعد 6 أيام');
  });

  test('says one and two days the Arabic way', () {
    expect(
      offerEndsLabel(DateTime(2026, 10, 25, 8), now),
      'ينتهي بعد يوم واحد',
    );
    expect(offerEndsLabel(DateTime(2026, 10, 26, 8), now), 'ينتهي بعد يومين');
    expect(offerEndsLabel(DateTime(2026, 11, 4, 8), now), 'ينتهي بعد 11 يوم');
  });

  test('the last day reads today, and an ended offer has no line', () {
    expect(offerEndsLabel(DateTime(2026, 10, 24, 22), now), 'ينتهي اليوم');
    expect(offerEndsLabel(DateTime(2026, 10, 24, 15), now), isNull);
    expect(offerEndsLabel(now, now), isNull);
  });
}
