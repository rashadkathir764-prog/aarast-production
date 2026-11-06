import 'package:aarast_mobile/core/utils/arabic_count.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('days follow the Arabic count', () {
    expect(arabicDays(1), 'يوم واحد');
    expect(arabicDays(2), 'يومين');
    expect(arabicDays(3), '3 أيام');
    expect(arabicDays(7), '7 أيام');
    expect(arabicDays(10), '10 أيام');
    expect(arabicDays(11), '11 يوم');
    expect(arabicDays(60), '60 يوم');
    expect(arabicDays(100), '100 يوم');
    expect(arabicDays(103), '103 أيام');
    expect(arabicDays(111), '111 يوم');
  });

  test('the counted word alone, for a screen that draws the number', () {
    // b01's countdown draws the days in 52 point beside their word, so it
    // needs the word without the number — by the same rule as arabicCount.
    String day(int n) => arabicCountWord(
      n,
      one: 'يوم واحد',
      two: 'يومين',
      few: 'أيام',
      many: 'يوم',
    );
    expect(day(1), 'يوم واحد');
    expect(day(2), 'يومين');
    expect(day(3), 'أيام');
    expect(day(10), 'أيام');
    expect(day(11), 'يوم');
    expect(day(60), 'يوم');
    expect(day(103), 'أيام');
    expect(day(111), 'يوم');
    expect(day(0), 'أيام');
  });

  test('the countdown says the day count both ways', () {
    expect(homeCountdownWords(5).drawn, 'أيام على عرسك');
    expect(homeCountdownWords(5).spoken, '5 أيام على عرسك');
    expect(homeCountdownWords(1).drawn, 'يوم واحد على عرسك');
    expect(homeCountdownWords(1).spoken, 'يوم واحد على عرسك');
    expect(homeCountdownWords(0).drawn, 'اليوم عرسك');
    // b07: the header congratulates by name, so the box states the day.
    expect(homeCountdownWords(-3).drawn, 'عرسك كان');
    expect(homeCountdownWords(null).drawn, '');
  });

  test('both countdowns read a count the same way', () {
    // b01/b02's hero and b04's wedding-week hero each wrote their own
    // wording; the week one said «4 يوم على عرسك» while the greeting above it
    // said «باقي 4 أيام». They share homeCountdownWords now.
    for (final days in [3, 4, 7, 10, 103]) {
      expect(
        homeCountdownWords(days).drawn,
        'أيام على عرسك',
        reason: 'days=$days',
      );
    }
    for (final days in [11, 60, 111]) {
      expect(
        homeCountdownWords(days).drawn,
        'يوم على عرسك',
        reason: 'days=$days',
      );
    }
    expect(homeCountdownWords(2).drawn, 'يومين على عرسك');
    expect(homeCountdownWords(1).drawn, 'يوم واحد على عرسك');
  });

  test('any counted word', () {
    String items(int n) =>
        arabicCount(n, one: 'بند واحد', two: 'بندين', few: 'بنود', many: 'بند');
    expect(items(1), 'بند واحد');
    expect(items(2), 'بندين');
    expect(items(5), '5 بنود');
    expect(items(11), '11 بند');
    expect(items(0), '0 بنود');
  });
}
