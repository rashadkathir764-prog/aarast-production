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
      padding: const EdgeInsets.all(16),
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
                : context.accent.primary,
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
    this.onTap,
  });

  final String title;
  final String line;
  final Object? amount;

  /// done, current (the next to pay), later, or reversed.
  final _EntryState state;

  /// Null when the row only shows (a viewer, a date nobody can change).
  final VoidCallback? onTap;
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
      button: entry.onTap != null,
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
            color: context.accent.primary,
            soft: context.accent.primarySoft,
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
          if (cost.quoteOfferId != null)
            JourneyListRow(
              key: const ValueKey('cost-booking-link'),
              icon: LucideIcons.messageCircle,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              title: 'الحجز والمحادثة',
              subtitle: 'العرض المقبول',
              trailing: const Icon(
                LucideIcons.chevronLeft,
                size: 18,
                color: AarastV3Color.textFaint,
              ),
              onTap: () => context.push(
                AppRouter.providerRequests(
                  cost.weddingPlanId,
                  itemKey: cost.budgetCategoryId,
                ),
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
    required this.disabled,
    required this.onEdit,
    required this.onRemove,
  });

  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      enabled: !disabled,
      tooltip: 'المزيد',
      icon: const Icon(LucideIcons.moreHorizontal),
      onSelected: (edit) => edit ? onEdit() : onRemove(),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: true,
          child: Row(
            children: [
              Icon(LucideIcons.pencil, size: 18),
              SizedBox(width: 10),
              Flexible(child: Text('تعديل الاتفاق')),
            ],
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('cost-remove'),
          value: false,
          child: Row(
            children: [
              const Icon(
                LucideIcons.trash2,
                size: 18,
                color: AarastV3Color.danger,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  context.say('شيل الاتفاق', 'شيلي الاتفاق'),
                  style: const TextStyle(color: AarastV3Color.danger),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _RemoveCostChoice { reverseFirst, cancel, delete }

/// w23: what removing an agreement can do. «بدّل المصور» is not offered:
/// moving a payment to another provider is wrong in the record.
class _RemoveCostSheet extends StatefulWidget {
  const _RemoveCostSheet({required this.title, required this.paid});

  final String title;

  /// What was paid on it, or null when nothing.
  final String? paid;

  @override
  State<_RemoveCostSheet> createState() => _RemoveCostSheetState();
}

class _RemoveCostSheetState extends State<_RemoveCostSheet> {
  late _RemoveCostChoice _choice = widget.paid == null
      ? _RemoveCostChoice.cancel
      : _RemoveCostChoice.reverseFirst;

  @override
  Widget build(BuildContext context) {
    final locked = widget.paid != null;
    final options = locked
        ? [
            (
              _RemoveCostChoice.reverseFirst,
              context.say('اعكس الدفعة أول', 'اعكسي الدفعة أول'),
              context.say(
                'لو سجلتها غلط. بعدها تقدر تشيله',
                'لو سجلتيها غلط. بعدها تقدرين تشيلينه',
              ),
              LucideIcons.undo2,
            ),
          ]
        : [
            (
              _RemoveCostChoice.cancel,
              context.say('ألغِه', 'ألغيه'),
              'يبقى في السجل ملغي، وتنلغي مواعيد دفعه',
              LucideIcons.circleSlash2,
            ),
            (
              _RemoveCostChoice.delete,
              context.say('احذفه نهائيًا', 'احذفيه نهائيًا'),
              'ينمسح من خطتك',
              LucideIcons.trash2,
            ),
          ];
    return JourneySheetBody(
      title: locked
          ? '${context.say('ما تقدر تشيل', 'ما تقدرين تشيلين')} ${widget.title}'
          : '${context.say('تشيل', 'تشيلين')} ${widget.title}؟',
      subtitle: locked
          ? 'عليه دفعات بـ ${widget.paid}. الاتفاق اللي عليه دفعات يبقى عشان سجلك يبقى صادق.'
          : 'ما عليه دفعات',
      children: [
        for (final (choice, title, line, icon) in options) ...[
          JourneyChoiceCard(
            key: ValueKey('cost-remove-${choice.name}'),
            title: title,
            subtitle: line,
            leading: Icon(
              icon,
              color: choice == _RemoveCostChoice.delete
                  ? AarastV3Color.danger
                  : context.accent.primary,
            ),
            selected: _choice == choice,
            onTap: () => setState(() => _choice = choice),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        JourneyButton(
          key: const ValueKey('cost-remove-confirm'),
          // The button names what it does, as the item's remove sheet does.
          label: options.firstWhere((option) => option.$1 == _choice).$2,
          background: _choice == _RemoveCostChoice.delete
              ? AarastV3Color.danger
              : context.accent.primary,
          expand: true,
          large: true,
          onPressed: () => Navigator.pop(context, _choice),
        ),
      ],
    );
  }
}
