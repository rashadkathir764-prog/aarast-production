/// Ordering Arabic names the way a reader expects to find them.
///
/// `String.compareTo` orders by UTF-16 code unit, and the alef forms sit on
/// four different ones (آ 0622, أ 0623, إ 0625, ا 0627). So a plain sort
/// pulls the same letter apart, and the same name spelled two ways lands
/// far from itself:
///
///     ['آدم', 'أحمد', 'أمل', 'إبراهيم', 'ابتسام', 'احمد', 'بدر']
///
/// «أحمد» and «احمد» are one name with three others wedged between them —
/// and both spellings are everyday in a Yemeni guest list, as are
/// «عبدالله» and «عبد الله».
///
/// [arabicSortKey] folds the forms that are spelling, not letters, so a
/// name sorts by the letters a reader sees.
String arabicSortKey(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().runes) {
    switch (rune) {
      // The alef forms, including the one with a hamza below.
      case 0x0622 || 0x0623 || 0x0625 || 0x0671:
        buffer.writeCharCode(0x0627);
      // Alef maqsura reads as yaa at the end of a name.
      case 0x0649:
        buffer.writeCharCode(0x064A);
      // Taa marbuta reads as haa.
      case 0x0629:
        buffer.writeCharCode(0x0647);
      // Harakat, tatweel and the tanween marks are not letters.
      case >= 0x064B && <= 0x0652:
      case 0x0640:
      case 0x0670:
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  // Spaces inside a name are a spelling choice too («عبد الله»).
  return buffer.toString().replaceAll(' ', '');
}

/// Compares two Arabic names by [arabicSortKey], falling back to the names
/// themselves so two spellings of one name keep a stable order.
int compareArabicNames(String a, String b) {
  final byKey = arabicSortKey(a).compareTo(arabicSortKey(b));
  return byKey != 0 ? byKey : a.compareTo(b);
}
