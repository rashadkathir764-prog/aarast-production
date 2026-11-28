part of 'provider_marketplace_screen.dart';

/// The category a typed word names, so a search that found nobody by name
/// offers the category instead (REFINEMENT_SPEC 2.7: «مصور» → «تصوير»): the
/// typed word and the category's name (or the plan's word for the venue)
/// share their first three root letters. Null when none does.
ProviderCategory? providerCategoryNamedBy(
  String typed,
  List<ProviderCategory> categories, {
  required bool bridePlan,
}) {
  final asked = _searchRoots(typed);
  if (asked.isEmpty) return null;
  for (final category in categories) {
    for (final name in {
      category.nameAr,
      providerKindNameFor(category, bridePlan: bridePlan),
    }) {
      final roots = _searchRoots(name);
      if (roots.any(asked.contains)) return category;
    }
  }
  return null;
}

/// The first three letters of a word's root, with and without a leading
/// pattern letter: «ال» goes, the shadda and the long vowels «ا» «ي» go, a
/// final «ة» reads as «ت», and a leading «م» or «ت» may be the pattern's
/// (مصوّر، تصوير) or the root's own (مكياج). Matching letters, not words
/// the reader sees.
Set<String> _searchRoots(String text) {
  final words = text.trim().split(RegExp(r'\s+'));
  var word = words.isEmpty ? '' : words.first;
  if (word.startsWith('ال')) word = word.substring(2);
  word = word
      .replaceAll(RegExp('[ً-ْ]'), '')
      .replaceAll(RegExp('[اي]'), '')
      .replaceAll('ة', 'ت');
  return {
    for (final candidate in [
      word,
      if (word.startsWith('م') || word.startsWith('ت')) word.substring(1),
    ])
      if (candidate.length >= 3) candidate.substring(0, 3),
  };
}
