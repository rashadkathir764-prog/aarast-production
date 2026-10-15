import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.13: how many days the wedding moved, for moving the tasks.

void main() {
  test('a later or earlier wedding reads as whole days', () {
    expect(
      weddingDateShiftDays(DateTime(2027, 3, 1), DateTime(2027, 3, 31)),
      30,
    );
    expect(
      weddingDateShiftDays(DateTime(2027, 3, 31), DateTime(2027, 3, 21)),
      -10,
    );
  });

  test('the time of day and daylight changes do not count', () {
    expect(
      weddingDateShiftDays(
        DateTime(2027, 3, 1, 23, 30),
        DateTime(2027, 3, 2, 0, 15),
      ),
      1,
    );
  });

  test('no move when a date is missing or the day is the same', () {
    expect(weddingDateShiftDays(null, DateTime(2027, 3, 1)), isNull);
    expect(weddingDateShiftDays(DateTime(2027, 3, 1), null), isNull);
    expect(
      weddingDateShiftDays(DateTime(2027, 3, 1, 8), DateTime(2027, 3, 1, 20)),
      isNull,
    );
  });
}
