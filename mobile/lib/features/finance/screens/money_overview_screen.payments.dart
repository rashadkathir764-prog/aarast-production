part of 'money_overview_screen.dart';

// c03 «الدفعات» (D102, D106): everything still to pay on the wedding, as a
// plan in time: what is late first, then month by month to the wedding and
// after it, then what has no date yet; the loans apart, a debt and not a
// cost of the wedding. And what was paid, with its reversals.
//
// A date opens its own pay page, at what it asks or any other amount
// (D106), where «اتفقتوا على موعد ثاني؟» and its reminder are too. The figures are the server's (C2), or the phone's twin for a plan
// kept on the phone.

enum _PaySegment { upcoming, done }

class _MoneyPaymentsTab extends StatefulWidget {
  const _MoneyPaymentsTab({
    required this.planId,
    required this.provider,
    required this.onOpen,
    required this.onPay,
    required this.onAgreement,
    required this.weddingDate,
  });

  final String planId;
  final FinanceProvider provider;
  final void Function(MoneyObligation line) onOpen;

  /// Null when the reader may not pay. A date's new day and its reminder
  /// are on its pay page (D106).
  final void Function(MoneyObligation line)? onPay;
  final VoidCallback? onAgreement;

  /// The wedding's day when the plan has one: the months run to it.
  final DateTime? weddingDate;

  @override
  State<_MoneyPaymentsTab> createState() => _MoneyPaymentsTabState();
}

class _MoneyPaymentsTabState extends State<_MoneyPaymentsTab> {
  _PaySegment _segment = _PaySegment.upcoming;

  /// Whose dues are shown: null all, '' the owner's, else a payer's key.
  String? _who;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final summary = provider.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            JourneyChip(
              key: const ValueKey('money-pay-upcoming'),
              label: 'الجاية',
              selected: _segment == _PaySegment.upcoming,
              onTap: () => setState(() => _segment = _PaySegment.upcoming),
            ),
            JourneyChip(
              key: const ValueKey('money-pay-done'),
              label: context.ownerDid(
                'اللي دفعتها',
                'اللي دفعتيها',
                groom: 'اللي اندفع',
                bride: 'اللي اندفع',
              ),
              selected: _segment == _PaySegment.done,
              onTap: () => setState(() => _segment = _PaySegment.done),
            ),
            // w20 «مين دفع ايش» (G14).
            if (summary.payers.isNotEmpty)
              JourneyTextAction(
                key: const ValueKey('money-payers'),
                label: 'مين دفع ايش',
                color: context.accent.primary,
                onPressed: () =>
                    context.push(AppRouter.moneyPayers(widget.planId)),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
        if (_segment == _PaySegment.upcoming)
          ..._upcoming(context, summary)
        else
          ..._done(context, provider),
      ],
    );
  }

  List<Widget> _upcoming(BuildContext context, MoneySummary summary) {
    final currency = summary.currency;
    String money(Object? value) => _figure(context, value, currency);
    final profile = context.journeyProfile;
    final wedding = [
      for (final line in summary.obligations)
        if (!line.isLoan) line,
    ];
    final loans = [
      for (final line in summary.obligations)
        if (line.isLoan) line,
    ];
    if (wedding.isEmpty && loans.isEmpty) {
      return [
        JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.money,
          emptyIcon: LucideIcons.calendarCheck,
          emptyTitle: context.ownerDid(
            'ما عليك دفعات',
            'ما عليكِ دفعات',
            groom: 'ما في دفعات',
            bride: 'ما في دفعات',
          ),
          emptyAction: widget.onAgreement == null
              ? null
              : context.say('سجّل اتفاق', 'سجّلي اتفاق'),
          onEmptyAction: widget.onAgreement,
        ),
      ];
    }
    // Whose: the owner's own, and each other payer (D59).
    final others = <String, ({String label, num amount})>{};
    num ownerAmount = 0;
    for (final line in wedding) {
      if (line.ownerMoney) {
        ownerAmount += moneyValue(line.amount);
        continue;
      }
      final key = payerKey(line.payer, line.payerName);
      final label = payerLabel(
        line.payer,
        line.payerName,
        bridePlan: profile.isBride,
        owner: profile.readerIsOwner,
      );
      final before = others[key];
      others[key] = (
        label: label,
        amount: (before?.amount ?? 0) + moneyValue(line.amount),
      );
    }
    final who = _who;
    final shown = [
      for (final line in wedding)
        if (who == null ||
            (who.isEmpty
                ? line.ownerMoney
                : !line.ownerMoney &&
                      payerKey(line.payer, line.payerName) == who))
          line,
    ];
    num sum(Iterable<MoneyObligation> lines) =>
        lines.fold<num>(0, (total, line) => total + moneyValue(line.amount));
    final late = [
      for (final line in shown)
        if (line.dueDate != null && line.isOverdue) line,
    ];
    final dated = [
      for (final line in shown)
        if (line.dueDate != null && !line.isOverdue) line,
    ]..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final undated = [
      for (final line in shown)
        if (line.dueDate == null) line,
    ];
    final weddingDay = widget.weddingDate;
    final weddingMonth = weddingDay == null
        ? null
        : DateTime(weddingDay.year, weddingDay.month);
    DateTime monthOf(DateTime day) => DateTime(day.year, day.month);
    final months = <DateTime, List<MoneyObligation>>{};
    final afterWedding = <MoneyObligation>[];
    for (final line in dated) {
      final month = monthOf(line.dueDate!);
      if (weddingMonth != null && month.isAfter(weddingMonth)) {
        afterWedding.add(line);
      } else {
        months.putIfAbsent(month, () => []).add(line);
      }
    }
    Widget lines(List<MoneyObligation> rows, {Key? key}) => JourneyBox(
      key: key,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AarastV3Color.line,
              ),
            _DueLine(
              key: ValueKey('money-due-${rows[index].id}'),
              line: rows[index],
              currency: currency,
              onOpen: () => widget.onOpen(rows[index]),
              onPay: rows[index].kind == MoneyObligationKind.due
                  ? widget.onPay
                  : null,
            ),
          ],
        ],
      ),
    );
    Widget title(String text, num amount, {Color? colour}) =>
        JourneySectionTitle(
          text,
          action: money(amount),
          actionColor: colour ?? AarastV3Color.textMuted,
        );
    final chart = [
      for (final entry in months.entries)
        (
          month: entry.key,
          amount: sum(entry.value),
          owner: sum(entry.value.where((line) => line.ownerMoney)),
        ),
      if (afterWedding.isNotEmpty)
        (
          month: monthOf(afterWedding.first.dueDate!),
          amount: sum(afterWedding),
          owner: sum(afterWedding.where((line) => line.ownerMoney)),
        ),
    ];
    return [
      if (others.isNotEmpty && wedding.isNotEmpty) ...[
        Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            JourneyChip(
              key: const ValueKey('money-pay-who-all'),
              label: 'الكل ${money(sum(wedding))}',
              selected: who == null,
              onTap: () => setState(() => _who = null),
            ),
            JourneyChip(
              key: const ValueKey('money-pay-who-owner'),
              label:
                  '${context.ownerDid('عليك', 'عليكِ', groom: 'على العريس', bride: 'على العروسة')} ${money(ownerAmount)}',
              selected: who == '',
              onTap: () => setState(() => _who = ''),
            ),
            for (final entry in others.entries)
              JourneyChip(
                key: ValueKey('money-pay-who-${entry.key}'),
                label: 'على ${entry.value.label} ${money(entry.value.amount)}',
                selected: who == entry.key,
                onTap: () => setState(() => _who = entry.key),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
      ],
      if (shown.isNotEmpty) ...[
        JourneyBox(
          key: const ValueKey('money-due-total'),
          color: context.accent.primarySoft,
          padding: const EdgeInsets.all(AarastV3Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'باقي من دفعات العرس',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
              Text(
                money(sum(shown)),
                style: JourneyType.of(
                  JourneyType.display,
                  weight: JourneyType.bold,
                  color: context.accent.primaryDark,
                ),
              ),
              Text(
                [
                  arabicCount(
                    shown.length,
                    one: 'دفعة وحدة',
                    two: 'دفعتين',
                    few: 'دفعات',
                    many: 'دفعة',
                  ),
                  if (late.isNotEmpty) 'منها متأخر ${money(sum(late))}',
                ].join(' · '),
                style: JourneyType.of(
                  JourneyType.small,
                  weight: late.isEmpty ? FontWeight.w400 : JourneyType.bold,
                  color: late.isEmpty
                      ? AarastV3Color.textMuted
                      : AarastV3Color.danger,
                ),
              ),
              if (chart.length > 1) ...[
                const SizedBox(height: AarastV3Space.x3),
                _DuesChart(
                  months: chart,
                  weddingMonth: weddingMonth,
                  afterWedding: afterWedding.isNotEmpty,
                  currency: currency,
                ),
              ],
            ],
          ),
        ),
      ] else if (wedding.isNotEmpty)
        JourneyNote(
          text:
              'ما في دفعات عرس ${who == '' ? context.ownerDid('عليك', 'عليكِ', groom: 'على العريس', bride: 'على العروسة') : 'على ${others[who]?.label ?? ''}'}.',
        ),
      if (late.isNotEmpty) ...[
        title('متأخرة', sum(late), colour: AarastV3Color.danger),
        lines(late, key: const ValueKey('money-due-late')),
      ],
      for (final entry in months.entries) ...[
        title(
          '${arabicMonthName(entry.key.month)}${entry.key.year != sanaaToday().year ? ' ${entry.key.year}' : ''}${entry.key == weddingMonth ? ' · شهر العرس' : ''}',
          sum(entry.value),
        ),
        lines(
          entry.value,
          key: ValueKey('money-due-month-${entry.key.year}-${entry.key.month}'),
        ),
      ],
      if (afterWedding.isNotEmpty) ...[
        title('بعد العرس', sum(afterWedding)),
        lines(afterWedding, key: const ValueKey('money-due-after')),
      ],
      if (undated.isNotEmpty) ...[
        title('بدون موعد', sum(undated), colour: AarastV3Color.amber),
        lines(undated, key: const ValueKey('money-due-undated')),
      ],
      // Loans: a debt of his, not a cost of the wedding (D102).
      if (loans.isNotEmpty && (who == null || who.isEmpty))
        ..._loans(context, loans, currency),
    ];
  }

  List<Widget> _loans(
    BuildContext context,
    List<MoneyObligation> loans,
    String currency,
  ) {
    String money(Object? value) => _figure(context, value, currency);
    final bySource = <String, List<MoneyObligation>>{};
    for (final line in loans) {
      bySource.putIfAbsent(line.fundingSourceId ?? line.id, () => []).add(line);
    }
    return [
      const SizedBox(height: AarastV3Space.x3),
      const Divider(height: 1, color: AarastV3Color.line),
      for (final entry in bySource.entries) ...[
        JourneySectionTitle(
          'سداد ${entry.value.first.title}',
          action: money(
            entry.value.fold<num>(
              0,
              (sum, line) => sum + moneyValue(line.amount),
            ),
          ),
          actionColor: AarastV3Color.textMuted,
        ),
        JourneyBox(
          key: ValueKey('money-loan-${entry.key}'),
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              for (final line in entry.value)
                JourneyListRow(
                  key: ValueKey('money-loan-line-${line.id}'),
                  icon: LucideIcons.repeat,
                  color: line.isOverdue
                      ? AarastV3Color.danger
                      : AarastV3Color.lilac,
                  soft: line.isOverdue
                      ? AarastV3Color.dangerSoft
                      : AarastV3Color.lilacSoft,
                  title: line.note?.trim().isNotEmpty == true
                      ? line.note!.trim()
                      : line.kind == MoneyObligationKind.loanUnplanned
                      ? 'بدون موعد سداد'
                      : 'دفعة سداد',
                  subtitle: line.dueDate == null
                      ? 'حدد متى ترجعه'
                      : '${formatArabicDayMonth(line.dueDate!)} · ${_whenWords(line.dueDate!)}',
                  subtitleMaxLines: 2,
                  trailing: Text(
                    money(line.amount),
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  onTap: line.fundingSourceId == null
                      ? null
                      : () => context.push(
                          AppRouter.moneyFunding(
                            widget.planId,
                            sourceId: line.fundingSourceId,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: AarastV3Space.x2),
        child: Text(
          context.ownerDid(
            'دين عليك، مو من تكاليف العرس: ما يدخل في «دفعات العرس» ولا في تكلفته.',
            'دين عليكِ، مو من تكاليف العرس: ما يدخل في «دفعات العرس» ولا في تكلفته.',
            groom: 'دين على العريس، مو من تكاليف العرس.',
            bride: 'دين على العروسة، مو من تكاليف العرس.',
          ),
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ),
    ];
  }

  List<Widget> _done(BuildContext context, FinanceProvider provider) {
    final currency = provider.summary.currency;
    String money(Object? value) => _figure(context, value, currency);
    final payments = [
      for (final payment in provider.payments)
        if (!payment.isReversal) payment,
    ]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    if (payments.isEmpty) {
      return [
        JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.money,
          emptyIcon: LucideIcons.receipt,
          emptyTitle: context.ownerDid(
            'ما سجلت دفعات بعد',
            'ما سجلتِ دفعات بعد',
            groom: 'ما انسجلت دفعات بعد',
            bride: 'ما انسجلت دفعات بعد',
          ),
        ),
      ];
    }
    final total = payments
        .where((payment) => !payment.isReversed)
        .fold<num>(0, (sum, payment) => sum + moneyValue(payment.amount));
    return [
      JourneySectionTitle(
        'اللي اندفع',
        action: money(total),
        actionColor: AarastV3Color.textMuted,
      ),
      JourneyBox(
        key: const ValueKey('money-paid-list'),
        padding: EdgeInsets.zero,
        child: JourneyList(
          children: [
            for (final payment in payments)
              JourneyListRow(
                key: ValueKey('money-paid-${payment.id}'),
                icon: payment.isReversed
                    ? LucideIcons.undo2
                    : LucideIcons.checkCircle2,
                color: payment.isReversed
                    ? AarastV3Color.textFaint
                    : AarastV3Color.mint,
                soft: payment.isReversed
                    ? AarastV3Color.line
                    : AarastV3Color.mintSoft,
                title:
                    payment.costTitle ??
                    provider.costById(payment.costId)?.title ??
                    'دفعة',
                subtitle: [
                  formatArabicDayMonth(payment.paidAt),
                  if (payment.method?.trim().isNotEmpty == true)
                    payment.method!.trim(),
                  if (payment.lowersScheduleId != null) 'من موعد',
                  if (payment.isReversed) 'انعكست',
                ].join(' · '),
                subtitleMaxLines: 2,
                trailing: Text(
                  money(payment.amount),
                  style:
                      JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                        color: payment.isReversed
                            ? AarastV3Color.textFaint
                            : AarastV3Color.ink,
                      ).copyWith(
                        decoration: payment.isReversed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                ),
                onTap: () => context.push(
                  AppRouter.moneyPaymentDetails(
                    widget.planId,
                    payment.id,
                    costId: payment.costId,
                  ),
                ),
              ),
          ],
        ),
      ),
      if (provider.hasMorePayments) ...[
        const SizedBox(height: AarastV3Space.x2),
        Center(
          child: JourneyTextAction(
            key: const ValueKey('money-paid-more'),
            label: provider.isLoadingMorePayments ? 'يحمّل…' : 'دفعات أقدم',
            color: context.accent.primary,
            onPressed: provider.isLoadingMorePayments
                ? null
                : provider.loadMorePayments,
          ),
        ),
      ],
    ];
  }
}

/// The wedding's dues by month: how much falls in each, the owner's part
/// in full colour, the others' lighter.
class _DuesChart extends StatelessWidget {
  const _DuesChart({
    required this.months,
    required this.weddingMonth,
    required this.afterWedding,
    required this.currency,
  });

  final List<({DateTime month, num amount, num owner})> months;
  final DateTime? weddingMonth;

  /// The last bar is everything after the wedding.
  final bool afterWedding;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final most = months.fold<num>(
      0,
      (max, month) => month.amount > max ? month.amount : max,
    );
    final own = context.accent.primary;
    final others = context.accent.primary.withValues(alpha: 0.35);
    return Semantics(
      label: [
        for (final (index, month) in months.indexed)
          '${afterWedding && index == months.length - 1 ? 'بعد العرس' : arabicMonthName(month.month.month)} ${_figure(context, month.amount, currency)}',
      ].join('، '),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (index, month) in months.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AarastV3Space.x1,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: _duesChartHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (month.amount > month.owner)
                              Container(
                                height:
                                    _duesChartHeight *
                                    (month.amount - month.owner) /
                                    (most <= 0 ? 1 : most),
                                color: others,
                              ),
                            if (month.owner > 0)
                              Container(
                                height:
                                    _duesChartHeight *
                                    month.owner /
                                    (most <= 0 ? 1 : most),
                                color: month.month == weddingMonth
                                    ? context.accent.primaryDark
                                    : own,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        afterWedding && index == months.length - 1
                            ? 'بعده'
                            : arabicMonthName(month.month.month),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JourneyType.of(
                          JourneyType.caption,
                          weight: month.month == weddingMonth
                              ? JourneyType.bold
                              : FontWeight.w400,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The chart's height: a fixed dimension, like the progress bars'.
const _duesChartHeight = 56.0;

/// One thing still to pay: when, whose, how much of it was paid, and its
/// actions (pay, a new date, its reminder) when the reader may.
class _DueLine extends StatelessWidget {
  const _DueLine({
    required this.line,
    required this.currency,
    required this.onOpen,
    required this.onPay,
    super.key,
  });

  final MoneyObligation line;
  final String currency;
  final VoidCallback onOpen;
  final void Function(MoneyObligation line)? onPay;

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    String money(Object? value) => _figure(context, value, currency);
    final day = line.dueDate;
    final late = day != null && line.isOverdue;
    final facts = <_Fact>[
      if (day == null)
        ('بدون موعد', AarastV3Color.amber)
      else if (late)
        (_whenWords(day), AarastV3Color.danger)
      else
        ('${formatArabicDayMonth(day)} · ${_whenWords(day)}', null),
      if (!line.ownerMoney)
        (
          'على ${payerLabel(line.payer, line.payerName, bridePlan: profile.isBride, owner: profile.readerIsOwner)}',
          null,
        ),
    ];
    final notes = [
      if (line.isPartlyPaid)
        'اندفع ${money(line.paidTowards)} من ${money(line.scheduledAmount)}',
      if (line.rescheduledFrom case final first?)
        'كانت ${formatArabicDayMonth(first)}',
      if (line.remindAt case final remind?)
        'نذكّرك ${formatArabicDayMonth(remind)}',
    ];
    final pay = onPay;
    final row = AarastPressable(
      // A date opens its pay page; anything else its agreement.
      onTap: pay == null ? onOpen : () => pay(line),
      semanticLabel: [
        line.title,
        for (final fact in facts) fact.$1,
        ...notes,
        money(line.amount),
      ].join('، '),
      child: Padding(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        // What it is beside how much, so the action does not push the
        // day under a gap.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.title,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        for (final (index, fact) in facts.indexed) ...[
                          if (index > 0) const TextSpan(text: ' · '),
                          TextSpan(
                            text: fact.$1,
                            style: fact.$2 == null
                                ? null
                                : TextStyle(
                                    color: fact.$2,
                                    fontWeight: JourneyType.bold,
                                  ),
                          ),
                        ],
                      ],
                    ),
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  if (notes.isNotEmpty)
                    Text(
                      notes.join(' · '),
                      style: JourneyType.of(
                        JourneyType.caption,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(line.amount),
                    textAlign: TextAlign.end,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: late ? AarastV3Color.danger : AarastV3Color.ink,
                    ),
                  ),
                  if (pay != null)
                    JourneyTextAction(
                      key: ValueKey('money-due-pay-${line.id}'),
                      label: context.say('سجّل', 'سجّلي'),
                      color: context.accent.primary,
                      onPressed: () => pay(line),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (pay == null) return row;
    // Swiping opens recording the payment; the row stays until the money
    // says it is paid.
    return Dismissible(
      key: ValueKey('money-due-swipe-${line.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        pay(line);
        return false;
      },
      background: Container(
        color: AarastV3Color.mint,
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsetsDirectional.only(start: AarastV3Space.x5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.check, color: AarastV3Color.onPrimary),
            const SizedBox(width: AarastV3Space.x2),
            Text(
              context.say('دفعتها', 'دفعتيها'),
              style: JourneyType.of(
                JourneyType.bodyLarge,
                weight: JourneyType.bold,
                color: AarastV3Color.onPrimary,
              ),
            ),
          ],
        ),
      ),
      child: row,
    );
  }
}
