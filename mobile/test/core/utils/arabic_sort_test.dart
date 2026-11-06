import 'package:aarast_mobile/core/utils/arabic_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one name keeps its two spellings together', () {
    // A plain compareTo gave:
    //   آدم، أحمد، أمل، إبراهيم، ابتسام، احمد، بدر
    // with «أحمد» and «احمد» three names apart, and «إبراهيم» after «أمل».
    final names = [
      'أحمد',
      'احمد',
      'إبراهيم',
      'آدم',
      'بدر',
      'عبدالله',
      'عمر',
      'ابتسام',
      'أمل',
    ]..sort(compareArabicNames);
    // The two spellings are now neighbours; which of them comes first is
    // only the tie-break (أ 0623 before ا 0627), and it is stable.
    expect(names, [
      'ابتسام',
      'إبراهيم',
      'أحمد',
      'احمد',
      'آدم',
      'أمل',
      'بدر',
      'عبدالله',
      'عمر',
    ]);
  });

  test('a space inside a name is spelling, not order', () {
    expect(arabicSortKey('عبد الله'), arabicSortKey('عبدالله'));
  });

  test('taa marbuta, alef maqsura and harakat do not move a name', () {
    expect(arabicSortKey('فاطمة'), arabicSortKey('فاطمه'));
    expect(arabicSortKey('يحيى'), arabicSortKey('يحيي'));
    expect(arabicSortKey('مُحَمَّد'), arabicSortKey('محمد'));
    expect(arabicSortKey('محمـــد'), arabicSortKey('محمد'));
  });

  test('two spellings keep a stable order instead of swapping', () {
    expect(compareArabicNames('أحمد', 'احمد'), isNot(0));
    expect(
      compareArabicNames('أحمد', 'احمد').sign,
      -compareArabicNames('احمد', 'أحمد').sign,
    );
  });
}
