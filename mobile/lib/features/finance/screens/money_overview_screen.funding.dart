part of 'money_overview_screen.dart';

// c05 «من وين» (the owner's): what reached you and what is promised, from
// the server's totals, then each source with its state. Spent per source is
// not drawn (payments carry no source), nor the rafd note.

class _MoneyFundingTab extends StatefulWidget {
  const _MoneyFundingTab({
    required this.planId,
    required this.funding,
    required this.currency,
  });

  final String planId;
  final MoneyFundingSummary funding;
  final String currency;

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

  @override
  Widget build(BuildContext context) {
    final funding = widget.funding;
    final currency = widget.currency;
    final sources = context.watch<FundingProvider?>();
    final loaded = sources?.loadedPlanId == widget.planId
        ? sources!.sources
        : const <FundingSource>[];
    // c05 as drawn: what reached her first, the mahr leading it, then what
    // is still promised, each kept in the order it was recorded.
    final list = [
      for (final source in loaded)
        if (!source.isPledged && source.isMahr) source,
      for (final source in loaded)
        if (!source.isPledged && !source.isMahr) source,
      for (final source in loaded)
        if (source.isPledged) source,
    ];
    void open() => context.push(AppRouter.moneyFunding(widget.planId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FundingTotal(
                  label: 'وصلك',
                  amount: _amount(context, funding.received, currency),
                  // c05 «صرفت 4.6 · معك 2.9»: what came in is what the
                  // owner's own money paid plus what is in hand (D59).
                  line:
                      '${context.say('صرفت', 'صرفتِ')} ${_amount(context, funding.spent, currency)} · '
                      'معك ${_amount(context, funding.availableCash, currency)}',
                  color: context.accent.primary,
                  background: AarastV3Color.paper,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FundingTotal(
                  label: 'موعود لك',
                  amount: _amount(context, funding.pledged, currency),
                  // Counted in «ومع الموعود ناقصك», so it is not «not
                  // counted»: it has only not arrived.
                  line: 'ما وصل بعد',
                  color: AarastV3Color.lilac,
                  background: AarastV3Color.lilacSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        JourneySectionTitle(
          'المصادر',
          action: context.say('أضف مصدر', 'أضيفي مصدر'),
          onAction: open,
        ),
        if (sources == null || sources.isLoading && list.isEmpty)
          const JourneyListState(
            phase: JourneyListPhase.loading,
            section: JourneySection.money,
          )
        else if (list.isEmpty)
          JourneyListState(
            phase: sources.loadErrorMessage == null
                ? JourneyListPhase.empty
                : JourneyListPhase.error,
            section: JourneySection.money,
            emptyIcon: LucideIcons.piggyBank,
            emptyTitle: context.say(
              'ما سجلت من وين بتجيب الفلوس',
              'ما سجلتِ من وين بتجيبين الفلوس',
            ),
            emptyAction: context.say('أضف أول مصدر', 'أضيفي أول مصدر'),
            onEmptyAction: open,
            onRetry: () => sources.load(widget.planId),
          )
        else
          JourneyBox(
            padding: EdgeInsets.zero,
            child: JourneyList(
              children: [
                for (final source in list)
                  _FundingSourceRow(
                    source: source,
                    amount: _amount(context, source.amount, currency),
                    // The source itself, not the top of «من وين».
                    onTap: () => context.push(
                      AppRouter.moneyFunding(
                        widget.planId,
                        sourceId: source.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FundingTotal extends StatelessWidget {
  const _FundingTotal({
    required this.label,
    required this.amount,
    required this.line,
    required this.color,
    required this.background,
  });

  final String label;
  final String amount;
  final String line;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      color: background,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              amount,
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
                color: color,
              ),
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
    );
  }
}

class _FundingSourceRow extends StatelessWidget {
  const _FundingSourceRow({
    required this.source,
    required this.amount,
    required this.onTap,
  });

  final FundingSource source;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final received = source.status == FundingStatus.received;
    final (icon, color, soft) = switch (source.kind) {
      FundingKind.savings => (
        LucideIcons.piggyBank,
        context.accent.primary,
        context.accent.primarySoft,
      ),
      FundingKind.familySupport => (
        LucideIcons.heartHandshake,
        context.accent.primary,
        context.accent.primarySoft,
      ),
      FundingKind.loan => (
        LucideIcons.user,
        AarastV3Color.brandAccentStrong,
        AarastV3Color.brandAccentSoft,
      ),
      // c05: the mahr from the groom, received or still to come.
      FundingKind.mahr =>
        received
            ? (
                LucideIcons.piggyBank,
                context.accent.primary,
                context.accent.primarySoft,
              )
            : (
                LucideIcons.heartHandshake,
                AarastV3Color.lilac,
                AarastV3Color.lilacSoft,
              ),
      _ => (LucideIcons.gift, AarastV3Color.lilac, AarastV3Color.lilacSoft),
    };
    final expected = source.expectedAt;
    return JourneyListRow(
      icon: icon,
      color: color,
      soft: soft,
      title: source.sourceName,
      // c05: «يوصلك يوم العقد 15 نوفمبر» for the mahr's rest; D59: a
      // promise whose day passed says so («كان موعده 15 نوفمبر»).
      subtitle: source.isOverdue && expected != null
          ? 'كان موعده ${formatArabicDayMonth(expected)}'
          : source.isMahr
          ? (!received && expected != null
                ? 'يوصلك ${formatArabicDayMonth(expected)}'
                : (source.note?.trim().isNotEmpty == true
                      ? source.note!.trim()
                      : FundingKind.label(source.kind, context.journeyProfile)))
          : FundingKind.label(source.kind, context.journeyProfile),
      onTap: onTap,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            style: JourneyType.of(
              JourneyType.bodyLarge,
              weight: JourneyType.bold,
            ),
          ),
          const SizedBox(height: 4),
          fundingStateTag(source),
        ],
      ),
    );
  }
}
