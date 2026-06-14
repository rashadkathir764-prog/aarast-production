String normalizeYemenPhone(String phone) {
  final digits = StringBuffer();
  var hasLeadingPlus = false;

  for (final rune in phone.trim().runes) {
    final char = String.fromCharCode(rune);
    if (char == '+' && digits.isEmpty && !hasLeadingPlus) {
      hasLeadingPlus = true;
      continue;
    }

    final digit = _normalizeDigit(rune);
    if (digit != null) {
      digits.write(digit);
    }
  }

  final value = digits.toString();
  if (value.startsWith('00967')) {
    return '+${value.substring(2)}';
  }
  if (value.startsWith('967')) {
    return '+$value';
  }
  if (!hasLeadingPlus && value.length == 9 && value.startsWith('7')) {
    return '+967$value';
  }
  return hasLeadingPlus ? '+$value' : value;
}

String? _normalizeDigit(int rune) {
  if (rune >= 0x30 && rune <= 0x39) {
    return String.fromCharCode(rune);
  }
  if (rune >= 0x660 && rune <= 0x669) {
    return String.fromCharCode(0x30 + rune - 0x660);
  }
  if (rune >= 0x6F0 && rune <= 0x6F9) {
    return String.fromCharCode(0x30 + rune - 0x6F0);
  }
  return null;
}
