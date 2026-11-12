import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/release_field_focus.dart';
import 'money_input_formatter.dart';

/// a06 «اتفقتوا على المهر؟»: the mahr, what was handed over (the groom) or
/// received (the bride), and the day the rest is due. One set of fields for the welcome steps
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
    this.currency = 'YER',
    super.key,
  });

  /// D86: the plan's currency; the mahr is not always in rial.
  final String currency;

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
          hint: 'مثلًا: 3,000,000',
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          inputFormatters: formatters,
          suffix: currencyLabelAr(currency),
          errorText: totalError,
          onChanged: (_) => onChanged(),
        ),
        if (total != null && total > 0) ...[
          const SizedBox(height: AarastV3Space.x2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    amountInWords(total),
                    style: JourneyType.of(
                      JourneyType.bodySmall,
                      weight: JourneyType.bold,
                      color: context.accent.primaryDark,
                    ),
                  ),
                ),
                if (remaining != null && remaining > 0)
                  Text(
                    'باقي ${mahrWords(remaining, currency)}',
                    key: const ValueKey('mahr-remaining'),
                    style: JourneyType.of(
                      JourneyType.bodySmall,
                      weight: JourneyType.bold,
                      color: context.accent.primaryDark,
                    ),
                  ),
              ],
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
          suffix: currencyLabelAr(currency),
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
            // The groom hands the rest over, the bride receives it.
            label: pays ? 'موعد تسليم الباقي' : 'موعد استلام الباقي',
            value: dueDate == null
                ? null
                : '${formatArabicWeekdayDayMonth(dueDate!)} ${dueDate!.year}',
            helper: dueDate == null
                ? null
                : HijriDate.fromGregorian(dueDate!)?.full,
            icon: LucideIcons.calendarDays,
            iconAtEnd: true,
            placeholder: context.say('اختر اليوم', 'اختاري اليوم'),
            onTap: onPickDueDate,
          ),
        ],
      ],
    );
  }
}

/// An amount the way people say it (as amountInWords does): «مليون»,
/// «مليونين», «3 مليون», «1.5 مليون», «500,000».
String mahrWords(num amount, [String currency = 'YER']) {
  final parts = compactMoneyParts(amount, currencyCode: currency);
  final unit = parts.millionUnit;
  if (unit == null) return parts.number;
  if (parts.number == '1') return unit;
  if (parts.number == '2') return 'مليونين';
  return '${parts.number} $unit';
}

/// The day the rest of the mahr is due, from today on.
/// [accent] is the plan's, when [context] sits above its profile scope.
Future<DateTime?> pickMahrDueDate(
  BuildContext context,
  DateTime? current, {
  JourneyAccent? accent,
}) {
  releaseFieldFocus();
  final today = DateUtils.dateOnly(appNow());
  final colours = accent ?? context.accent;
  return showDatePicker(
    context: context,
    initialDate: current != null && !current.isBefore(today) ? current : today,
    firstDate: today,
    lastDate: DateTime(today.year + 5),
    locale: const Locale('ar'),
    // The plan's colour (the bride's rose), not the app's default teal.
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: colours.primary,
          onPrimary: AarastV3Color.onPrimary,
        ),
      ),
      child: child!,
    ),
  );
}
