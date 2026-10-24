part of 'aarast_dashboard_view.dart';

/// Tasks, guests and providers, each in its own colour, with the server's
/// counts and what each count is of.
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
            arabicCount(
              s.overdueTasks,
              one: 'وحدة متأخرة',
              two: 'ثنتين متأخرة',
              few: 'متأخرة',
              many: 'متأخرة',
            ),
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
            AarastV3Color.brandAccentStrong,
          )
        : null;
    final guestsNote = s.pendingGuests > 0
        ? (
            '${s.pendingGuests} ${context.say('ما ردّوا', 'ما ردّن')}',
            AarastV3Color.lilac,
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
            AarastV3Color.cobalt,
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
              color: AarastV3Color.brandAccentStrong,
              soft: AarastV3Color.brandAccentSoft,
              value: s.completedTasks,
              of: s.totalTasks == 0
                  ? 'ما في مهام بعد'
                  : 'خلصت من ${s.totalTasks}',
              note: tasksNote,
              progress: s.totalTasks == 0
                  ? null
                  : s.completedTasks / s.totalTasks,
              onTap: onOpenTasks,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HomeTile(
              key: const ValueKey('aarast-dashboard-tile-guests'),
              label: JourneySection.guests.labelOf(context),
              icon: LucideIcons.users,
              color: AarastV3Color.lilac,
              soft: AarastV3Color.lilacSoft,
              value: s.confirmedGuests,
              of: s.guestCount == 0
                  ? context.say('ما في ضيوف بعد', 'ما في ضيفات بعد')
                  : '${context.say('أكدوا', 'أكدن')} من ${s.guestCount}',
              note: guestsNote,
              progress: s.guestCount == 0
                  ? null
                  : s.confirmedGuests / s.guestCount,
              onTap: onOpenGuests,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HomeTile(
              key: const ValueKey('aarast-dashboard-tile-providers'),
              label: 'المزودين',
              icon: LucideIcons.store,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              value: s.acceptedProviders,
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                  JourneyType.caption,
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
                const SizedBox(height: 8),
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
                  color: _colorForItem(item.type, context.accent).$1,
                  soft: _colorForItem(item.type, context.accent).$2,
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

  static (Color, Color) _colorForItem(String type, JourneyAccent accent) {
    final t = type.toUpperCase();
    if (t.contains('TASK')) {
      return (AarastV3Color.brandAccentStrong, AarastV3Color.brandAccentSoft);
    }
    if (t.contains('GUEST')) {
      return (AarastV3Color.lilac, AarastV3Color.lilacSoft);
    }
    if (t.contains('QUOTE') ||
        t.contains('PROVIDER') ||
        t.contains('BOOKING')) {
      return (AarastV3Color.cobalt, AarastV3Color.cobaltSoft);
    }
    return (accent.primary, accent.primarySoft);
  }
}
