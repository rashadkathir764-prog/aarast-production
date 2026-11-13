part of 'money_overview_screen.dart';

// c05 «من وين» (the owner's, D102 D103 D104 D108): what he holds now and
// how («وصلك − صرفت منها»), against what is on him and the loans he owes,
// with the one cover sentence; what reached him, what is promised (and
// whether it arrived), the family person by person, and the loans with
// their way back. Every figure is the server's (C2), or the phone's twin
// for a plan kept on the phone.

class _MoneyFundingTab extends StatefulWidget {
  const _MoneyFundingTab({
    required this.planId,
    required this.summary,
    required this.onHowCounted,
    required this.onChanged,
  });

  final String planId;
  final MoneySummary summary;
  final VoidCallback onHowCounted;

  /// Reads the money again after a source changed (the cover follows it).
  final Future<void> Function() onChanged;

  @override
  State<_MoneyFundingTab> createState() => _MoneyFundingTabState();
}

class _MoneyFundingTabState extends State<_MoneyFundingTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sources = context.read<FundingProvider?>();
      if (sources != null && sources.loadedPlanId != widget.planId) {
        sources.load(widget.planId);
      }
    });
  }

  void _openSources([String? sourceId]) =>
      context.push(AppRouter.moneyFunding(widget.planId, sourceId: sourceId));

  /// «وصلت؟»: said once, then the money is read again.
  Future<void> _arrived(FundingSource source) async {
    final currency = widget.summary.currency;
    final yes = await showJourneySheet<bool>(
      context: context,
      builder: (sheet) => JourneySheetBody(
        title: 'وصلت ${source.sourceName}؟',
        subtitle:
            '${_figure(sheet, source.amount, currency)} تنحسب في «معك» من اليوم.',
        children: [
          JourneyButton(
            key: const ValueKey('money-pledge-arrived-yes'),
            label: 'إيه، وصلت',
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Center(
            child: JourneyTextAction(
              label: 'لا، لسّا',
              color: AarastV3Color.textMuted,
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final funding = context.read<FundingProvider>();
    final ok = await funding.markReceived(source);
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        funding.errorMessage ?? 'ما انحفظت. جرّب مرة ثانية.',
      );
      return;
    }
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final currency = summary.currency;
    String money(Object? value) => _figure(context, value, currency);
    final funding = summary.funding ?? const MoneyFundingSummary();
    final provider = context.watch<FundingProvider?>();
    final loaded = provider?.loadedPlanId == widget.planId
        ? provider!.sources
        : const <FundingSource>[];
    final received = [
      for (final source in loaded)
        if (!source.isPledged && source.isMahr) source,
      for (final source in loaded)
        if (!source.isPledged && !source.isMahr) source,
    ];
    final pledged = [
      for (final source in loaded)
        if (source.isPledged) source,
    ];
    final loans = [
      for (final source in loaded)
        if (source.isLoan && !source.isPledged) source,
    ];
    final family = summary.family ?? const <MoneyContributor>[];
    final nothing = funding.sourcesCount == 0 && loaded.isEmpty;
    num sum(Iterable<FundingSource> sources) => sources.fold<num>(
      0,
      (total, source) => total + moneyValue(source.amount),
    );

    if (nothing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider != null && provider.isLoading)
            const JourneyListState(
              phase: JourneyListPhase.loading,
              section: JourneySection.money,
            )
          else
            JourneyListState(
              key: const ValueKey('money-sources-empty'),
              phase: provider?.loadErrorMessage == null
                  ? JourneyListPhase.empty
                  : JourneyListPhase.error,
              section: JourneySection.money,
              emptyIcon: LucideIcons.piggyBank,
              emptyTitle: context.say(
                'من وين بتجيب فلوس العرس؟',
                'من وين بتجيبين فلوس العرس؟',
              ),
              emptyAction: context.say('سجّل أول مصدر', 'سجّلي أول مصدر'),
              onEmptyAction: _openSources,
              onRetry: () => provider?.load(widget.planId),
            ),
          ..._family(context, family, currency),
        ],
      );
    }

    final coverage = summary.coverage;
    final words = coverage == null
        ? null
        : moneyCoverWords(
            context,
            coverage,
            (value) => _figure(context, value, summary.currency),
          );
    final estimates = moneyValue(coverage?.estimatesLeft);
    final afterEstimates = moneyValue(coverage?.endAfterEstimates);
    final out = moneyValue(funding.spent) + moneyValue(funding.loanRepaid);
    // RA-MO-171 (D86): the head and the sections under it read one list.
    final head = funding.headOn(loaded.isEmpty ? null : sum(received));
    final receivedTotal = head.received;
    final cash = head.cash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // «معك الحين» and how it came to be (D104).
        JourneyBox(
          key: const ValueKey('money-cash-hero'),
          padding: const EdgeInsets.all(AarastV3Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'معك الحين',
                style: JourneyType.of(
                  JourneyType.detail,
                  color: AarastV3Color.textMuted,
                ),
              ),
              Text(
                money(cash),
                key: const ValueKey('money-cash-figure'),
                style: JourneyType.of(
                  JourneyType.headline,
                  weight: JourneyType.bold,
                  color: context.accent.primaryDark,
                ),
              ),
              Text(
                'وصلك ${money(receivedTotal)} − ${context.say('صرفت', 'صرفتِ')} منها ${money(out)}',
                key: const ValueKey('money-cash-how'),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const SizedBox(height: AarastV3Space.x3),
              const Divider(height: 1, color: AarastV3Color.line),
              const SizedBox(height: AarastV3Space.x3),
              Wrap(
                spacing: AarastV3Space.x3,
                runSpacing: AarastV3Space.x1,
                children: [
                  Text(
                    '${context.say('عليك', 'عليكِ')} من العرس ${money(summary.outstanding?.owner ?? summary.costs.outstanding)}',
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                    ),
                  ),
                  if (moneyValue(funding.loanOutstanding) > 0)
                    Text(
                      '${context.ownerDid('سلف ترجعها', 'سلف ترجعينها', groom: 'سلف يرجعها العريس', bride: 'سلف ترجعها العروسة')} ${money(funding.loanOutstanding)}',
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                      ),
                    ),
                ],
              ),
              if (words != null) ...[
                const SizedBox(height: AarastV3Space.x2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      words.ok
                          ? LucideIcons.checkCircle2
                          : LucideIcons.alertCircle,
                      size: 18,
                      color: words.ok
                          ? AarastV3Color.mint
                          : AarastV3Color.danger,
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: Text(
                        words.main,
                        key: const ValueKey('money-sources-cover'),
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                          color: words.ok
                              ? AarastV3Color.ink
                              : AarastV3Color.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                if (words.sub.isNotEmpty)
                  Text(
                    words.sub,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                // The estimates' «if» (D105): not agreed yet, not on him.
                if (estimates > 0 && coverage != null)
                  Text(
                    moneyIfEstimatesWords(context, coverage, money),
                    key: const ValueKey('money-sources-if'),
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: afterEstimates < 0
                          ? JourneyType.bold
                          : FontWeight.w400,
                      color: afterEstimates < 0
                          ? AarastV3Color.danger
                          : AarastV3Color.textMuted,
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyTextAction(
                    key: const ValueKey('money-sources-how-counted'),
                    label: 'كيف حسبناها؟',
                    color: context.accent.primary,
                    onPressed: widget.onHowCounted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (received.isNotEmpty) ...[
          JourneySectionTitle(
            'وصلك',
            action: money(sum(received)),
            actionColor: AarastV3Color.textMuted,
          ),
          JourneyBox(
            key: const ValueKey('money-sources-received'),
            padding: EdgeInsets.zero,
            child: JourneyList(
              children: [
                for (final source in received)
                  JourneyListRow(
                    key: ValueKey('money-source-${source.id}'),
                    icon: fundingKindIcon(source.kind),
                    color: context.accent.primary,
                    soft: context.accent.primarySoft,
                    title: source.sourceName,
                    subtitle: [
                      // Its kind, unless its name already says it.
                      if (fundingKindChoice(
                            source.kind,
                            context.journeyProfile,
                          ) !=
                          source.sourceName.trim())
                        fundingKindChoice(source.kind, context.journeyProfile),
                      if (source.isLoan)
                        context.say('ترجعها', 'ترجعينها')
                      else if (source.note?.trim().isNotEmpty == true)
                        source.note!.trim(),
                    ].join(' · '),
                    trailing: Text(
                      money(source.amount),
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                    onTap: () => _openSources(source.id),
                  ),
              ],
            ),
          ),
        ],
        if (pledged.isNotEmpty) ...[
          JourneySectionTitle(
            'موعود لك',
            action: money(sum(pledged)),
            actionColor: AarastV3Color.textMuted,
          ),
          JourneyBox(
            key: const ValueKey('money-sources-pledged'),
            padding: EdgeInsets.zero,
            child: JourneyList(
              children: [
                for (final source in pledged)
                  _PledgeRow(
                    key: ValueKey('money-source-${source.id}'),
                    source: source,
                    amount: money(source.amount),
                    onOpen: () => _openSources(source.id),
                    onArrived: () => _arrived(source),
                  ),
              ],
            ),
          ),
        ],
        ..._family(context, family, currency),
        if (loans.isNotEmpty) ...[
          JourneySectionTitle(
            'ديون السلف',
            action: money(funding.loanOutstanding),
            actionColor: AarastV3Color.textMuted,
          ),
          for (final loan in loans) ...[
            _LoanTrack(
              key: ValueKey('money-loan-track-${loan.id}'),
              loan: loan,
              currency: currency,
              onTap: () => _openSources(loan.id),
            ),
            const SizedBox(height: AarastV3Space.x2),
          ],
        ],
        const SizedBox(height: AarastV3Space.x2),
        Center(
          child: JourneyTextAction(
            key: const ValueKey('money-sources-add'),
            label: context.say('أضف مصدر', 'أضيفي مصدر'),
            icon: LucideIcons.plus,
            color: context.accent.primary,
            onPressed: _openSources,
          ),
        ),
      ],
    );
  }

  /// One person: what reached him from them and what they paid to the
  /// shops for him (to date); before any of it, what they promised.
  Widget _personRow(
    BuildContext context,
    int index,
    MoneyContributor person,
    String Function(Object? value) money,
    JourneyProfile profile,
  ) {
    final done = moneyValue(person.gave) + moneyValue(person.paid);
    final promised = moneyValue(person.promised);
    final facts = [
      if (moneyValue(person.gave) > 0) 'وصلك ${money(person.gave)}',
      if (moneyValue(person.paid) > 0) 'مدفوع للمحلات ${money(person.paid)}',
      if (moneyValue(person.left) > 0) 'باقي ${money(person.left)}',
      if (promised > 0 && done > 0) 'موعود ${money(promised)}',
    ];
    return JourneyListRow(
      key: ValueKey('money-family-$index'),
      icon: LucideIcons.users,
      color: AarastV3Color.lilac,
      soft: AarastV3Color.lilacSoft,
      title:
          person.name ??
          payerLabel(
            person.payer,
            null,
            bridePlan: profile.isBride,
            owner: profile.readerIsOwner,
          ),
      subtitle: facts.isEmpty ? 'ما وصل شي بعد' : facts.join(' · '),
      subtitleMaxLines: 2,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            money(done > 0 ? done : promised),
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
          Text(
            done > 0 ? 'لين الحين' : 'موعود',
            style: JourneyType.of(
              JourneyType.caption,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
      onTap: () => context.push(AppRouter.moneyPayers(widget.planId)),
    );
  }

  /// D108: the family, person by person.
  List<Widget> _family(
    BuildContext context,
    List<MoneyContributor> family,
    String currency,
  ) {
    if (family.isEmpty) return const [];
    String money(Object? value) => _figure(context, value, currency);
    final profile = context.journeyProfile;
    return [
      const JourneySectionTitle('مساهمات الأهل'),
      JourneyBox(
        key: const ValueKey('money-family'),
        padding: EdgeInsets.zero,
        child: JourneyList(
          children: [
            for (final (index, person) in family.indexed)
              _personRow(context, index, person, money, profile),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: AarastV3Space.x2),
        child: Text(
          'اللي وصلك منهم داخل في «وصلك». واللي دفعوه للمحلات مباشرة ما مر من جيبك، فما ينحسب فيه.',
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ),
    ];
  }
}

/// Promised money: when it is due (or that its day passed), and «وصلت؟».
class _PledgeRow extends StatelessWidget {
  const _PledgeRow({
    required this.source,
    required this.amount,
    required this.onOpen,
    required this.onArrived,
    super.key,
  });

  final FundingSource source;
  final String amount;
  final VoidCallback onOpen;
  final VoidCallback onArrived;

  @override
  Widget build(BuildContext context) {
    final day = source.expectedAt;
    // The server says it is late (C2); a day already past says so too.
    final late = source.isOverdue || (day != null && daysUntilPlanDay(day) < 0);
    return JourneyListRow(
      icon: fundingKindIcon(source.kind),
      color: late ? AarastV3Color.danger : AarastV3Color.lilac,
      soft: late ? AarastV3Color.dangerSoft : AarastV3Color.lilacSoft,
      title: source.sourceName,
      subtitle: late
          ? (day == null
                ? 'تأخرت عن موعدها'
                : 'موعدها كان ${formatArabicDayMonth(day)}')
          : day == null
          ? 'ما تحدد موعدها'
          : 'موعدها ${formatArabicDayMonth(day)}',
      subtitleMaxLines: 2,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amount,
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
          JourneyTextAction(
            key: ValueKey('money-pledge-arrived-${source.id}'),
            label: 'وصلت؟',
            color: context.accent.primary,
            onPressed: onArrived,
          ),
        ],
      ),
      onTap: onOpen,
    );
  }
}

/// A loan and its way back: what is left, the next payment, when it ends,
/// each payment ticked when paid.
class _LoanTrack extends StatelessWidget {
  const _LoanTrack({
    required this.loan,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final FundingSource loan;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String money(Object? value) => _figure(context, value, currency);
    final repayments =
        [
          for (final repayment in loan.repayments)
            if (!repayment.isCancelled) repayment,
        ]..sort(
          (a, b) => (a.dueDate ?? DateTime(9999)).compareTo(
            b.dueDate ?? DateTime(9999),
          ),
        );
    final open = [
      for (final repayment in repayments)
        if (!repayment.isPaid) repayment,
    ];
    final next = open.firstOrNull;
    final last = open.lastOrNull;
    final left = loan.loanLeft;
    return AarastPressable(
      onTap: onTap,
      semanticLabel: '${loan.sourceName}، باقي ${money(left)}',
      child: JourneyBox(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loan.sourceName,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AarastV3Space.x2),
                Flexible(
                  child: Text(
                    'باقي ${money(left)}',
                    textAlign: TextAlign.end,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              repayments.isEmpty
                  ? context.say(
                      'ما حطيت لها مواعيد سداد',
                      'ما حطيتِ لها مواعيد سداد',
                    )
                  : next == null
                  ? context.say('خلّصتها', 'خلّصتيها')
                  : [
                      if (next.dueDate case final day?)
                        'الجاية ${formatArabicDayMonth(day)}',
                      if (last?.dueDate case final day?)
                        'تخلص في ${arabicMonthName(day.month)}',
                    ].join(' · '),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            if (repayments.isNotEmpty) ...[
              const SizedBox(height: AarastV3Space.x2),
              Wrap(
                spacing: AarastV3Space.x2,
                runSpacing: AarastV3Space.x1,
                children: [
                  for (final repayment in repayments)
                    JourneyTag(
                      label: [
                        if (repayment.isPaid) '✓',
                        if (repayment.dueDate case final day?)
                          arabicMonthName(day.month),
                        money(repayment.amount),
                      ].join(' '),
                      color: repayment.isPaid
                          ? AarastV3Color.mint
                          : AarastV3Color.textMuted,
                      soft: repayment.isPaid
                          ? AarastV3Color.mintSoft
                          : AarastV3Color.paperQuiet,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
