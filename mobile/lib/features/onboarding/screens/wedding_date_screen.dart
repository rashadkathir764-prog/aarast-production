import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
import '../models/persona_copy.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class WeddingDateScreen extends StatelessWidget {
  const WeddingDateScreen({
    this.draft = const GuestOnboardingDraft.empty(),
    this.onSelectDate,
    this.onContinue,
    this.onBack,
    super.key,
  });

  final GuestOnboardingDraft draft;
  final void Function(DateTime? date, {bool unknown})? onSelectDate;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sixMonthsLater = DateTime(now.year, now.month + 6, now.day);
    final twelveMonthsLater = DateTime(now.year + 1, now.month, now.day);
    final copy = personaCopyForGuest(draft.persona);

    return GuestOnboardingStepScaffold(
      stepNumber: 4,
      title: copy.weddingDateTitle,
      description: 'يمكنك اختيار تاريخ تقريبي أو المتابعة بدون تاريخ الآن.',
      continueLabel: 'متابعة',
      onContinue: draft.hasTimelineSeed ? onContinue : null,
      onBack: onBack,
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            key: const Key('guest-date-unknown'),
            title: 'لا أعرف التاريخ الآن',
            subtitle: 'استخدموا خطة مرنة إلى أن يتم تحديد الموعد.',
            icon: Icons.event_busy_rounded,
            selected: draft.weddingDateUnknown,
            onTap: () => onSelectDate?.call(null, unknown: true),
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'اختيار تاريخ من التقويم',
            subtitle: draft.weddingDate == null
                ? copy.calendarSubtitle
                : _dateLabel(draft.weddingDate!),
            icon: Icons.calendar_month_rounded,
            selected: draft.weddingDate != null && !draft.weddingDateUnknown,
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: draft.weddingDate ?? sixMonthsLater,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 5),
                helpText: 'اختر موعد الزفاف',
                cancelText: 'إلغاء',
                confirmText: 'اعتماد',
              );
              if (selected != null) onSelectDate?.call(selected);
            },
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'بعد 6 أشهر تقريبًا',
            subtitle: _dateLabel(sixMonthsLater),
            icon: Icons.event_available_rounded,
            selected: _sameDay(draft.weddingDate, sixMonthsLater),
            onTap: () => onSelectDate?.call(sixMonthsLater),
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'بعد سنة تقريبًا',
            subtitle: _dateLabel(twelveMonthsLater),
            icon: Icons.event_note_rounded,
            selected: _sameDay(draft.weddingDate, twelveMonthsLater),
            onTap: () => onSelectDate?.call(twelveMonthsLater),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime? left, DateTime right) {
    return left?.year == right.year &&
        left?.month == right.month &&
        left?.day == right.day;
  }

  static String _dateLabel(DateTime date) {
    return '${date.year}/${_twoDigits(date.month)}/${_twoDigits(date.day)}';
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
