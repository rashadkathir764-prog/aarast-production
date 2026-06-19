import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
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

    return GuestOnboardingStepScaffold(
      title: 'متى موعد الزفاف؟',
      description: 'يمكنك اختيار تاريخ تقريبي أو المتابعة بدون تاريخ الآن.',
      continueLabel: 'متابعة',
      onContinue: onContinue,
      onBack: onBack,
      child: Column(
        children: [
          GuestOnboardingOptionTile(
            title: 'لا أعرف التاريخ الآن',
            subtitle: 'استخدموا خطة مرنة إلى أن يتم تحديد الموعد.',
            icon: Icons.event_busy_rounded,
            selected: draft.weddingDateUnknown || draft.weddingDate == null,
            onTap: () => onSelectDate?.call(null, unknown: true),
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
