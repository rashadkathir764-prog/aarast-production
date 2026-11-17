part of 'money_overview_screen.dart';

// c02 «البنود»'s pieces (D102, D105, D109): the budget against the wedding's
// items, the recorded cost and how complete it is, one row per item, and
// what the four words mean.

typedef _Fact = (String, Color?);

/// One item: its name, what is known about it, and its figure (what was
/// agreed, or the estimate before any agreement).
class _ItemLine extends StatelessWidget {
  const _ItemLine({
    required this.icon,
    required this.title,
    required this.figure,
    required this.onTap,
    this.facts = const [],
    this.state = const [],
    this.under,
    this.figureNote,
    this.private = false,
    this.quiet = false,
    this.figureAccent = false,
    super.key,
  });

  /// The figure is a word to act on («قدّره»), in the plan's colour.
  final bool figureAccent;

  final IconData icon;
  final String title;
  final List<_Fact> facts;
  final List<_Fact> state;
  final _Fact? under;
  final String figure;
  final String? figureNote;

  /// V1 checklist 4.10: every agreement of the item is the reader's alone.
  final bool private;

  /// Not agreed yet: its figure is an estimate.
  final bool quiet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = JourneyType.of(
      JourneyType.small,
      color: AarastV3Color.textMuted,
    );
    Widget line(List<_Fact> parts) => Text.rich(
      TextSpan(
        children: [
          for (final (index, part) in parts.indexed) ...[
            if (index > 0) const TextSpan(text: ' · '),
            TextSpan(
              text: part.$1,
              style: part.$2 == null
                  ? null
                  : TextStyle(color: part.$2, fontWeight: JourneyType.bold),
            ),
          ],
        ],
      ),
      style: muted,
    );
    return AarastPressable(
      onTap: onTap,
      semanticLabel: [
        title,
        if (private) 'خاص بك',
        for (final fact in [...facts, ...state]) fact.$1,
        ?under?.$1,
        figure,
        ?figureNote,
      ].join('، '),
      child: Padding(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JourneyIconTile(
              icon: icon,
              color: quiet ? AarastV3Color.textMuted : context.accent.primary,
              soft: quiet
                  ? AarastV3Color.paperQuiet
                  : context.accent.primarySoft,
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The figure sits on the name's line only: what is known
                  // about the item gets the row's whole width under it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (private) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: AarastV3Space.x1),
                          child: Icon(
                            LucideIcons.lock,
                            key: ValueKey('cost-private-lock'),
                            size: 14,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                        const SizedBox(width: AarastV3Space.x1),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: JourneyType.of(
                            JourneyType.body,
                            weight: JourneyType.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AarastV3Space.x2),
                      // At most 40%: a long figure wraps, the name stays.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              figure,
                              textAlign: TextAlign.end,
                              style: JourneyType.of(
                                JourneyType.body,
                                weight: JourneyType.bold,
                                color: figureAccent
                                    ? context.accent.primary
                                    : quiet
                                    ? AarastV3Color.textMuted
                                    : AarastV3Color.ink,
                              ),
                            ),
                            if (figureNote case final note?)
                              Text(
                                note,
                                style: JourneyType.of(
                                  JourneyType.caption,
                                  color: AarastV3Color.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (facts.isNotEmpty) line(facts),
                  if (state.isNotEmpty) line(state),
                  if (under case final under?) line([under]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The budget bar's thickness: a fixed dimension, like the progress bars'.
const _splitBarHeight = 8.0;

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.parts});

  final List<(num, Color)> parts;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final part in parts)
        if (part.$1 > 0) part,
    ];
    final total = shown.fold<num>(0, (sum, part) => sum + part.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AarastV3Radius.pill),
      child: SizedBox(
        height: _splitBarHeight,
        child: total <= 0
            ? const ColoredBox(color: AarastV3Color.line)
            // Stretched: a coloured box with no child is otherwise drawn
            // at no height at all.
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final part in shown)
                    Expanded(
                      flex: (part.$1 / total * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: part.$2),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AarastV3Space.x1),
        Flexible(
          child: Text(
            text,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The budget against the wedding's items (C1, D105): what is agreed, what
/// is still an estimate, and what is free; or that there is no budget.
class _ItemsBudgetBox extends StatelessWidget {
  const _ItemsBudgetBox({required this.summary, required this.onBudget});

  final MoneySummary summary;

  /// Null: the reader may not change the budget.
  final VoidCallback? onBudget;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currency;
    // RA-MO-168: this card states a difference between its figures.
    String money(Object? value) => _exactFigure(context, value, currency);
    final wedding = summary.expected?.wedding ?? const MoneyExpectedTotals();
    final agreed = moneyValue(wedding.agreed);
    final budget = summary.budget.total;
    if (budget == null) {
      return JourneyBox(
        key: const ValueKey('money-items-no-budget'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.ownerDid(
                'ما حطيت ميزانية',
                'ما حطيتِ ميزانية',
                groom: 'ما في ميزانية بعد',
                bride: 'ما في ميزانية بعد',
              ),
              style: JourneyType.of(
                JourneyType.bodyLarge,
                weight: JourneyType.bold,
              ),
            ),
            const SizedBox(height: AarastV3Space.x1),
            Text(
              [
                if (agreed > 0) 'الاتفاقات ${money(agreed)} بدون المهر.',
                onBudget == null
                    ? 'ما في ميزانية نقارن بها البنود.'
                    : context.say(
                        'حط ميزانية ونقول لك وين أنت منها.',
                        'حطي ميزانية ونقول لك وين أنتِ منها.',
                      ),
              ].join(' '),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            if (onBudget case final onBudget?) ...[
              const SizedBox(height: AarastV3Space.x3),
              JourneyButton.outline(
                key: const ValueKey('money-items-set-budget'),
                label: context.say('حط ميزانية', 'حطي ميزانية'),
                onPressed: onBudget,
              ),
            ],
          ],
        ),
      );
    }
    final total = moneyValue(budget);
    final estimates = moneyValue(wedding.estimateLeft);
    // D114: a budget that holds the groom's mahr is held against it too.
    final mahr = summary.budget.includesMahr
        ? moneyValue(summary.expected?.mahr.expected)
        : 0;
    final expected = moneyValue(wedding.expected) + mahr;
    final free = total > expected ? total - expected : 0;
    final over = expected - total;
    final itemsExpected = moneyValue(wedding.expected);
    final status = mahr > 0
        ? [
            'المهر ${money(mahr)}',
            if (itemsExpected > 0)
              'وبنود العرس ${money(itemsExpected)}'
            else
              'والبنود ما لها تقدير بعد',
            if (over > 0)
              'فوق الميزانية بـ${money(over)}'
            else if (over < 0)
              'باقي منها ${money(-over)}'
            else
              'على قد الميزانية',
          ].join('، ')
        : expected <= 0
        ? context.ownerDid(
            'ما قدّرت البنود بعد، فما نعرف وين أنت من الميزانية',
            'ما قدّرتِ البنود بعد، فما نعرف وين أنتِ من الميزانية',
            groom: 'البنود ما لها تقدير بعد، فما نعرف وين العرس من الميزانية',
            bride: 'البنود ما لها تقدير بعد، فما نعرف وين العرس من الميزانية',
          )
        : over > 0
        ? 'بنود العرس ${money(expected)}، فوق الميزانية بـ${money(over)}'
        : over < 0
        ? 'بنود العرس ${money(expected)}، تحت الميزانية بـ${money(-over)}'
        : 'بنود العرس ${money(expected)}، على قد الميزانية';
    final agreedColour = context.accent.primary;
    final mahrColour = context.accent.primaryDark;
    final estimateColour = context.accent.primary.withValues(alpha: 0.35);
    return JourneyBox(
      key: const ValueKey('money-items-budget'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mahr > 0 ? 'الميزانية، فيها المهر' : 'ميزانية العرس',
                      style: JourneyType.of(
                        JourneyType.detail,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    Text(
                      money(budget),
                      style: JourneyType.of(
                        JourneyType.figure,
                        weight: JourneyType.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (onBudget case final onBudget?)
                JourneyTextAction(
                  key: const ValueKey('money-items-edit-budget'),
                  label: context.say('عدّلها', 'عدّليها'),
                  color: context.accent.primary,
                  onPressed: onBudget,
                ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
          _SplitBar(
            parts: [
              (mahr, mahrColour),
              (agreed, agreedColour),
              (estimates, estimateColour),
              (free, AarastV3Color.line),
            ],
          ),
          const SizedBox(height: AarastV3Space.x2),
          Wrap(
            spacing: AarastV3Space.x3,
            runSpacing: AarastV3Space.x1,
            children: [
              // A zero is no part of the bar: «تقديرات 0» said nothing.
              if (mahr > 0)
                _Legend(color: mahrColour, text: 'المهر ${money(mahr)}'),
              if (agreed > 0)
                _Legend(color: agreedColour, text: 'اتفاقات ${money(agreed)}'),
              if (estimates > 0)
                _Legend(
                  color: estimateColour,
                  text: 'تقديرات ${money(estimates)}',
                ),
              if (free > 0)
                _Legend(color: AarastV3Color.line, text: 'متاح ${money(free)}'),
            ],
          ),
          // Under the budget the legend's «متاح» already says by how much;
          // the line stays where it says more: over it, the mahr in it, or
          // nothing priced yet.
          if (!(over < 0 && mahr <= 0 && expected > 0)) ...[
            const SizedBox(height: AarastV3Space.x2),
            Text(
              status,
              key: const ValueKey('money-items-budget-status'),
              style: JourneyType.of(
                JourneyType.small,
                weight: over > 0 && expected > 0
                    ? JourneyType.bold
                    : FontWeight.w400,
                color: over > 0 && expected > 0
                    ? AarastV3Color.danger
                    : AarastV3Color.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// «ايش الفرق؟»: the four words of money, one meaning each.
class _ItemsExplainSheet extends StatelessWidget {
  const _ItemsExplainSheet();

  @override
  Widget build(BuildContext context) {
    JourneyListRow word(IconData icon, String title, String meaning) =>
        JourneyListRow(
          icon: icon,
          color: context.accent.primary,
          soft: context.accent.primarySoft,
          title: title,
          subtitle: meaning,
          subtitleMaxLines: 4,
        );
    return JourneySheetBody(
      title: 'ايش الفرق؟',
      subtitle: 'أربع كلمات في المال، وكل وحدة لها معنى واحد.',
      children: [
        JourneyList(
          children: [
            word(
              LucideIcons.tag,
              'البند',
              'تكلفة من تكاليف العرس: القاعة، الضيافة، التصوير.',
            ),
            word(
              LucideIcons.pencil,
              'التقدير',
              context.say(
                'كم تتوقع يكلف البند قبل ما تتفق. رقم تقريبي، وما ينحسب عليك.',
                'كم تتوقعين يكلف البند قبل ما تتفقين. رقم تقريبي، وما ينحسب عليكِ.',
              ),
            ),
            word(
              LucideIcons.fileSignature,
              'الاتفاق',
              context.say(
                'مبلغ اتفقت عليه مع أحد. ينحسب عليك، وتدفعه بدفعات أو مرة وحدة.',
                'مبلغ اتفقتِ عليه مع أحد. ينحسب عليكِ، وتدفعينه بدفعات أو مرة وحدة.',
              ),
            ),
            word(
              LucideIcons.banknote,
              'المصروف',
              context.say(
                'شي دفعته كامل مرة وحدة، مثل قات المقيل. يتسجل اتفاق خالص.',
                'شي دفعتيه كامل مرة وحدة، مثل قات المقيل. يتسجل اتفاق خالص.',
              ),
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
        const JourneyNote(
          icon: LucideIcons.scale,
          color: AarastV3Color.textMuted,
          soft: AarastV3Color.paperQuiet,
          // D114: whether the budget holds the mahr is the groom's choice.
          text:
              'الميزانية حدّ لبنود العرس، ويدخل فيها المهر لو اخترت كذا. والتكلفة المسجّلة هي بنود العرس ومعها المهر.',
        ),
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('money-items-explain-done'),
          label: 'فهمت',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
