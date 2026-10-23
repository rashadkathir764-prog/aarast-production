part of 'task_details_screen.dart';

/// Asks for a day from today on; null when the person backs out.
Future<DateTime?> pickTaskDate(BuildContext context, {DateTime? initial}) {
  releaseFieldFocus();
  final today = DateUtils.dateOnly(DateTime.now());
  final start = initial != null && !initial.isBefore(today) ? initial : today;
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: today,
    lastDate: today.add(const Duration(days: 3650)),
    locale: const Locale('ar'),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AarastV3Color.brandAccentStrong),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// The responsible person, with a call and a WhatsApp chat.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.name,
    required this.phone,
    required this.onCall,
    required this.onWhatsApp,
  });

  final String name;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('task-contact'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          JourneyAvatar(
            letter: name.isEmpty ? '؟' : name.characters.first,
            color: AarastV3Color.brandAccentStrong,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  PhoneNumberUtils.directionalDisplay(phone) ?? phone,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          JourneyRoundButton(
            key: const ValueKey('task-contact-call'),
            icon: LucideIcons.phone,
            tooltip: 'اتصل بـ$name',
            onPressed: onCall,
          ),
          if (onWhatsApp != null) ...[
            const SizedBox(width: 6),
            JourneyRoundButton(
              key: const ValueKey('task-contact-whatsapp'),
              icon: LucideIcons.messageCircle,
              tooltip: 'كلّم $name على واتساب',
              onPressed: onWhatsApp!,
            ),
          ],
        ],
      ),
    );
  }
}

enum _TaskAction { handOver, moveDate, edit, reopen, cancel, delete }

/// x16: what can be done with a task besides finishing it. A free-text time
/// («بعد العصر») is not offered: a task keeps a day only.
class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.open,
    required this.disabled,
    required this.onSelected,
  });

  final bool open;
  final bool disabled;
  final ValueChanged<_TaskAction> onSelected;

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<_TaskAction> item(
      _TaskAction action,
      IconData icon,
      String title, {
      bool danger = false,
    }) => PopupMenuItem(
      key: ValueKey('task-menu-${action.name}'),
      value: action,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: danger ? AarastV3Color.danger : AarastV3Color.ink,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              style: TextStyle(color: danger ? AarastV3Color.danger : null),
            ),
          ),
        ],
      ),
    );
    return PopupMenuButton<_TaskAction>(
      key: const ValueKey('task-menu'),
      enabled: !disabled,
      tooltip: 'خيارات المهمة',
      icon: const Icon(LucideIcons.moreHorizontal),
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (open) ...[
          item(_TaskAction.handOver, LucideIcons.userPlus, 'حوّلها لأحد ثاني'),
          item(_TaskAction.moveDate, LucideIcons.calendarClock, 'غيّر موعدها'),
        ],
        item(_TaskAction.edit, LucideIcons.pencil, 'عدّل المهمة'),
        if (!open)
          item(_TaskAction.reopen, LucideIcons.rotateCcw, 'أعد فتحها')
        else
          item(_TaskAction.cancel, LucideIcons.x, 'ما نحتاجها', danger: true),
        item(_TaskAction.delete, LucideIcons.trash2, 'احذفها', danger: true),
      ],
    );
  }
}

/// «أجّلها»: a few common delays, or a day of one's choosing.
class _PostponeSheet extends StatelessWidget {
  const _PostponeSheet({required this.task});

  final WeddingTask task;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final from = task.dueDate != null && !task.dueDate!.isBefore(today)
        ? DateUtils.dateOnly(task.dueDate!)
        : today;
    final options = [
      ('بكرة', today.add(const Duration(days: 1))),
      ('بعد ثلاثة أيام', from.add(const Duration(days: 3))),
      ('بعد أسبوع', from.add(const Duration(days: 7))),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'لمتى تأجلها؟',
              style: JourneyType.of(
                JourneyType.title,
                weight: JourneyType.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          JourneyBox(
            padding: EdgeInsets.zero,
            child: JourneyList(
              children: [
                for (final (label, date) in options)
                  JourneyListRow(
                    key: ValueKey('task-postpone-$label'),
                    icon: LucideIcons.calendarClock,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                    title: label,
                    subtitle: formatArabicWeekdayDayMonth(date),
                    onTap: () => Navigator.pop(context, date),
                  ),
                JourneyListRow(
                  key: const ValueKey('task-postpone-pick'),
                  icon: LucideIcons.calendarDays,
                  color: AarastV3Color.primary,
                  soft: AarastV3Color.primarySoft,
                  title: 'اختر يوم',
                  subtitle: 'من التقويم',
                  onTap: () async {
                    final date = await pickTaskDate(
                      context,
                      initial: task.dueDate,
                    );
                    if (date != null && context.mounted) {
                      Navigator.pop(context, date);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'تحذف «$title»؟',
              style: JourneyType.of(
                JourneyType.title,
                weight: JourneyType.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'تنمسح هي وخطواتها. لو بس ما تحتاجها، «ما نحتاجها» تخليها في السجل.',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          JourneyButton(
            key: const ValueKey('task-delete-confirm'),
            label: 'احذفها',
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            onPressed: () => Navigator.pop(context, true),
          ),
          Center(
            child: JourneyTextAction(
              label: 'رجوع',
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    );
  }
}
