import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Batch 5 (RA-MO-322 rest, Q-35 (أ)): these files spoke formal Arabic
// («أين سيكون الزفاف؟», «لديك مهام متأخرة», «ثبّت أساس الخطة») where the
// app speaks Sana'ani. A formal word in any string they hold is reported,
// with the app's own word for it.

const _files = [
  'lib/features/onboarding/models/persona_copy.dart',
  'lib/features/wedding_plans/models/wedding_plan_stage.dart',
  'lib/features/home/data/dashboard_summary_sources.dart',
  'lib/features/onboarding/models/generated_dashboard_seed.dart',
  'lib/core/experience_v3/aarast_v3_adaptive.dart',
];

/// The formal word and the app's word for it.
const _formal = <String, String>{
  'أين': 'فين',
  'سيكون': 'بيكون، أو بلا مستقبل',
  'ستكون': 'بتكون، أو بلا مستقبل',
  'ستساعد': 'تساعد',
  'تريد': 'تشتي',
  'هذه': 'هذي',
  'لديك': 'عندك',
  'التي': 'اللي',
  'الذي': 'اللي',
  'لم': 'ما',
  'دون': 'بدون، أو بلا',
  'أدخل': 'اكتب',
  'لاحقًا': 'بعدين',
  'ثم': 'وبعدها',
  'إلى': 'لـ',
  'أن': 'بلا «أن»',
  'إن': 'لو',
  'فقط': 'بس',
  'تجاوزت': 'فاتت',
  'القادمة': 'الجاية',
  'تصبح': 'تصير',
  'بعض': 'فيه',
  'أمامك': 'قدامك',
  'متوفرة': 'معك',
  'الزفاف': 'العرس',
  'غير': 'ما',
};

const _arabic = 'ء-يً-ْ';

void main() {
  test("the copy of these files is Sana'ani, not formal Arabic", () {
    final patterns = {
      for (final word in _formal.keys)
        word: RegExp('(?<![$_arabic])$word(?![$_arabic])'),
    };
    final literal = RegExp(r"'([^'\\]|\\.)*'");
    final offenders = <String>[];
    for (final path in _files) {
      final lines = File(path).readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final code = lines[index].trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        for (final match in literal.allMatches(code)) {
          final text = match.group(0)!;
          for (final entry in patterns.entries) {
            if (entry.value.hasMatch(text)) {
              offenders.add(
                '$path:${index + 1}: «${entry.key}» is '
                '«${_formal[entry.key]}»: $text',
              );
            }
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
