part of 'aarast_dashboard_view.dart';

// b01: a new plan's three first steps. The mahr step waits for the
// agreement section (C1), so there are three. Each step is done by a server
// fact: a budget, a secured venue (C24), a first guest.

class _SetupStep {
  const _SetupStep({
    required this.title,
    required this.doneLine,
    required this.todoLine,
    required this.icon,
    required this.color,
    required this.soft,
    required this.done,
    required this.onOpen,
  });

  final String title;
  final String doneLine;
  final String todoLine;
  final IconData icon;
  final Color color;
  final Color soft;
  final bool done;
  final VoidCallback onOpen;
}

/// Whether the home still leads with the first steps: only the plan's owner
/// sets them, and only until all three are done.
bool _showsSetupSteps(DashboardSummary summary) {
  if (!summary.permissions.isOwner) return false;
  return !(_budgetIsSet(summary) &&
      summary.venueSecured &&
      summary.guestCount > 0);
}

/// b01 «7 مليون لعرسك»: the budget without the currency.
String _budgetWords(double budget, String currency) {
  final parts = compactMoneyParts(budget, currencyCode: currency);
  final unit = parts.millionUnit;
  return unit == null ? parts.plainText : '${parts.number} $unit';
}

bool _budgetIsSet(DashboardSummary summary) {
  final budget = dashboardAmount(summary.totalBudgetForDisplay);
  return budget != null && budget > 0;
}

class _JourneySetupSteps extends StatelessWidget {
  const _JourneySetupSteps({
    required this.summary,
    required this.onOpenMoney,
    required this.onOpenProviders,
    required this.onOpenGuests,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;

  @override
  Widget build(BuildContext context) {
    final budget = dashboardAmount(summary.totalBudgetForDisplay);
    final steps = [
      _SetupStep(
        title: 'ميزانيتك',
        doneLine: budget == null
            ? 'محددة'
            : '${_budgetWords(budget, summary.currency)} لعرسك، والمهر لحاله',
        todoLine: context.say(
          'رقم تقريبي يكفي، وتقدر تغيّره بعدين',
          'رقم تقريبي يكفي، وتقدرين تغيّرينه بعدين',
        ),
        icon: LucideIcons.wallet,
        color: context.accent.primary,
        soft: context.accent.primarySoft,
        done: _budgetIsSet(summary),
        onOpen: onOpenMoney,
      ),
      _SetupStep(
        title: context.say('القاعة', 'الصالة'),
        doneLine: 'محجوزة',
        todoLine: context.say(
          'أهم حجز، والقاعات تمتلي بدري',
          'أهم حجز، والصالات تمتلي بدري',
        ),
        icon: LucideIcons.building2,
        color: AarastV3Color.cobalt,
        soft: AarastV3Color.cobaltSoft,
        done: summary.venueSecured,
        onOpen: onOpenProviders,
      ),
      _SetupStep(
        title: context.say('ضيوفك', 'ضيفاتك'),
        doneLine: arabicCount(
          summary.guestCount,
          one: context.say('ضيف واحد', 'ضيفة وحدة'),
          two: context.say('ضيفين', 'ضيفتين'),
          few: context.say('ضيوف', 'ضيفات'),
          many: context.say('ضيف', 'ضيفة'),
        ),
        todoLine: 'من جهات الاتصال بضغطة',
        icon: LucideIcons.users,
        color: AarastV3Color.lilac,
        soft: AarastV3Color.lilacSoft,
        done: summary.guestCount > 0,
        onOpen: onOpenGuests,
      ),
    ];
    final doneCount = steps.where((step) => step.done).length;
    final current = steps.indexWhere((step) => !step.done);

    return Column(
      key: const ValueKey('aarast-dashboard-setup-steps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'ثلاث خطوات وعرسك منظم',
            style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'خلصت $doneCount من ${steps.length}',
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.mint,
              ),
            ),
            const SizedBox(width: 12),
            // b01: done green, the current step in the plan's colour, the
            // rest white.
            for (var index = 0; index < steps.length; index++) ...[
              if (index > 0) const SizedBox(width: 5),
              Expanded(
                child: Container(
                  key: ValueKey('aarast-dashboard-setup-bar-$index'),
                  height: 6,
                  decoration: BoxDecoration(
                    color: steps[index].done
                        ? AarastV3Color.mint
                        : index == current
                        ? context.accent.primary
                        : AarastV3Color.paper,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < steps.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _SetupStepCard(
            step: steps[index],
            number: index + 1,
            isCurrent: index == current,
          ),
        ],
      ],
    );
  }
}

class _SetupStepCard extends StatelessWidget {
  const _SetupStepCard({
    required this.step,
    required this.number,
    required this.isCurrent,
  });

  final _SetupStep step;
  final int number;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final eyebrow = step.done ? 'خلصت · الخطوة $number' : 'الخطوة $number';
    final line = step.done ? step.doneLine : step.todoLine;
    return Semantics(
      button: true,
      label: '$eyebrow، ${step.title}، $line',
      onTap: step.onOpen,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: step.onOpen,
        borderRadius: BorderRadius.circular(22),
        child: JourneyBox(
          key: ValueKey('aarast-dashboard-setup-step-$number'),
          color: isCurrent ? AarastV3Color.paper : AarastV3Color.paperQuiet,
          borderColor: isCurrent ? context.accent.primary : null,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              step.done
                  ? const JourneyIconTile(
                      icon: LucideIcons.check,
                      color: AarastV3Color.onPrimary,
                      soft: AarastV3Color.mint,
                    )
                  : JourneyIconTile(
                      icon: step.icon,
                      color: step.color,
                      soft: step.soft,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: JourneyType.of(
                        JourneyType.caption,
                        weight: JourneyType.bold,
                        color: step.done
                            ? AarastV3Color.mint
                            : AarastV3Color.textMuted,
                      ),
                    ),
                    Text(
                      step.title,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                        color: step.done
                            ? AarastV3Color.textMuted
                            : AarastV3Color.ink,
                      ),
                    ),
                    Text(
                      line,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                JourneyButton(
                  label: context.say('كمّل', 'كمّلي'),
                  onPressed: step.onOpen,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
