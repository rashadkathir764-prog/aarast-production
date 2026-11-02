import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/release_field_focus.dart';
import 'money_input_formatter.dart';

/// a06 «اتفقتوا على المهر؟»: the mahr, what was handed over (the groom) or
/// received (the bride), and the day the rest is due, then the line that
/// says whose wedding this plan is. One set of fields for the welcome steps
/// and for b01's mahr step once the plan exists.
class MahrFields extends StatelessWidget {
  const MahrFields({
    required this.pays,
    required this.totalController,
    required this.settledController,
    required this.dueDate,
    required this.onPickDueDate,
    required this.onChanged,
    this.totalError,
    this.settledError,
    super.key,
  });

  /// The groom's plan pays the mahr to the bride's family; the bride's plan
  /// receives it (C1). The plan's side, not the reader's gender.
  final bool pays;
  final TextEditingController totalController;
  final TextEditingController settledController;
  final DateTime? dueDate;
  final VoidCallback onPickDueDate;
  final VoidCallback onChanged;
  final String? totalError;
  final String? settledError;

  static int? amountOf(TextEditingController controller) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  /// What is left of the mahr, or null before the mahr is typed.
  static int? remainingOf(
    TextEditingController total,
    TextEditingController settled,
  ) {
    final mahr = amountOf(total);
    if (mahr == null || mahr <= 0) return null;
    return mahr - (amountOf(settled) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final total = amountOf(totalController);
    final remaining = remainingOf(totalController, settledController);
    final formatters = [
      FilteringTextInputFormatter.deny(RegExp(r'[.٫]')),
      const MoneyInputFormatter(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyTextField(
          key: const ValueKey('mahr-total'),
          label: 'المهر',
          controller: totalController,
          large: true,
          hint: '3,000,000',
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          inputFormatters: formatters,
          errorText: totalError,
          helper: total == null || total <= 0 ? null : amountInWords(total),
          onChanged: (_) => onChanged(),
        ),
        if (remaining != null && remaining > 0) ...[
          const SizedBox(height: AarastV3Space.x2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTag(
              key: const ValueKey('mahr-remaining'),
              label: 'باقي ${mahrWords(remaining)}',
              color: AarastV3Color.brandAccentStrong,
              soft: AarastV3Color.brandAccentSoft,
            ),
          ),
        ],
        const SizedBox(height: AarastV3Space.x3),
        JourneyTextField(
          key: const ValueKey('mahr-settled'),
          label: pays
              ? context.say('سلّمت منه', 'سلّمتِ منه')
              : context.say('استلمت منه', 'استلمتِ منه'),
          controller: settledController,
          icon: LucideIcons.checkCircle2,
          hint: '0',
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          inputFormatters: formatters,
          errorText: settledError,
          onChanged: (_) => onChanged(),
        ),
        if (remaining == null || remaining > 0) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyPickerField(
            key: const ValueKey('mahr-due-date'),
            // a06 draws «موعد تسليم الباقي» on both sides.
            label: 'موعد تسليم الباقي',
            value: dueDate == null ? null : formatArabicDayMonth(dueDate!),
            icon: LucideIcons.calendarDays,
            placeholder: context.say('اختر اليوم', 'اختاري اليوم'),
            onTap: onPickDueDate,
          ),
        ],
        const SizedBox(height: AarastV3Space.x4),
        JourneyNote(
          // Whose wedding the plan is (the plan's side), said to its owner.
          text: pays
              ? 'تجهيز العروسة وعرس النساء عند أهلها. '
                    '${context.say('خطتك لعرسك أنت', 'خطتك لعرسك أنتِ')}: عرس الرجال.'
              : 'عرس الرجال عند العريس وأهله. '
                    '${context.say('خطتك لعرسك أنت', 'خطتك لعرسك أنتِ')}: عرس النساء.',
          icon: LucideIcons.heartHandshake,
          color: context.accent.primaryDark,
          soft: context.accent.primarySoft,
        ),
      ],
    );
  }
}

/// An amount the way a06 and b01 say it: «مليون», «3 مليون», «500,000».
String mahrWords(num amount) {
  final parts = compactMoneyParts(amount, currencyCode: 'YER');
  final unit = parts.millionUnit;
  if (unit == null) return parts.number;
  return parts.number == '1' ? unit : '${parts.number} $unit';
}

/// The day the rest of the mahr is due, from today on.
Future<DateTime?> pickMahrDueDate(BuildContext context, DateTime? current) {
  releaseFieldFocus();
  final today = DateUtils.dateOnly(DateTime.now());
  return showDatePicker(
    context: context,
    initialDate: current != null && !current.isBefore(today) ? current : today,
    firstDate: today,
    lastDate: DateTime(today.year + 5),
    locale: const Locale('ar'),
  );
}
