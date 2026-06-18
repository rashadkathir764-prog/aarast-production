const _countryCode = '967';
const _invalidYemeniPhoneMessage = 'Invalid Yemeni phone number';

String normalizeYemeniPhone(String input) {
  final value = _toAsciiDigits(input).trim();
  final digits = value.replaceAll(RegExp('[^0-9]'), '');

  if (digits.isEmpty) {
    throw const FormatException(_invalidYemeniPhoneMessage);
  }

  final local = _localYemeniDigits(value, digits);
  if (local.length != 9) {
    throw const FormatException(_invalidYemeniPhoneMessage);
  }

  return '+$_countryCode$local';
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

String _localYemeniDigits(String value, String digits) {
  if (value.startsWith('+')) {
    if (!digits.startsWith(_countryCode)) {
      throw const FormatException(_invalidYemeniPhoneMessage);
    }
    return digits.substring(_countryCode.length);
  }

  if (digits.startsWith('00$_countryCode')) {
    return digits.substring('00$_countryCode'.length);
  }

  if (digits.startsWith(_countryCode)) {
    return digits.substring(_countryCode.length);
  }

  if (digits.startsWith('0')) {
    return digits.substring(1);
  }

  return digits;
}

String _toAsciiDigits(String value) {
  final buffer = StringBuffer();
  for (final codePoint in value.runes) {
    if (codePoint >= 0x0660 && codePoint <= 0x0669) {
      buffer.writeCharCode(0x30 + codePoint - 0x0660);
    } else if (codePoint >= 0x06f0 && codePoint <= 0x06f9) {
      buffer.writeCharCode(0x30 + codePoint - 0x06f0);
    } else {
      buffer.writeCharCode(codePoint);
    }
  }
  return buffer.toString();
}
