/// The same service groups the server uses to file an accepted offer under a
/// money item (backend/src/modules/finance/domain/cost-category-matching.ts).
/// Keep the two lists equal.
const providerServiceGroups = <List<String>>[
  ['صالة', 'صاله', 'صالات', 'الصالات', 'قاعة', 'قاعه', 'قاعات', 'hall', 'venue'],
  ['غداء', 'عشاء', 'ضيافة', 'ضيافه', 'بوفيه', 'تموين', 'ماء', 'cater'],
  ['تصوير', 'مصور', 'فيديو', 'كاميرا', 'photo', 'video'],
  ['كوشة', 'كوشه', 'ديكور', 'ورد', 'زفة', 'زفه', 'decor'],
  ['فنان', 'فرقة', 'فرقه', 'ديجي', 'dj', 'music', 'ترفيه'],
  ['فستان', 'ازياء', 'أزياء', 'ملابس', 'بدلة', 'بدله', 'dress'],
  ['صالون', 'مكياج', 'تجميل', 'كوافير', 'beauty', 'salon'],
  ['قات', 'مقوت', 'مقوّت', 'qat'],
];

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[ً-ْـ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Which service group a name belongs to, or -1.
int providerServiceGroupOf(String? name) {
  final source = _normalize(name ?? '');
  if (source.isEmpty) return -1;
  for (var i = 0; i < providerServiceGroups.length; i++) {
    if (providerServiceGroups[i].any(
      (keyword) => source.contains(_normalize(keyword)),
    )) {
      return i;
    }
  }
  return -1;
}
