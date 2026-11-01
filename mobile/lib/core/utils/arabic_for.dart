/// Names that begin like «ال» without being definite.
const _notDefinite = {'الهام', 'الياس'};

/// «لصالح», and «للوالد» where the alif of «ال» falls after «ل».
String arabicFor(String name) {
  final text = name.trim();
  if (text.startsWith('ال') && !_notDefinite.contains(text)) {
    return 'ل${text.substring(1)}';
  }
  return 'ل$text';
}
