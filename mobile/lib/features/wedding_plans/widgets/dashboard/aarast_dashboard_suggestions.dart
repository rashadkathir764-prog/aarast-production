part of 'aarast_dashboard_view.dart';

// D72: no fixed steps hold the home. The basics come one at a time in
// «خطوتك الجاية»; the venue and the like are suggestions under it, the
// plan's own open items. Each can be answered «ما أحتاجها» (off this plan,
// back from the money items) or «بعدين» (a week).

/// At most this many suggestions at once, so they guide and do not crowd.
const _maxSuggestions = 3;

/// The plan is still at its start while a basic is missing (the moment's
/// «البداية»): no budget, no item, no task or no guest yet.
bool _startingOut(DashboardSummary summary) {
  if (!summary.permissions.isOwner) return false;
  // The same reading of the budget as b01's first step
  // (dashboardBudgetMissing), so the moment and the step never disagree.
  return dashboardBudgetMissing(summary) ||
      summary.budgetItemsCount == 0 ||
      summary.totalTasks == 0 ||
      summary.guestCount == 0;
}

/// What the home suggests now: whoever manages the money, the open items
/// not answered away.
List<DashboardEssential> _homeSuggestions(DashboardSummary summary) {
  if (!summary.permissions.canManageMoney) return const [];
  return summary.essentials
      .where((item) => item.suggested)
      .take(_maxSuggestions)
      .toList();
}

class _JourneySuggestions extends StatelessWidget {
  const _JourneySuggestions({
    required this.suggestions,
    required this.onOpen,
    required this.onAnswer,
  });

  final List<DashboardEssential> suggestions;
  final ValueChanged<DashboardEssential> onOpen;

  /// «ما أحتاجها» (`NOT_NEEDED`) or «بعدين» (`LATER`).
  final void Function(DashboardEssential item, String choice) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('aarast-dashboard-suggestions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('اقتراحات لعرسك'),
        for (final item in suggestions) ...[
          JourneyBox(
            key: ValueKey('aarast-dashboard-suggestion-${item.key}'),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JourneyListRow(
                  icon: _icon(item.key),
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  title: _title(context, item.key),
                  subtitle: context.say(
                    'ما اتفقت مع أحد بعد',
                    'ما اتفقتِ مع أحد بعد',
                  ),
                  trailing: const Icon(
                    LucideIcons.chevronLeft,
                    size: 18,
                    color: AarastV3Color.textFaint,
                  ),
                  onTap: () => onOpen(item),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AarastV3Space.x2,
                    end: AarastV3Space.x2,
                    bottom: AarastV3Space.x1,
                  ),
                  child: Wrap(
                    children: [
                      JourneyTextAction(
                        key: ValueKey(
                          'aarast-dashboard-suggestion-${item.key}-not-needed',
                        ),
                        label: 'ما أحتاجها',
                        onPressed: () => onAnswer(item, 'NOT_NEEDED'),
                      ),
                      JourneyTextAction(
                        key: ValueKey(
                          'aarast-dashboard-suggestion-${item.key}-later',
                        ),
                        label: 'بعدين',
                        onPressed: () => onAnswer(item, 'LATER'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
      ],
    );
  }

  static String _title(BuildContext context, String key) => switch (key) {
    'VENUE' => context.planWord('القاعة', 'الصالة'),
    'DRESS' => context.planWord('البدلة والكسوة', 'الفستان'),
    'PHOTO' => 'التصوير',
    'GOLD' => 'الذهب والشبكة',
    'HOME' => 'الشقة وتجهيز المنزل',
    'HONEYMOON' => 'شهر العسل',
    _ => key,
  };

  static IconData _icon(String key) => switch (key) {
    'VENUE' => LucideIcons.building2,
    'DRESS' => LucideIcons.shirt,
    'PHOTO' => LucideIcons.camera,
    'GOLD' => LucideIcons.gem,
    'HOME' => LucideIcons.home,
    'HONEYMOON' => LucideIcons.plane,
    _ => LucideIcons.sparkles,
  };
}
