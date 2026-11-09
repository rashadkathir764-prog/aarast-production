import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/plan_day.dart';
import '../models/money_plan.dart' show reminderDayToCome;

// D106: a date agreed again (it is no longer late until its new day, and
// its first day is kept), and a date's own reminder day.

/// «اتفقتوا على موعد ثاني؟»: only when the other side agreed; to be
/// reminded on another day is the reminder's.
class MoveDueDateSheet extends StatefulWidget {
  const MoveDueDateSheet({
    required this.title,
    required this.dueDate,
    required this.party,
    required this.weddingDate,
    required this.onSave,
    this.firstDue,
    super.key,
  });

  final String title;
  final DateTime dueDate;

  /// D106: the day it was first due, when it was moved.
  final DateTime? firstDue;
  final String? party;
  final DateTime? weddingDate;
  final Future<bool> Function(DateTime day) onSave;

  @override
  State<MoveDueDateSheet> createState() => _MoveDueDateSheetState();
}

class _MoveDueDateSheetState extends State<MoveDueDateSheet> {
  DateTime? _day;
  bool _saving = false;

  Future<void> _pick() async {
    final today = sanaaToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: DateTime(today.year + 3),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _save() async {
    final day = _day;
    if (day == null) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(day);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = sanaaToday();
    final due = widget.dueDate;
    final first = widget.firstDue;
    final wedding = widget.weddingDate;
    final choices = <(String, String, DateTime)>[
      ('week', 'بعد أسبوع', today.add(const Duration(days: 7))),
      ('weeks', 'بعد أسبوعين', today.add(const Duration(days: 14))),
      if (wedding != null && !wedding.isBefore(today))
        ('wedding', 'يوم العرس', DateUtils.dateOnly(wedding)),
      if (first != null && !first.isBefore(today))
        ('first', 'موعدها الأول', DateUtils.dateOnly(first)),
    ];
    final party = widget.party?.trim();
    return JourneySheetBody(
      title: 'اتفقتوا على موعد ثاني؟',
      subtitle:
          '${widget.title} · موعدها الحين ${formatArabicWeekdayDayMonth(due)}. '
          '${context.say('غيّره', 'غيّريه')} بس لما ${context.say('تتفق', 'تتفقين')}'
          '${party == null || party.isEmpty ? '' : ' مع «$party»'} على يوم ثاني: '
          'الدفعة ما تعتبر متأخرة لين الموعد الجديد. '
          '${context.say('ولو تبغى', 'ولو تبغين')} بس نذكّرك في يوم ثاني، غيّر التذكير.',
      children: [
        Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            for (final (key, label, day) in choices)
              JourneyChip(
                key: ValueKey('money-move-$key'),
                label: label,
                selected: _day != null && DateUtils.isSameDay(_day, day),
                onTap: () => setState(() => _day = day),
              ),
            JourneyChip(
              key: const ValueKey('money-move-other'),
              label: 'تاريخ ثاني',
              icon: LucideIcons.calendarDays,
              selected:
                  _day != null &&
                  !choices.any(
                    (choice) => DateUtils.isSameDay(_day, choice.$3),
                  ),
              onTap: _pick,
            ),
          ],
        ),
        if (_day case final day?) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            'الموعد الجديد: ${formatArabicWeekdayDayMonth(day)}',
            key: const ValueKey('money-move-chosen'),
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
        ],
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('money-move-save'),
          label: 'اتفقنا على هالموعد',
          loading: _saving,
          onPressed: _day == null || _saving ? null : _save,
        ),
      ],
    );
  }
}

/// A date's own reminder day, between today and the date; or as usual.
class DueReminderSheet extends StatefulWidget {
  const DueReminderSheet({
    required this.title,
    required this.dueDate,
    required this.remindAt,
    required this.onSave,
    super.key,
  });

  final String title;
  final DateTime dueDate;

  /// Its own reminder day; null: as usual.
  final DateTime? remindAt;
  final Future<bool> Function(DateTime? day) onSave;

  @override
  State<DueReminderSheet> createState() => _DueReminderSheetState();
}

class _DueReminderSheetState extends State<DueReminderSheet> {
  // RA-MO-50: its own day while it is still to come; one that has passed
  // was used, and the date is reminded as usual unless another is chosen
  // (the server takes a day from today on, D106).
  late DateTime? _day = reminderDayToCome(widget.remindAt);
  bool _saving = false;

  Future<void> _pick(DateTime due) async {
    final today = sanaaToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? (due.isBefore(today) ? today : due),
      firstDate: today,
      lastDate: due.isBefore(today) ? today : due,
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.onSave(_day);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = sanaaToday();
    final due = DateUtils.dateOnly(widget.dueDate);
    // Only days between today and the date (D106).
    final choices = <(String, String, DateTime)>[
      for (final (key, label, days) in const [
        ('day', 'قبلها بيوم', 1),
        ('three', 'قبلها بثلاثة أيام', 3),
        ('week', 'قبلها بأسبوع', 7),
      ])
        if (!due.subtract(Duration(days: days)).isBefore(today))
          (key, label, due.subtract(Duration(days: days))),
    ];
    return JourneySheetBody(
      title: 'متى نذكّرك؟',
      subtitle: '${widget.title} · موعدها ${formatArabicWeekdayDayMonth(due)}',
      children: [
        Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            JourneyChip(
              key: const ValueKey('money-remind-usual'),
              label: 'مثل العادة',
              selected: _day == null,
              onTap: () => setState(() => _day = null),
            ),
            for (final (key, label, day) in choices)
              JourneyChip(
                key: ValueKey('money-remind-$key'),
                label: label,
                selected: _day != null && DateUtils.isSameDay(_day, day),
                onTap: () => setState(() => _day = day),
              ),
            if (!due.isBefore(today))
              JourneyChip(
                key: const ValueKey('money-remind-other'),
                label: 'يوم ثاني',
                icon: LucideIcons.calendarDays,
                selected:
                    _day != null &&
                    !choices.any(
                      (choice) => DateUtils.isSameDay(_day, choice.$3),
                    ),
                onTap: () => _pick(due),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x2),
        Text(
          _day == null
              ? 'نذكّرك قبل موعدها بأيام، مثل كل الدفعات.'
              : 'نذكّرك ${formatArabicWeekdayDayMonth(_day!)}.',
          key: const ValueKey('money-remind-chosen'),
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('money-remind-save'),
          label: 'احفظ',
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
