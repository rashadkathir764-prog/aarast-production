import '../phone/phone_number_utils.dart';

class ContactDuplicateUtils {
  const ContactDuplicateUtils._();

  static T? findByPhone<T>(
    Iterable<T> items, {
    required String? candidatePhone,
    required String? Function(T item) phoneOf,
    bool Function(T item)? exclude,
  }) {
    final candidateKey = PhoneNumberUtils.comparisonKey(candidatePhone);
    if (candidateKey == null) return null;

    for (final item in items) {
      if (exclude?.call(item) == true) continue;
      if (PhoneNumberUtils.comparisonKey(phoneOf(item)) == candidateKey) {
        return item;
      }
    }
    return null;
  }

  static String normalizeName(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static bool sameName(String? first, String? second) {
    final firstName = normalizeName(first);
    return firstName.isNotEmpty && firstName == normalizeName(second);
  }
}
