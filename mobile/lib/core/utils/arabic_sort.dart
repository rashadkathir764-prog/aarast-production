/// Ordering and finding Arabic names the way a reader expects.
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
/// One folding serves both keys: the forms that are spelling, not letters,
/// read as the letter. On top of it, [arabicSearchKey] ignores every space
/// (a search for «عبدالله» finds «عبد الله»), while [arabicSortKey] keeps the
/// words apart, so «أمل» sorts after «أم علي» and «أم محمد» rather than
/// between them (RA-MO-17), and joins only the compound «عبد …».
String arabicFold(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().runes) {
    switch (rune) {
      // The alef forms, including the one with a hamza below and wasla.
      case 0x0622 || 0x0623 || 0x0625 || 0x0671:
        buffer.writeCharCode(0x0627);
      // Alef maqsura reads as yaa at the end of a name.
      case 0x0649:
        buffer.writeCharCode(0x064A);
      // Taa marbuta reads as haa.
      case 0x0629:
        buffer.writeCharCode(0x0647);
      // The hamza seats on waw and yaa are spelling of the same letter.
      case 0x0624:
        buffer.writeCharCode(0x0648);
      case 0x0626:
        buffer.writeCharCode(0x064A);
      // Harakat, tanween, the other marks, tatweel and the dagger alef are
      // not letters.
      case >= 0x064B && <= 0x065F:
      case 0x0640:
      case 0x0670:
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().toLowerCase();
}

/// The key a name is found by: folded, with no spaces at all, since a space
/// inside a name is a spelling choice («عبد الله», «عبدالله»).
String arabicSearchKey(String value) =>
    arabicFold(value).replaceAll(RegExp(r'\s+'), '');

/// The key a name is ordered by: folded, its words kept apart by one space,
/// and «عبد» joined to the word after it, since «عبد الله» and «عبدالله» are
/// one compound name.
String arabicSortKey(String value) {
  final words = arabicFold(value).split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  final buffer = StringBuffer();
  for (var index = 0; index < words.length; index++) {
    final word = words[index];
    buffer.write(word);
    final joinsNext = word == 'عبد' && index + 1 < words.length;
    if (!joinsNext && index + 1 < words.length) buffer.write(' ');
  }
  return buffer.toString();
}

/// Compares two Arabic names by [arabicSortKey], falling back to the names
/// themselves so two spellings of one name keep a stable order.
int compareArabicNames(String a, String b) {
  final byKey = arabicSortKey(a).compareTo(arabicSortKey(b));
  return byKey != 0 ? byKey : a.compareTo(b);
}
