part of 'aarast_dashboard_view.dart';

// b01: a new plan's first steps. Each step is done by a server fact: a
// budget, the mahr recorded (a06, C1; a groom's or a bride's plan only), a
// secured venue (C24), a first guest. The home leaves the steps once the
// budget, the venue and a guest are there: the mahr is a step to take, and
// «ما اتفقنا بعد» is a real answer that must not hold the home back.

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
    this.mahr,
    this.onOpenMahr,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;

  /// The plan's mahr step, when the plan is a groom's or a bride's and the
  /// money is read; null leaves the step out.
  final DashboardHomeMahr? mahr;
  final VoidCallback? onOpenMahr;

  @override
  Widget build(BuildContext context) {
    final budget = dashboardAmount(summary.totalBudgetForDisplay);
    final mahr = this.mahr;
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
      if (mahr != null)
        _SetupStep(
          title: 'المهر',
          // b01: «3 مليون لأهل العروسة · سلّمت 2», «3 مليون من العريس ·
          // استلمتِ 2».
          doneLine: mahr.side == MahrHomeSide.pays
              ? '${mahrHomeWords(mahr.total)} لأهل العروسة · '
                    '${context.say('سلّمت', 'سلّمتِ')} ${mahrHomeNumber(mahr.settled)}'
              : '${mahrHomeWords(mahr.total)} من العريس · '
                    '${context.say('استلمت', 'استلمتِ')} ${mahrHomeNumber(mahr.settled)}',
          todoLine: mahr.side == MahrHomeSide.pays
              ? context.say(
                  'اللي بتسلّمه لأهل العروسة، نحسبه لحاله',
                  'اللي بتسلّمينه لأهل العروسة، نحسبه لحاله',
                )
              : context.say(
                  'اللي بتستلمه من العريس، نحسبه لحاله',
                  'اللي بتستلمينه من العريس، نحسبه لحاله',
                ),
          icon: LucideIcons.heartHandshake,
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
          done: mahr.recorded,
          onOpen: mahr.recorded ? onOpenMoney : (onOpenMahr ?? onOpenMoney),
        ),
      _SetupStep(
        title: context.planWord('القاعة', 'الصالة'),
        doneLine: 'محجوزة',
        todoLine: context.planWord(
          'أهم حجز، والقاعات تمتلي بدري',
          'أهم حجز، والصالات تمتلي بدري',
        ),
        icon: LucideIcons.building2,
        color: context.accent.primary,
        soft: context.accent.primarySoft,
        done: summary.venueSecured,
        onOpen: onOpenProviders,
      ),
      _SetupStep(
        title: context.planWord('ضيوفك', 'ضيفاتك'),
        doneLine: arabicCount(
          summary.guestCount,
          one: context.planWord('ضيف واحد', 'ضيفة وحدة'),
          two: context.planWord('ضيفين', 'ضيفتين'),
          few: context.planWord('ضيوف', 'ضيفات'),
          many: context.planWord('ضيف', 'ضيفة'),
        ),
        todoLine: 'من جهات الاتصال بضغطة',
        icon: LucideIcons.users,
        color: context.accent.primary,
        soft: context.accent.primarySoft,
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
            steps.length == 4
                ? 'أربع خطوات وعرسك منظم'
                : 'ثلاث خطوات وعرسك منظم',
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
