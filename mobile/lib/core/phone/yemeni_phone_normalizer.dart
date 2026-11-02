import 'phone_number_utils.dart';

String normalizeYemeniPhone(String input) {
  return PhoneNumberUtils.normalizeYemeni(input);
}

String? normalizeOptionalYemeniPhone(String? input) {
  final value = input?.trim();
  if (value == null || value.isEmpty) return null;
  return normalizeYemeniPhone(value);
}

bool isValidYemeniPhoneInput(String input) {
  try {
    normalizeYemeniPhone(input);
    return true;
  } on FormatException {
    return false;
  }
}

bool isValidOptionalYemeniPhoneInput(String? input) {
  final value = input?.trim();
  if (value == null || value.isEmpty) return true;
  return isValidYemeniPhoneInput(value);
}

/// What is wrong with a typed phone number, in the words every entry field
/// shows (D75), or null when it can be sent. [empty] names what the field
/// asks for when nothing is typed.
String? yemeniPhoneInputError(
  String input, {
  String empty = 'رقم الجوال مطلوب',
}) {
  final phone = input.trim();
  if (phone.isEmpty) return empty;
  if (!isValidYemeniPhoneInput(phone)) return 'رقم الجوال غير صحيح';
  return null;
}
