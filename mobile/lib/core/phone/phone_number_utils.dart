enum PhoneValidationState { empty, valid, warning, invalid }

class PhoneNumberAnalysis {
  const PhoneNumberAnalysis({
    required this.rawPhone,
    required this.validationState,
    this.normalizedPhone,
    this.displayPhone,
    this.message,
    this.isYemeniMobile = false,
  });

  final String rawPhone;
  final String? normalizedPhone;
  final String? displayPhone;
  final PhoneValidationState validationState;
  final String? message;
  final bool isYemeniMobile;

  bool get isEmpty => validationState == PhoneValidationState.empty;
  bool get isValid => validationState == PhoneValidationState.valid;
  bool get isWarning => validationState == PhoneValidationState.warning;
  bool get isInvalid => validationState == PhoneValidationState.invalid;
  bool get canSubmit => !isInvalid;
}

class PhoneNumberUtils {
  const PhoneNumberUtils._();

  static const _leftToRightIsolate = '\u2066';
  static const _popDirectionalIsolate = '\u2069';

  static const invalidMessage = 'أدخل رقم جوال صحيح.';
  static const internationalWarningMessage =
      'ما قدرنا نتأكد من بلد الرقم، وخلّيناه زي ما كتبته.';
  // Said to a man or a woman alike, in the app's own words.
  static const optionalPhoneMessage = 'الرقم ينضاف بعدين من شاشة الضيف.';

  static PhoneNumberAnalysis analyze(
    String? input, {
    bool required = false,
    bool requireYemeni = false,
  }) {
    final rawPhone = input?.trim() ?? '';
    if (rawPhone.isEmpty) {
      return PhoneNumberAnalysis(
        rawPhone: rawPhone,
        validationState: required
            ? PhoneValidationState.invalid
            : PhoneValidationState.empty,
        message: required ? invalidMessage : optionalPhoneMessage,
      );
    }

    final asciiPhone = toAsciiDigits(rawPhone);
    final compact = asciiPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^(?:\+|00)?[0-9]+$').hasMatch(compact)) {
      return PhoneNumberAnalysis(
        rawPhone: rawPhone,
        validationState: PhoneValidationState.invalid,
        message: invalidMessage,
      );
    }

    final digits = compact.replaceFirst(RegExp(r'^(?:\+|00)'), '');
    final yemeniLocal = _yemeniLocalDigits(compact, digits);
    if (yemeniLocal != null) {
      final normalizedPhone = '+967$yemeniLocal';
      final displayPhone = _formatYemeniMobile(yemeniLocal);
      return PhoneNumberAnalysis(
        rawPhone: rawPhone,
        normalizedPhone: normalizedPhone,
        displayPhone: displayPhone,
        validationState: PhoneValidationState.valid,
        message: _sameCompactPhone(compact, normalizedPhone)
            ? null
            // RA-MO-236: in the app's voice, not the formal «تم تنسيق».
            : 'رتّبنا الرقم كذا: ${isolateLtr(displayPhone)}',
        isYemeniMobile: true,
      );
    }

    if (_looksLikeMalformedYemeniNumber(compact, digits) || requireYemeni) {
      return PhoneNumberAnalysis(
        rawPhone: rawPhone,
        validationState: PhoneValidationState.invalid,
        message: invalidMessage,
      );
    }

    if (digits.length < 7 || digits.length > 15) {
      return PhoneNumberAnalysis(
        rawPhone: rawPhone,
        validationState: PhoneValidationState.invalid,
        message: invalidMessage,
      );
    }

    final normalizedPhone = compact.startsWith('+')
        ? '+$digits'
        : compact.startsWith('00')
        ? '+$digits'
        : digits;
    return PhoneNumberAnalysis(
      rawPhone: rawPhone,
      normalizedPhone: normalizedPhone,
      displayPhone: normalizedPhone,
      validationState: PhoneValidationState.warning,
      message: internationalWarningMessage,
    );
  }

  static String normalizeYemeni(String input) {
    final analysis = analyze(input, required: true, requireYemeni: true);
    if (!analysis.isValid || analysis.normalizedPhone == null) {
      throw const FormatException('Invalid Yemeni phone number');
    }
    return analysis.normalizedPhone!;
  }

  static String? normalizeOptional(
    String? input, {
    bool requireYemeni = false,
  }) {
    final analysis = analyze(input, requireYemeni: requireYemeni);
    if (analysis.isEmpty) return null;
    if (analysis.isInvalid || analysis.normalizedPhone == null) {
      throw const FormatException('Invalid phone number');
    }
    return analysis.normalizedPhone;
  }

  static String? display(String? input) {
    final analysis = analyze(input);
    if (analysis.isEmpty) return null;
    return analysis.displayPhone ?? analysis.rawPhone;
  }

  /// يعزل النص اللاتيني داخل واجهة RTL حتى لا ينقلب ترتيب `+` أو مجموعات
  /// الأرقام عند دمجه داخل جملة عربية.
  static String isolateLtr(String value) {
    return '$_leftToRightIsolate$value$_popDirectionalIsolate';
  }

  /// نسخة آمنة للدمج داخل نص عربي. للعروض المستقلة استخدم
  /// `AarastPhoneText` حتى يكون اتجاه عنصر النص نفسه LTR أيضًا.
  static String? directionalDisplay(String? input) {
    final value = display(input);
    if (value == null) return null;
    return isolateLtr(value);
  }

  static String? comparisonKey(String? input) {
    final analysis = analyze(input);
    if (analysis.isEmpty || analysis.isInvalid) return null;
    final normalized = analysis.normalizedPhone;
    if (normalized == null || normalized.isEmpty) return null;
    return normalized.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  static bool areEquivalent(String? first, String? second) {
    final firstKey = comparisonKey(first);
    final secondKey = comparisonKey(second);
    return firstKey != null && firstKey == secondKey;
  }

  static String toAsciiDigits(String value) {
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

  static String? _yemeniLocalDigits(String compact, String digits) {
    String? local;
    if (compact.startsWith('+967')) {
      local = digits.substring(3);
    } else if (compact.startsWith('00967')) {
      local = digits.substring(3);
    } else if (digits.startsWith('967')) {
      local = digits.substring(3);
    } else if (digits.length == 10 && digits.startsWith('0')) {
      local = digits.substring(1);
    } else if (digits.length == 9) {
      local = digits;
    }

    if (local == null || local.length != 9 || !local.startsWith('7')) {
      return null;
    }
    return local;
  }

  static bool _looksLikeMalformedYemeniNumber(String compact, String digits) {
    return compact.startsWith('+967') ||
        compact.startsWith('00967') ||
        digits.startsWith('967') ||
        (digits.startsWith('0') && digits.length <= 10);
  }

  static bool _sameCompactPhone(String compact, String normalizedPhone) {
    final normalizedCompact = compact.startsWith('00')
        ? '+${compact.substring(2)}'
        : compact;
    return normalizedCompact == normalizedPhone;
  }

  static String _formatYemeniMobile(String local) {
    return '+967 ${local.substring(0, 3)} ${local.substring(3, 6)} '
        '${local.substring(6)}';
  }
}
