part of 'money_overview_screen.dart';

// c03 «الدفعات»: what is late and what falls due in the next 30 days (the
// server's due list: `dueDate <= today + 30` with no lower bound, so every
// old overdue date is in it), the total of those, and each one recorded with
// its own «سجّل الدفعة» or a swipe. A row opens its agreement (c07), where
// every date of it is listed; later dates are not shown here, as drawn.
//
// The late ones are their own section: they were under a heading that said
// «قادمة», and counted into a figure labelled «خلال 30 يوم», while they are
// neither upcoming nor inside that window.

class _MoneyPaymentsTab extends StatelessWidget {
  const _MoneyPaymentsTab({
    required this.planId,
    required this.provider,
    required this.onPay,
  });

  final String planId;
  final FinanceProvider provider;

  /// Opens recording this payment; null when it cannot be paid here.
  final ValueChanged<PaymentSchedule>? Function(PaymentSchedule) onPay;

  @override
  Widget build(BuildContext context) {
    final currency = provider.summary.currency;
    final now = appNow();
    final schedules = [...provider.dueSchedules]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    // RA-BE-53: each reminder at what it asks for now (at most what its
    // agreement still owes), as the server reads it and pays it.
    final total = schedules.fold<double>(
      0,
      (sum, schedule) => sum + moneyValue(schedule.dueAmount),
    );
    final canSwipe = provider.canManageMoney;
    final late = [
      for (final schedule in schedules)
        if (schedule.isOverdueAt(now)) schedule,
    ];
    final soon = [
      for (final schedule in schedules)
        if (!schedule.isOverdueAt(now)) schedule,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // w20 «مين دفع ايش» (G14): an undrawn way in from c03.
        if (provider.summary.payers.isNotEmpty) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('money-payers'),
              label: 'مين دفع ايش',
              color: context.accent.primary,
              onPressed: () => context.push(AppRouter.moneyPayers(planId)),
            ),
          ),
          const SizedBox(height: AarastV3Space.x1),
        ],
        if (schedules.isEmpty)
          const JourneyListState(
            phase: JourneyListPhase.empty,
            section: JourneySection.money,
            emptyIcon: LucideIcons.calendarCheck,
            emptyTitle: 'ما عليك دفعات قريبة',
          )
        else ...[
          JourneyBox(
            key: const ValueKey('money-due-total'),
            color: context.accent.primarySoft,
            padding: const EdgeInsets.all(AarastV3Space.x4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The label says what the figure adds up: the late
                        // ones, the next 30 days, or both. «المستحق عليك
                        // الآن» over both called the coming ones due now,
                        // and spoke to a participant as the owner (RA-MO-10).
                        late.isEmpty
                            ? 'خلال 30 يوم'
                            : soon.isEmpty
                            ? 'المتأخر'
                            : 'المتأخر والقادم خلال 30 يوم',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                      Text(
                        _amount(context, total, currency),
                        style: JourneyType.of(
                          JourneyType.display,
                          weight: JourneyType.bold,
                          color: context.accent.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  arabicCount(
                    schedules.length,
                    one: 'دفعة وحدة',
                    two: 'دفعتين',
                    few: 'دفعات',
                    many: 'دفعة',
                  ),
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                    color: context.accent.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          if (canSwipe)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AarastV3Space.x1,
                0,
                AarastV3Space.x1,
                AarastV3Space.x2,
              ),
              child: Text(
                context.say(
                  'سجّل الدفعة لما تدفعها، أو اسحبها',
                  'سجّلي الدفعة لما تدفعينها، أو اسحبيها',
                ),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
          if (late.isNotEmpty) ...[
            const JourneySectionTitle('متأخرة'),
            _DueList(
              key: const ValueKey('money-due-late'),
              planId: planId,
              schedules: late,
              currency: currency,
              now: now,
              canPay: canSwipe,
              onPay: onPay,
            ),
            const SizedBox(height: AarastV3Space.x3),
          ],
          if (soon.isNotEmpty) ...[
            const JourneySectionTitle('قادمة خلال 30 يوم'),
            _DueList(
              key: const ValueKey('money-due-soon'),
              planId: planId,
              schedules: soon,
              currency: currency,
              now: now,
              canPay: canSwipe,
              onPay: onPay,
            ),
          ],
        ],
      ],
    );
  }
}

/// One section's rows, so «متأخرة» and «قادمة» are drawn the same way.
class _DueList extends StatelessWidget {
  const _DueList({
    required this.planId,
    required this.schedules,
    required this.currency,
    required this.now,
    required this.canPay,
    required this.onPay,
    super.key,
  });

  final String planId;
  final List<PaymentSchedule> schedules;
  final String currency;
  final DateTime now;
  final bool canPay;
  final ValueChanged<PaymentSchedule>? Function(PaymentSchedule) onPay;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < schedules.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AarastV3Color.line,
              ),
            _DueRow(
              schedule: schedules[index],
              amount: _amount(context, schedules[index].amount, currency),
              overdue: schedules[index].isOverdueAt(now),
              onOpen: () => context.push(
                AppRouter.moneyCostDetails(planId, schedules[index].costId),
              ),
              onPay: canPay ? onPay(schedules[index]) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow({
    required this.schedule,
    required this.amount,
    required this.overdue,
    required this.onOpen,
    required this.onPay,
  });

  final PaymentSchedule schedule;
  final String amount;
  final bool overdue;
  final VoidCallback onOpen;
  final ValueChanged<PaymentSchedule>? onPay;

  @override
  Widget build(BuildContext context) {
    final title = schedule.costTitle ?? 'دفعة';
    final row = Semantics(
      button: true,
      label:
          '${overdue ? 'متأخرة، ' : ''}$title، $amount، ${formatArabicWeekdayDayMonth(schedule.dueDate)}',
      onTap: onOpen,
      customSemanticsActions: onPay == null
          ? null
          : {
              CustomSemanticsAction(
                label: context.say('دفعتها', 'دفعتيها'),
              ): () =>
                  onPay!(schedule),
            },
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
                decoration: BoxDecoration(
                  color: overdue
                      ? AarastV3Color.dangerSoft
                      : AarastV3Color.brandAccentSoft,
                  borderRadius: BorderRadius.circular(AarastV3Radius.surface),
                ),
                child: Column(
                  children: [
                    Text(
                      '${schedule.dueDate.day}',
                      style: JourneyType.of(
                        JourneyType.title,
                        weight: JourneyType.bold,
                        color: overdue
                            ? AarastV3Color.danger
                            : AarastV3Color.brandAccentStrong,
                        height: 1.1,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        arabicMonthName(schedule.dueDate.month),
                        style: JourneyType.of(
                          JourneyType.caption,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                      ),
                    ),
                    if (overdue)
                      Text(
                        'متأخرة',
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: AarastV3Color.danger,
                        ),
                      ),
                    // The main action in sight, not only behind a swipe.
                    if (onPay != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: JourneyTextAction(
                          key: ValueKey('money-due-pay-${schedule.id}'),
                          label: context.say('سجّل الدفعة', 'سجّلي الدفعة'),
                          icon: LucideIcons.checkCircle2,
                          color: context.accent.primary,
                          onPressed: () => onPay!(schedule),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    amount,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onPay == null) return row;
    // Swiping opens recording the payment; the row stays until the server
    // says it is paid.
    return Dismissible(
      key: ValueKey('money-due-swipe-${schedule.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onPay!(schedule);
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
