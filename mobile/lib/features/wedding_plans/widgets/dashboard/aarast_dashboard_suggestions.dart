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

/// The open items in one card, a row each (Rashad 2026-11-17: three cards
/// filled a screen, and their bold «ما أحتاجها» and «بعدين» stood louder
/// than opening the item). The two answers are behind each row's «⋯».
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
        // Not «اقتراحات»: these are the wedding's own items still open.
        JourneySectionTitle(
          context.say('ما اتفقت عليه بعد', 'ما اتفقتِ عليه بعد'),
        ),
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              for (final item in suggestions)
                JourneyListRow(
                  key: ValueKey('aarast-dashboard-suggestion-${item.key}'),
                  icon: _icon(item.key),
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  title: _title(context, item.key),
                  subtitle: context.say(
                    'ما اتفقت مع أحد بعد',
                    'ما اتفقتِ مع أحد بعد',
                  ),
                  // RA-MO-361: «⋯» is a button of its own beside the row's,
                  // with its own tap: the row's one label hid it, and its
                  // label hid the IconButton's tap.
                  trailingIsAction: true,
                  trailing: Semantics(
                    container: true,
                    button: true,
                    label: 'خيارات ${_title(context, item.key)}',
                    onTap: () => _answer(context, item),
                    excludeSemantics: true,
                    child: IconButton(
                      key: ValueKey(
                        'aarast-dashboard-suggestion-${item.key}-more',
                      ),
                      onPressed: () => _answer(context, item),
                      icon: const Icon(
                        LucideIcons.moreHorizontal,
                        size: AarastV3Icon.md,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                  onTap: () => onOpen(item),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _answer(BuildContext context, DashboardEssential item) async {
    final title = _title(context, item.key);
    final choice = await showJourneySheet<String>(
      context: context,
      builder: (sheetContext) {
        // RA-MO-361: each label below hides its button's tap with its
        // words, so the tap is said with the label.
        void notNeeded() => Navigator.of(sheetContext).pop('NOT_NEEDED');
        void later() => Navigator.of(sheetContext).pop('LATER');
        return JourneySheetBody(
          title: title,
          subtitle: context.say(
            'تشيلها من الرئيسية، وترجع من بنود المال.',
            'تشيلينها من الرئيسية، وترجع من بنود المال.',
          ),
          children: [
            // RA-MO-164: each answer names the item it answers.
            Semantics(
              button: true,
              label: 'ما أحتاج $title',
              onTap: notNeeded,
              excludeSemantics: true,
              child: JourneyButton(
                key: ValueKey(
                  'aarast-dashboard-suggestion-${item.key}-not-needed',
                ),
                label: 'ما أحتاجها',
                expand: true,
                onPressed: notNeeded,
              ),
            ),
            const SizedBox(height: AarastV3Space.x2),
            Semantics(
              button: true,
              label: '$title بعدين',
              onTap: later,
              excludeSemantics: true,
              child: JourneyButton(
                key: ValueKey('aarast-dashboard-suggestion-${item.key}-later'),
                label: 'بعدين (أسبوع)',
                expand: true,
                background: AarastV3Color.paperQuiet,
                foreground: AarastV3Color.ink,
                onPressed: later,
              ),
            ),
          ],
        );
      },
    );
    if (choice != null) onAnswer(item, choice);
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
