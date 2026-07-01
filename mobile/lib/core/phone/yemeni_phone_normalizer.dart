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
