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

  test('the first deadline still ahead is said, past ones do not hide it', () {
    final now = DateTime(2026, 11, 23, 12);
    // An expired offer sorted first used to blank the tag on the requests
    // hero and the home's waiting card.
    expect(
      firstOfferEndsLabel([
        DateTime(2026, 11, 20),
        null,
        DateTime(2026, 11, 29, 9),
        DateTime(2026, 12, 2),
      ], now),
      'ينتهي بعد 6 أيام',
    );
    expect(firstOfferEndsLabel([DateTime(2026, 11, 1), null], now), isNull);
    expect(firstOfferEndsLabel(const [], now), isNull);
  });
}
