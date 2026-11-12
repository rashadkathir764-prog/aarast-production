import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../../core/forms/latin_digits_formatter.dart' show latinDigitOf;

class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.wholeOnly = false});

  /// A field that takes whole riyals (the first run's budget, the mahr):
  /// grouped as typed, never a fraction (RA-MO-113). A fraction of one or
  /// two digits at the end is dropped with its point («5000000.00» is five
  /// million); any other point is a grouping mark and goes. Deleting every
  /// point alone turned that paste into five hundred million.
  final bool wholeOnly;

  /// The most digits an amount has (`FinanceMoneyRules.serverAmount`).
  static const maxWholeDigits = 12;

  static final _fraction = RegExp(r'[.٫][0-9٠-٩۰-۹]{0,2}$');
  static final _point = RegExp(r'[.٫]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    if (wholeOnly && newValue.text.contains(_point)) {
      final whole = newValue.text
          .replaceFirst(_fraction, '')
          .replaceAll(_point, '');
      newValue = TextEditingValue(
        text: whole,
        selection: TextSelection.collapsed(offset: whole.length),
      );
    }

    final selectionEnd = newValue.selection.end < 0
        ? newValue.text.length
        : math.min(newValue.selection.end, newValue.text.length);
    final meaningfulBeforeCursor = _sanitize(
      newValue.text.substring(0, selectionEnd),
    ).length;
    final sanitized = _sanitize(newValue.text);
    // D86: an amount has at most twelve digits, the server's own bound. A
    // longer one was taken here and refused later, at the save, under a
    // message about something else.
    if (wholeOnly && sanitized.length > maxWholeDigits) return oldValue;
    final formatted = formatMoneyInputValue(sanitized);

    var formattedOffset = 0;
    var meaningfulSeen = 0;
    while (formattedOffset < formatted.length &&
        meaningfulSeen < meaningfulBeforeCursor) {
      if (_isMeaningful(formatted.codeUnitAt(formattedOffset))) {
        meaningfulSeen++;
      }
      formattedOffset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formattedOffset),
    );
  }
}

String formatMoneyInputValue(Object? value) {
  final sanitized = _sanitize(value?.toString() ?? '');
  if (sanitized.isEmpty) return '';

  final decimalIndex = sanitized.indexOf('.');
  final integer = decimalIndex == -1
      ? sanitized
      : sanitized.substring(0, decimalIndex);
  final fraction = decimalIndex == -1
      ? null
      : sanitized.substring(decimalIndex + 1);
  final normalizedInteger = integer.isEmpty ? '0' : integer;
  final grouped = _groupDigits(normalizedInteger);
  return fraction == null ? grouped : '$grouped.$fraction';
}

String _sanitize(String input) {
  final buffer = StringBuffer();
  var hasDecimal = false;
  var fractionDigits = 0;
  for (final rune in input.runes) {
    final digit = _normalizedDigit(rune);
    if (digit != null) {
      if (hasDecimal && fractionDigits >= 2) continue;
      buffer.writeCharCode(digit);
      if (hasDecimal) fractionDigits++;
      continue;
    }
    if (!hasDecimal && (rune == 0x2E || rune == 0x066B)) {
      hasDecimal = true;
      buffer.write('.');
    }
  }
  return buffer.toString();
}

int? _normalizedDigit(int rune) => latinDigitOf(rune);

bool _isMeaningful(int codeUnit) =>
    (codeUnit >= 0x30 && codeUnit <= 0x39) || codeUnit == 0x2E;

String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
