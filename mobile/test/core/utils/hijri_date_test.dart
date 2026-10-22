import 'package:aarast_mobile/core/utils/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts on the Umm al-Qura calendar', () {
    expect(
      HijriDate.fromGregorian(DateTime(2027, 1, 21))!.dayAndMonth,
      '13 شعبان',
    );
    expect(
      HijriDate.fromGregorian(DateTime(2027, 4, 15))!.dayAndMonth,
      '8 ذو القعدة',
    );
    expect(
      HijriDate.fromGregorian(DateTime(2026, 9, 10))!.dayAndMonth,
      '28 ربيع الأول',
    );
    expect(HijriDate.fromGregorian(DateTime(2027, 2, 8))!.full, '1 رمضان 1448');
  });

  test('finds the Ramadan of a wedding date', () {
    final (start, end) = HijriDate.ramadanOnOrAfter(DateTime(2027, 1, 21))!;
    expect(start, DateTime.utc(2027, 2, 8));
    expect(end, DateTime.utc(2027, 3, 9));
    final inside = HijriDate.ramadanOnOrAfter(DateTime(2027, 2, 20))!;
    expect(inside.$1, DateTime.utc(2027, 2, 8));
  });

  test('returns null outside the table', () {
    expect(HijriDate.fromGregorian(DateTime(2020, 1, 1)), isNull);
    expect(HijriDate.fromGregorian(DateTime(2035, 1, 1)), isNull);
  });
}
