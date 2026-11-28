import 'package:aarast_mobile/core/utils/arabic_count.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('days follow the six Arabic count forms', () {
    expect(arabicDays(0), '0 يوم');
    expect(arabicDays(1), 'يوم واحد');
    expect(arabicDays(2), 'يومين');
    expect(arabicDays(3), '3 أيام');
    expect(arabicDays(7), '7 أيام');
    expect(arabicDays(10), '10 أيام');
    expect(arabicDays(11), '11 يومًا');
    expect(arabicDays(60), '60 يومًا');
    expect(arabicDays(99), '99 يومًا');
    expect(arabicDays(100), '100 يوم');
    expect(arabicDays(102), '102 يوم');
    expect(arabicDays(103), '103 أيام');
    expect(arabicDays(111), '111 يومًا');
    expect(arabicDays(200), '200 يوم');
  });

  test('the counted word alone, for a screen that draws the number', () {
    // b01's countdown draws the days in 52 point beside their word, so it
    // needs the word without the number — by the same rule as arabicCount.
    String day(int n) => arabicCountWord(
      n,
      one: 'يوم واحد',
      two: 'يومان',
      few: 'أيام',
      many: 'يومًا',
      other: 'يوم',
    );
    expect(day(1), 'يوم واحد');
    expect(day(2), 'يومان');
    expect(day(3), 'أيام');
    expect(day(10), 'أيام');
    expect(day(11), 'يومًا');
    expect(day(60), 'يومًا');
    expect(day(100), 'يوم');
    expect(day(103), 'أيام');
    expect(day(111), 'يومًا');
    // Never «0 أيام».
    expect(day(0), 'يوم');
  });

  test('a caller that passes one word for many and other keeps it', () {
    String day(int n) => arabicCountWord(
      n,
      one: 'يوم واحد',
      two: 'يومين',
      few: 'أيام',
      many: 'يومًا',
    );
    expect(day(11), 'يومًا');
    expect(day(100), 'يومًا');
    expect(day(0), 'يومًا');
  });

  // D134 (2026-11-27): the approved home stays, and its countdown with it.
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
    // b01/b02's hero and the wedding week's hero each wrote their own
    // wording; the week one said «4 يوم على عرسك» while the greeting above it
    // said «باقي 4 أيام». They share homeCountdownWords now.
    for (final days in [3, 4, 7, 10, 103]) {
      expect(
        homeCountdownWords(days).drawn,
        'أيام على عرسك',
        reason: 'days=$days',
      );
    }
    // D136: the drawn word is the spoken one's («55 يومًا على عرسك»); the
    // hero drew «55 يوم» over a card that said «بعد 48 يومًا».
    for (final days in [11, 60, 111]) {
      expect(
        homeCountdownWords(days).drawn,
        'يومًا على عرسك',
        reason: 'days=$days',
      );
      expect(homeCountdownWords(days).spoken, '$days يومًا على عرسك');
    }
    expect(homeCountdownWords(100).drawn, 'يوم على عرسك');
    expect(homeCountdownWords(2).drawn, 'يومين على عرسك');
    expect(homeCountdownWords(1).drawn, 'يوم واحد على عرسك');
  });

  test('any counted word', () {
    String items(int n) => arabicCount(
      n,
      one: 'بند واحد',
      two: 'بندان',
      few: 'بنود',
      many: 'بندًا',
      other: 'بند',
    );
    expect(items(1), 'بند واحد');
    expect(items(2), 'بندان');
    expect(items(5), '5 بنود');
    expect(items(11), '11 بندًا');
    expect(items(100), '100 بند');
    expect(items(0), '0 بند');
    expect(
      arabicCount(
        0,
        zero: 'لا بنود بعد',
        one: 'بند واحد',
        two: 'بندان',
        few: 'بنود',
        many: 'بندًا',
      ),
      'لا بنود بعد',
    );
  });
}
