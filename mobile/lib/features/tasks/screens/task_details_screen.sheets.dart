part of 'task_details_screen.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _taskSheetLabelWidth = 64.0;

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.accent.primary),
          const SizedBox(width: AarastV3Space.x2),
          SizedBox(
            width: _taskSheetLabelWidth,
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
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Row(
        children: [
          JourneyAvatar(
            letter: name.isEmpty ? '؟' : name.characters.first,
            color: context.accent.primary,
            size: 40,
          ),
          const SizedBox(width: AarastV3Space.x3),
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
            tooltip: '${context.say('اتصل', 'اتصلي')} بـ$name',
            onPressed: onCall,
          ),
          if (onWhatsApp != null) ...[
            const SizedBox(width: AarastV3Space.x1),
            JourneyRoundButton(
              key: const ValueKey('task-contact-whatsapp'),
              icon: LucideIcons.messageCircle,
              tooltip: '${context.say('كلّم', 'كلّمي')} $name على واتساب',
              onPressed: onWhatsApp!,
            ),
          ],
        ],
      ),
    );
  }
}

/// R4: what the task waits on, leading to it: the item names itself once the
/// money is read, and the words say how the task ends or how it ended.
class _TaskLinkRow extends StatelessWidget {
  const _TaskLinkRow({required this.task, required this.itemName});

  final WeddingTask task;
  final String? itemName;

  @override
  Widget build(BuildContext context) {
    final costId = task.linkedCostId;
    final itemId = task.linkedBudgetCategoryId;
    final payment = costId != null;
    return JourneyListRow(
      key: const ValueKey('task-link'),
      icon: payment ? LucideIcons.calendarClock : LucideIcons.tags,
      color: context.accent.primary,
      soft: context.accent.primarySoft,
      title: payment ? 'الدفعة في المال' : itemName ?? 'البند في المال',
      subtitle: switch ((payment, task.closedByLink)) {
        (true, true) => 'انتهت لما انسجّلت الدفعة',
        (true, false) => 'تنتهي لحالها لما تنسجّل الدفعة',
        (false, true) => 'انتهت لما انحجز البند',
        (false, false) => 'تنتهي لحالها لما ينحجز البند',
      },
      trailing: const Icon(
        LucideIcons.chevronLeft,
        size: 18,
        color: AarastV3Color.textFaint,
      ),
      onTap: () => context.push(
        payment
            ? AppRouter.moneyCostDetails(task.weddingPlanId, costId)
            : AppRouter.moneyCategoryDetails(task.weddingPlanId, itemId!),
      ),
    );
  }
}

enum _TaskAction { handOver, moveDate, link, edit, reopen, cancel, delete }

/// x16: what can be done with a task besides finishing it. A free-text time
/// («بعد العصر») is not offered: a task keeps a day only.
class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.open,
    required this.canLink,
    required this.disabled,
    required this.onSelected,
  });

  final bool open;

  /// R4: linking needs the money in sight.
  final bool canLink;
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
          const SizedBox(width: AarastV3Space.x2),
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
          item(
            _TaskAction.handOver,
            LucideIcons.userPlus,
            context.say('حوّلها لأحد ثاني', 'حوّليها لأحد ثاني'),
          ),
          item(
            _TaskAction.moveDate,
            LucideIcons.calendarClock,
            context.say('غيّر موعدها', 'غيّري موعدها'),
          ),
          if (canLink)
            item(
              _TaskAction.link,
              LucideIcons.link,
              context.say('اربطها ببند أو دفعة', 'اربطيها ببند أو دفعة'),
            ),
        ],
        item(
          _TaskAction.edit,
          LucideIcons.pencil,
          context.say('عدّل المهمة', 'عدّلي المهمة'),
        ),
        if (!open)
          item(
            _TaskAction.reopen,
            LucideIcons.rotateCcw,
            context.say('أعد فتحها', 'أعيدي فتحها'),
          )
        else
          item(_TaskAction.cancel, LucideIcons.x, 'ما نحتاجها', danger: true),
        item(
          _TaskAction.delete,
          LucideIcons.trash2,
          context.say('احذفها', 'احذفيها'),
          danger: true,
        ),
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
      title: '${context.say('تحذف', 'تحذفين')} «$title»؟',
      subtitle: context.say(
        'تنمسح هي وخطواتها. لو بس ما تحتاجها، «ما نحتاجها» تخليها في السجل.',
        'تنمسح هي وخطواتها. لو بس ما تحتاجينها، «ما نحتاجها» تخليها في السجل.',
      ),
      children: [
        JourneyButton(
          key: const ValueKey('task-delete-confirm'),
          label: context.say('احذفها', 'احذفيها'),
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
