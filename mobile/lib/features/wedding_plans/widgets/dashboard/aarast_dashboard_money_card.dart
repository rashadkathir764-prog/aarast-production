part of 'aarast_dashboard_view.dart';

class _DashboardMoneyCard extends StatefulWidget {
  const _DashboardMoneyCard({required this.summary, required this.onTap});

  final DashboardSummary summary;
  final VoidCallback onTap;

  @override
  State<_DashboardMoneyCard> createState() => _DashboardMoneyCardState();
}

class _DashboardMoneyCardState extends State<_DashboardMoneyCard> {
  bool _amountsHidden = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final budget = dashboardAmount(summary.totalBudgetForDisplay);
    final confirmed = dashboardAmount(summary.confirmedCostForDisplay) ?? 0;
    final paid = dashboardAmount(summary.paidForDisplay) ?? 0;
    final calculatedOutstanding = confirmed - paid;
    final outstanding =
        dashboardAmount(summary.outstandingForDisplay) ??
        (calculatedOutstanding < 0 ? 0.0 : calculatedOutstanding);
    final remaining =
        dashboardAmount(summary.remainingBudgetForDisplay) ??
        (budget == null ? null : budget - confirmed);
    final overBudget =
        summary.moneySummary.overBudget == true ||
        (remaining != null && remaining < 0);
    final hasDuePayment = (summary.duePaymentSchedulesCount ?? 0) > 0;
    final ratio = budget == null || budget <= 0
        ? null
        : (confirmed / budget).clamp(0.0, 1.0);
    final percent = budget == null || budget <= 0
        ? null
        : ((confirmed / budget) * 100).round();
    final tone = _DashboardMoneyTone.fromState(
      overBudget: overBudget,
      hasDuePayment: hasDuePayment,
    );
    final headlineAmount = overBudget && remaining != null
        ? remaining.abs()
        : remaining;

    return Semantics(
      container: true,
      button: true,
      label: _dashboardMoneySemanticsLabel(
        summary: summary,
        budget: budget,
        remaining: remaining,
        paid: paid,
        outstanding: outstanding,
        hidden: _amountsHidden,
      ),
      child: Material(
        color: AarastV3Color.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          side: BorderSide(color: tone.accent.withValues(alpha: .34)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('aarast-dashboard-money-card'),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DashboardMoneyHeader(
                  budgetIsSet: budget != null,
                  overBudget: overBudget,
                  hasDuePayment: hasDuePayment,
                  amountsHidden: _amountsHidden,
                  tone: tone,
                  onTogglePrivacy: () =>
                      setState(() => _amountsHidden = !_amountsHidden),
                ),
                const SizedBox(height: AarastV3Space.x2),
                if (budget == null)
                  _DashboardUnsetBudgetSummary(
                    confirmed: confirmed,
                    currency: summary.currency,
                    hidden: _amountsHidden,
                  )
                else
                  _DashboardMoneyOverview(
                    budget: budget,
                    headlineAmount: headlineAmount,
                    confirmed: confirmed,
                    paid: paid,
                    outstanding: outstanding,
                    ratio: ratio,
                    percent: percent,
                    overBudget: overBudget,
                    hidden: _amountsHidden,
                    currency: summary.currency,
                    tone: tone,
                  ),
                if (hasDuePayment) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  _DashboardPaymentAttention(
                    label: _paymentAttentionLabel(summary, _amountsHidden),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardMoneyHeader extends StatelessWidget {
  const _DashboardMoneyHeader({
    required this.budgetIsSet,
    required this.overBudget,
    required this.hasDuePayment,
    required this.amountsHidden,
    required this.tone,
    required this.onTogglePrivacy,
  });

  final bool budgetIsSet;
  final bool overBudget;
  final bool hasDuePayment;
  final bool amountsHidden;
  final _DashboardMoneyTone tone;
  final VoidCallback onTogglePrivacy;

  @override
  Widget build(BuildContext context) {
    final subtitle = !budgetIsSet
        ? 'ابدأ بصورة مالية واضحة'
        : overBudget
        ? 'تجاوز يحتاج قرارك'
        : hasDuePayment
        ? 'موعد دفع يحتاج انتباهك'
        : 'أمورك المالية ضمن الخطة';

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
          ),
          child: Icon(LucideIcons.walletCards, color: tone.accent, size: 18),
        ),
        const SizedBox(width: AarastV3Space.x2),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المال',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AarastV3Color.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tone.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('dashboard-money-privacy-toggle'),
          onPressed: onTogglePrivacy,
          tooltip: amountsHidden ? 'إظهار المبالغ' : 'إخفاء المبالغ',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: Icon(
            amountsHidden ? LucideIcons.eye : LucideIcons.eyeOff,
            color: AarastV3Color.textMuted,
            size: 18,
          ),
        ),
        const SizedBox(width: AarastV3Space.x1),
        const Icon(
          LucideIcons.chevronLeft,
          color: AarastV3Color.textFaint,
          size: 17,
        ),
      ],
    );
  }
}

class _DashboardMoneyOverview extends StatelessWidget {
  const _DashboardMoneyOverview({
    required this.budget,
    required this.headlineAmount,
    required this.confirmed,
    required this.paid,
    required this.outstanding,
    required this.ratio,
    required this.percent,
    required this.overBudget,
    required this.hidden,
    required this.currency,
    required this.tone,
  });

  final double budget;
  final double? headlineAmount;
  final double confirmed;
  final double paid;
  final double outstanding;
  final double? ratio;
  final int? percent;
  final bool overBudget;
  final bool hidden;
  final String currency;
  final _DashboardMoneyTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overBudget ? 'تجاوز الميزانية' : 'المتاح من الميزانية',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AarastV3Color.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _DashboardAnimatedAmount(
                    value: hidden
                        ? '••••'
                        : _displayAmount(headlineAmount, currency),
                    color: overBudget
                        ? AarastV3Color.danger
                        : AarastV3Color.ink,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Flexible(
              child: Text(
                hidden
                    ? 'من ميزانية ••••'
                    : 'من ميزانية ${_displayAmount(budget, currency)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AarastV3Color.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x2),
        Row(
          children: [
            Expanded(
              child: _DashboardMoneyFigure(
                label: 'التكاليف',
                value: hidden ? '••••' : _displayAmount(confirmed, currency),
                accent: AarastV3Color.primary,
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: _DashboardMoneyFigure(
                label: 'المدفوع',
                value: hidden ? '••••' : _displayAmount(paid, currency),
                accent: AarastV3Color.mint,
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: _DashboardMoneyFigure(
                label: 'غير المدفوع',
                value: hidden ? '••••' : _displayAmount(outstanding, currency),
                accent: outstanding > 0
                    ? AarastV3Color.amber
                    : AarastV3Color.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x2),
        AarastV3ProgressLine(
          height: 5,
          value: ratio,
          color: tone.accent,
          backgroundColor: tone.background,
          semanticsLabel: 'نسبة استخدام الميزانية',
        ),
        const SizedBox(height: AarastV3Space.x1),
        Text(
          hidden
              ? 'نسبة الاستخدام مخفية مؤقتًا'
              : overBudget
              ? 'مستخدمة $percent% · راجع التكاليف الآن'
              : 'مستخدمة $percent% من الميزانية',
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: overBudget ? AarastV3Color.danger : tone.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DashboardMoneyFigure extends StatelessWidget {
  const _DashboardMoneyFigure({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AarastV3Color.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: accent,
              fontFamily: AarastV3Type.displayFamily,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardAnimatedAmount extends StatelessWidget {
  const _DashboardAnimatedAmount({required this.value, required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: FittedBox(
        key: ValueKey(value),
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          value,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontFamily: AarastV3Type.displayFamily,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DashboardUnsetBudgetSummary extends StatelessWidget {
  const _DashboardUnsetBudgetSummary({
    required this.confirmed,
    required this.currency,
    required this.hidden,
  });

  final double confirmed;
  final String currency;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'حدّد ميزانية تقريبية',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AarastV3Color.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AarastV3Space.x1),
              Text(
                confirmed > 0
                    ? hidden
                          ? 'لديك تكاليف مؤكدة · المبلغ مخفي'
                          : 'التكاليف المؤكدة ${_displayAmount(confirmed, currency)}'
                    : 'ابدأ برقم أولي وعدّله لاحقًا.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AarastV3Color.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AarastV3Space.x2),
        Text(
          'إعداد الميزانية',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AarastV3Color.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DashboardPaymentAttention extends StatelessWidget {
  const _DashboardPaymentAttention({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x2,
        vertical: AarastV3Space.x2,
      ),
      decoration: BoxDecoration(
        color: AarastV3Color.amberSoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.calendarClock,
            color: AarastV3Color.amber,
            size: 16,
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AarastV3Color.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(
            LucideIcons.arrowLeft,
            color: AarastV3Color.amber,
            size: 15,
          ),
        ],
      ),
    );
  }
}

class _DashboardMoneyTone {
  const _DashboardMoneyTone({required this.accent, required this.background});

  factory _DashboardMoneyTone.fromState({
    required bool overBudget,
    required bool hasDuePayment,
  }) {
    if (overBudget) {
      return const _DashboardMoneyTone(
        accent: AarastV3Color.danger,
        background: AarastV3Color.dangerSoft,
      );
    }
    if (hasDuePayment) {
      return const _DashboardMoneyTone(
        accent: AarastV3Color.amber,
        background: AarastV3Color.amberSoft,
      );
    }
    return const _DashboardMoneyTone(
      accent: AarastV3Color.primary,
      background: AarastV3Color.primarySoft,
    );
  }

  final Color accent;
  final Color background;
}

String _dashboardMoneySemanticsLabel({
  required DashboardSummary summary,
  required double? budget,
  required double? remaining,
  required double paid,
  required double outstanding,
  required bool hidden,
}) {
  if (hidden) return 'المال، المبالغ مخفية مؤقتًا';
  if (budget == null) return 'المال، الميزانية غير محددة';
  return 'المال، المتاح ${_displayAmount(remaining, summary.currency)}، '
      'المدفوع ${_displayAmount(paid, summary.currency)}، '
      'غير المدفوع ${_displayAmount(outstanding, summary.currency)}';
}

String _displayAmount(double? value, String currency) {
  if (value == null) return 'غير محسوب';
  return _money(value, currency);
}

String _paymentAttentionLabel(DashboardSummary summary, bool hidden) {
  final next = summary.nextPaymentScheduleDue;
  final count = summary.duePaymentSchedulesCount ?? 0;
  if (next == null) {
    return count == 1
        ? 'لديك موعد دفع يحتاج مراجعة'
        : 'لديك $count مواعيد دفع تحتاج مراجعة';
  }
  final title = next.title.trim().isEmpty ? 'موعد دفع قريب' : next.title.trim();
  if (hidden) return 'موعد دفع قريب · $title';
  final amount = dashboardAmount(next.amount);
  return amount == null
      ? 'موعد دفع قريب · $title'
      : 'موعد دفع قريب · $title · ${_displayAmount(amount, summary.currency)}';
}
