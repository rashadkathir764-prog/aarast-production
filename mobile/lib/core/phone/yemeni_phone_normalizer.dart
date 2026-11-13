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
  if (!isValidYemeniPhoneInput(phone)) return yemeniPhoneRefusal(phone);
  return null;
}

/// D112 (Q-12), the first step: why a typed number that is not a Yemeni
/// mobile is not taken. A number written with another country's code (the
/// groom working in Riyadh) is a right number the app does not take yet,
/// and is told so; «رقم الجوال غير صحيح» was said to it. Anything else is a
/// wrong number. Taking the Gulf's numbers themselves waits for the server
/// and the WhatsApp sender.
String yemeniPhoneRefusal(String input) {
  final compact = PhoneNumberUtils.toAsciiDigits(
    input,
  ).replaceAll(RegExp(r'[\s\-\(\)]'), '');
  final abroad = RegExp(r'^(?:\+|00)(\d{8,15})$').firstMatch(compact);
  return abroad != null && !abroad.group(1)!.startsWith('967')
      ? 'نقبل الأرقام اليمنية بس حاليًا.'
      : 'رقم الجوال غير صحيح';
}
