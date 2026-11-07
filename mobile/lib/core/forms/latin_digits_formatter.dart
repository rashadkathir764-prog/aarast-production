import 'dart:math' as math;

import 'package:flutter/services.dart';

/// The digit 0-9 [rune] stands for: itself, an Arabic-Indic digit (٠-٩) or
/// an Eastern Arabic-Indic one (۰-۹), as an Arabic keyboard types them; null
/// for anything else. The one rule for every number the person types.
int? latinDigitOf(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return rune;
  if (rune >= 0x0660 && rune <= 0x0669) return 0x30 + (rune - 0x0660);
  if (rune >= 0x06F0 && rune <= 0x06F9) return 0x30 + (rune - 0x06F0);
  return null;
}

/// A field of digits (a code, a count, a price) that takes the digits an
/// Arabic keyboard types. `FilteringTextInputFormatter.digitsOnly` keeps
/// 0-9 only, so «٥٠٠٠٠٠» or a WhatsApp code typed in Arabic digits vanished
/// and the field stayed empty: each becomes 0-9 here, and anything that is
/// not a digit is dropped. With [decimals] above 0, one decimal point
/// (`.` or the Arabic «٫») and that many digits after it are kept.
class LatinDigitsFormatter extends TextInputFormatter {
  const LatinDigitsFormatter({this.decimals = 0});

  final int decimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final end = newValue.selection.end < 0
        ? newValue.text.length
        : math.min(newValue.selection.end, newValue.text.length);
    final beforeCursor = _keep(newValue.text.substring(0, end)).length;
    final text = _keep(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: math.min(beforeCursor, text.length),
      ),
    );
  }

  String _keep(String input) {
    final buffer = StringBuffer();
    var hasPoint = false;
    var fraction = 0;
    for (final rune in input.runes) {
      final digit = latinDigitOf(rune);
      if (digit != null) {
        if (hasPoint && fraction >= decimals) continue;
        buffer.writeCharCode(digit);
        if (hasPoint) fraction++;
        continue;
      }
      if (decimals > 0 && !hasPoint && (rune == 0x2E || rune == 0x066B)) {
        hasPoint = true;
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}
