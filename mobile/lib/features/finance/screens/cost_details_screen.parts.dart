part of 'cost_details_screen.dart';

String _plainAmount(BuildContext context, Object? value, String currency) {
  final hidden = context.select<FinanceProvider?, bool>(
    (provider) => provider?.amountsHidden ?? false,
  );
  if (hidden) return '••••';
  return compactMoneyParts(moneyValue(value), currencyCode: currency).plainText;
}

/// «الاتفاق 2,000,000 · باقي 1.5 مليون», what is paid, and where it came
/// from.
class _CostAgreementCard extends StatelessWidget {
  const _CostAgreementCard({required this.cost, required this.currency});

  final WeddingCost cost;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final total = moneyValue(cost.totalAmount);
    final paid = moneyValue(cost.paidAmount);
    final left = moneyValue(cost.remainingAmount);
    final ratio = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final hidden = context.select<FinanceProvider?, bool>(
      (provider) => provider?.amountsHidden ?? false,
    );
    final line = [
      if (cost.agreementDate != null)
        formatArabicWeekdayDayMonth(cost.agreementDate!),
      if (cost.quoteOfferId != null) 'من عرض مقبول في اعّرست',
      if (cost.isCancelled) 'ملغية',
    ].join(' · ');
    return JourneyBox(
      key: const ValueKey('cost-agreement-card'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الاتفاق',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        hidden
                            ? '••••'
                            : '${formatMoneyInputValue(total.round())} ${currencyLabelAr(currency)}',
                        style: JourneyType.of(
                          JourneyType.display,
                          weight: JourneyType.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        left > 0 ? 'باقي' : 'خالص',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                      if (left > 0)
                        Text(
                          _plainAmount(context, left, currency),
                          style: JourneyType.of(
                            JourneyType.title,
                            weight: JourneyType.bold,
                            color: AarastV3Color.danger,
                          ),
                        )
                      else
                        const Icon(
                          LucideIcons.checkCircle2,
                          color: AarastV3Color.mint,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          JourneyBar(
            value: ratio,
            color: cost.isCancelled
                ? AarastV3Color.textFaint
                : AarastV3Color.primary,
          ),
          if (line.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              line,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line of «جدول الدفعات»: a payment made, or one still to make.
class _TimelineEntry {
  const _TimelineEntry({
    required this.title,
    required this.line,
    required this.amount,
    required this.state,
    required this.onTap,
  });

  final String title;
  final String line;
  final Object? amount;

  /// done, current (the next to pay), later, or reversed.
  final _EntryState state;
  final VoidCallback onTap;
}

enum _EntryState { done, current, later, reversed }

class _PaymentTimeline extends StatelessWidget {
  const _PaymentTimeline({required this.entries, required this.currency});

  final List<_TimelineEntry> entries;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AarastV3Color.line,
              ),
            _TimelineRow(entry: entries[index], currency: currency),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.currency});

  final _TimelineEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final state = entry.state;
    final Widget mark = switch (state) {
      _EntryState.done => const _Mark(
        fill: AarastV3Color.mint,
        icon: LucideIcons.check,
      ),
      _EntryState.current => const _Mark(
        fill: AarastV3Color.brandAccentSoft,
        border: AarastV3Color.saffron,
      ),
      _EntryState.reversed => const _Mark(
        fill: AarastV3Color.line,
        icon: LucideIcons.undo2,
        iconColor: AarastV3Color.textMuted,
      ),
      _EntryState.later => const _Mark(fill: AarastV3Color.paperQuiet),
    };
    final muted = state == _EntryState.reversed;
    final amount = _plainAmount(context, entry.amount, currency);
    return Semantics(
      button: true,
      label: '${entry.title}، ${entry.line}، $amount',
      onTap: entry.onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              mark,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                        color: muted
                            ? AarastV3Color.textFaint
                            : AarastV3Color.ink,
                      ),
                    ),
                    Text(
                      entry.line,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: state == _EntryState.current
                            ? AarastV3Color.brandAccentStrong
                            : AarastV3Color.textMuted,
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
                      color: muted
                          ? AarastV3Color.textFaint
                          : AarastV3Color.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.fill,
    this.border,
    this.icon,
    this.iconColor = AarastV3Color.onPrimary,
  });

  final Color fill;
  final Color? border;
  final IconData? icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border!, width: 2.5),
      ),
      child: icon == null ? null : Icon(icon, size: 16, color: iconColor),
    );
  }
}

/// The agreement's facts: its item, who it is with and how to reach them,
/// and the note.
class _CostFacts extends StatelessWidget {
  const _CostFacts({required this.cost, required this.categoryName});

  final WeddingCost cost;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final party = cost.partyLabel;
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: JourneyList(
        children: [
          JourneyListRow(
            icon: LucideIcons.tags,
            color: AarastV3Color.primary,
            soft: AarastV3Color.primarySoft,
            title: categoryName ?? 'بدون بند',
            subtitle: 'البند',
          ),
          if (party != null)
            JourneyListRow(
              icon: cost.providerId == null
                  ? LucideIcons.user
                  : LucideIcons.store,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              title: party,
              subtitle: cost.providerId == null ? 'الجهة' : 'المزود',
              trailing: cost.providerId == null
                  ? null
                  : const Icon(
                      LucideIcons.chevronLeft,
                      size: 18,
                      color: AarastV3Color.textFaint,
                    ),
              onTap: cost.providerId == null
                  ? null
                  : () => context.push(
                      AppRouter.providerDetails(cost.providerId!),
                    ),
            ),
          if (cost.partyPhone != null)
            JourneyListRow(
              icon: LucideIcons.phone,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              title:
                  PhoneNumberUtils.directionalDisplay(cost.partyPhone) ??
                  cost.partyPhone!,
              subtitle: 'رقم التواصل',
            ),
          if (cost.note != null)
            JourneyListRow(
              icon: LucideIcons.fileText,
              color: AarastV3Color.textMuted,
              soft: AarastV3Color.line,
              title: cost.note!,
              subtitle: 'ملاحظة',
            ),
        ],
      ),
    );
  }
}

class _CostMoreMenu extends StatelessWidget {
  const _CostMoreMenu({
    required this.canCancel,
    required this.disabled,
    required this.onEdit,
    required this.onCancel,
  });

  final bool canCancel;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CostMenuAction>(
      enabled: !disabled,
      tooltip: 'المزيد',
      icon: const Icon(LucideIcons.moreHorizontal),
      onSelected: (action) {
        switch (action) {
          case _CostMenuAction.edit:
            onEdit();
          case _CostMenuAction.cancel:
            onCancel();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _CostMenuAction.edit,
          child: Row(
            children: [
              Icon(LucideIcons.pencil, size: 18),
              SizedBox(width: 10),
              Flexible(child: Text('تعديل التكلفة')),
            ],
          ),
        ),
        if (canCancel)
          const PopupMenuItem(
            value: _CostMenuAction.cancel,
            child: Row(
              children: [
                Icon(
                  LucideIcons.circleSlash2,
                  size: 18,
                  color: AarastV3Color.danger,
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'إلغاء التكلفة',
                    style: TextStyle(color: AarastV3Color.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _CostMenuAction { edit, cancel }
