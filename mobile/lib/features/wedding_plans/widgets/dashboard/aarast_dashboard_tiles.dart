part of 'aarast_dashboard_view.dart';

/// Tasks, guests and providers, with the server's counts and what each count
/// is of. All three wear the plan's one colour (D68); they do not take a
/// colour per section.
class _JourneyHomeTiles extends StatelessWidget {
  const _JourneyHomeTiles({
    required this.summary,
    required this.onOpenTasks,
    required this.onOpenGuests,
    required this.onOpenProviders,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenProviders;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final tasksNote = s.overdueTasks > 0
        ? (
            // b02 «1 متأخرة».
            '${s.overdueTasks} متأخرة',
            AarastV3Color.danger,
          )
        : s.todayTasks > 0
        ? (
            arabicCount(
              s.todayTasks,
              one: 'وحدة اليوم',
              two: 'ثنتين اليوم',
              few: 'اليوم',
              many: 'اليوم',
            ),
            context.accent.primary,
          )
        : null;
    final guestsNote = s.pendingGuests > 0
        ? (
            '${s.pendingGuests} ${context.say('ما ردّوا', 'ما ردّن')}',
            context.accent.primary,
          )
        : null;
    final providersNote = s.receivedQuotes > 0
        ? (
            arabicCount(
              s.receivedQuotes,
              one: 'عرض ينتظرك',
              two: 'عرضين ينتظرونك',
              few: 'عروض تنتظرك',
              many: 'عرض ينتظرك',
            ),
            context.accent.primary,
          )
        : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _HomeTile(
              key: const ValueKey('aarast-dashboard-tile-tasks'),
              label: 'المهام',
              icon: LucideIcons.listChecks,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              value: s.completedTasks,
              of: s.totalTasks == 0
                  ? 'ما في مهام بعد'
                  : 'من ${arabicCount(s.totalTasks, one: 'مهمة وحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')}',
              note: tasksNote,
              progress: s.totalTasks == 0
                  ? null
                  : s.completedTasks / s.totalTasks,
              onTap: onOpenTasks,
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: _HomeTile(
              key: const ValueKey('aarast-dashboard-tile-guests'),
              label: JourneySection.guests.labelOf(context),
              icon: LucideIcons.users,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              value: s.confirmedGuests,
              of: s.guestCount == 0
                  ? context.planWord('ما في ضيوف بعد', 'ما في ضيفات بعد')
                  : '${context.say('أكدوا', 'أكدن')} من ${s.guestCount}',
              note: guestsNote,
              progress: s.guestCount == 0
                  ? null
                  : s.confirmedGuests / s.guestCount,
              onTap: onOpenGuests,
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: _HomeTile(
              key: const ValueKey('aarast-dashboard-tile-providers'),
              label: 'المزودين',
              icon: LucideIcons.store,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              // D60: the server's one count, the board's «محجوز N» too.
              value: s.bookedServices.count,
              of: 'محجوز',
              note: providersNote,
              progress: null,
              onTap: onOpenProviders,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.soft,
    required this.value,
    required this.of,
    required this.note,
    required this.progress,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color soft;
  final int value;
  final String of;
  final (String, Color)? note;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label، $value $of${note == null ? '' : '، ${note!.$1}'}',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: Container(
          padding: const EdgeInsets.all(AarastV3Space.x3),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(AarastV3Radius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: AarastV3Space.x1),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.detail,
                        weight: JourneyType.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x2),
              Text(
                '$value',
                style: JourneyType.of(
                  JourneyType.display,
                  weight: JourneyType.bold,
                  height: 1.1,
                ),
              ),
              Text(
                of,
                style: JourneyType.of(
                  JourneyType.label,
                  color: AarastV3Color.textMuted,
                ),
              ),
              if (note != null)
                Text(
                  note!.$1,
                  style: JourneyType.of(
                    JourneyType.caption,
                    weight: JourneyType.bold,
                    color: note!.$2,
                  ),
                ),
              const Spacer(),
              if (progress != null) ...[
                const SizedBox(height: AarastV3Space.x2),
                JourneyBar(
                  value: progress!.clamp(0.0, 1.0),
                  color: color,
                  track: AarastV3Color.paper,
                  height: 5,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «بعدها»: the server's other important items, after the next step.
class _JourneyAfterwards extends StatelessWidget {
  const _JourneyAfterwards({required this.items, required this.onOpen});

  final List<DashboardImportantItem> items;
  final ValueChanged<DashboardImportantItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('aarast-dashboard-afterwards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('بعدها'),
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              for (final item in items)
                JourneyListRow(
                  icon: _iconForItem(item.type),
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  title: item.title,
                  subtitle: item.subtitle,
                  trailing: const Icon(
                    LucideIcons.chevronLeft,
                    size: 18,
                    color: AarastV3Color.textFaint,
                  ),
                  onTap: () => onOpen(item),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconForItem(String type) {
    final t = type.toUpperCase();
    if (t.contains('PAYMENT') || t.contains('COST') || t.contains('BUDGET')) {
      return LucideIcons.wallet;
    }
    if (t.contains('TASK')) return LucideIcons.listChecks;
    if (t.contains('QUOTE') ||
        t.contains('PROVIDER') ||
        t.contains('BOOKING')) {
      return LucideIcons.store;
    }
    if (t.contains('GUEST')) return LucideIcons.users;
    return LucideIcons.sparkles;
  }
}
