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

  test('a search finds the name whichever way it was spelled', () {
    // This is what a guest search does: match on the key, not letter for
    // letter. «احمد» used to find no «أحمد» in a list of hundreds.
    bool finds(String saved, String typed) =>
        arabicSortKey(saved).contains(arabicSortKey(typed));
    expect(finds('أحمد', 'احمد'), isTrue);
    expect(finds('احمد', 'أحمد'), isTrue);
    expect(finds('عبد الله', 'عبدالله'), isTrue);
    expect(finds('عبدالله', 'عبد الله'), isTrue);
    expect(finds('فاطمة', 'فاطمه'), isTrue);
    expect(finds('مُحَمَّد', 'محمد'), isTrue);
    expect(finds('أحمد المقطري', 'المقطري'), isTrue);
    // A different name is still a different name.
    expect(finds('أحمد', 'محمد'), isFalse);
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
