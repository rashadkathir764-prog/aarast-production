part of 'money_overview_screen.dart';

// c03 «الدفعات»: what is late and what falls due in the next 30 days (the
// server's due list), the total of those, and each one recorded with a
// swipe («دفعتها»). A row opens its agreement (c07), where every date of it
// is listed; later dates are not shown here, as drawn.

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
    final now = DateTime.now();
    final schedules = [...provider.dueSchedules]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final total = schedules.fold<double>(
      0,
      (sum, schedule) => sum + moneyValue(schedule.amount),
    );
    final canSwipe = provider.canManageMoney;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            color: AarastV3Color.primarySoft,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'خلال 30 يوم',
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
                          color: AarastV3Color.primaryDark,
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
                    color: AarastV3Color.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const JourneySectionTitle('قادمة'),
          if (canSwipe)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
              child: Text(
                'اسحب الدفعة لما تدفعها',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
          JourneyBox(
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
                      AppRouter.moneyCostDetails(
                        planId,
                        schedules[index].costId,
                      ),
                    ),
                    onPay: canSwipe ? onPay(schedules[index]) : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
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
              const CustomSemanticsAction(label: 'دفعتها'): () =>
                  onPay!(schedule),
            },
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: overdue
                      ? AarastV3Color.dangerSoft
                      : AarastV3Color.brandAccentSoft,
                  borderRadius: BorderRadius.circular(14),
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
              const SizedBox(width: 12),
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
        padding: const EdgeInsetsDirectional.only(start: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.check, color: AarastV3Color.onPrimary),
            const SizedBox(width: 8),
            Text(
              'دفعتها',
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
