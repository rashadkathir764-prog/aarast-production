part of 'task_details_screen.dart';

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

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: 'تحذف «$title»؟',
      subtitle:
          'تنمسح هي وخطواتها. لو بس ما تحتاجها، «ما نحتاجها» تخليها في السجل.',
      children: [
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
    );
  }
}
