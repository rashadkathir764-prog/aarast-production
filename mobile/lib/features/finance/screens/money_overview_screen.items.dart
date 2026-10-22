part of 'money_overview_screen.dart';

// c02 «البنود»: one list. Each agreement (a cost) with what is agreed, what
// is paid and the next thing about it; a budget category with no agreement
// yet reads «ما انحجز». Then «أضف بند»: the starter items the plan does not
// have, or any other.

class _MoneyItemsTab extends StatelessWidget {
  const _MoneyItemsTab({
    required this.planId,
    required this.provider,
    required this.catalog,
  });

  final String planId;
  final FinanceProvider provider;
  final MoneyStarterCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final currency = provider.summary.currency;
    final costs = [
      ...provider.costs.where((cost) => !cost.isCancelled),
      ...provider.costs.where((cost) => cost.isCancelled),
    ];
    final withCosts = {
      for (final cost in provider.costs) cost.budgetCategoryId,
    };
    final waiting = provider.categories
        .where((category) => !withCosts.contains(category.id))
        .toList(growable: false);
    final starterIcons = {
      for (final group in catalog.groups)
        for (final item in group.categories) item.name: item.icon,
    };
    IconData iconFor(String? name) =>
        starterIcons[name?.trim()] ?? LucideIcons.wallet;

    final have = {
      for (final category in provider.categories) category.name.trim(),
    };
    final suggestions = [
      for (final group in catalog.groups)
        for (final item in group.categories)
          if (!have.contains(item.name.trim())) item,
    ].take(3).toList(growable: false);

    final now = DateTime.now();
    final rows = <Widget>[
      for (final cost in costs)
        _MoneyItemRow(
          key: ValueKey('money-item-${cost.id}'),
          icon: iconFor(
            provider.categoryById(cost.budgetCategoryId)?.name ??
                cost.categoryName,
          ),
          title: cost.title,
          amount: _amount(context, cost.totalAmount, currency),
          paidRatio: moneyValue(cost.totalAmount) <= 0
              ? 0
              : moneyValue(cost.paidAmount) / moneyValue(cost.totalAmount),
          paidLine: cost.isCancelled
              ? 'ملغي'
              : moneyValue(cost.paidAmount) <= 0
              ? 'ما دفعت شي'
              : moneyValue(cost.paidAmount) >= moneyValue(cost.totalAmount)
              ? 'خالص'
              : 'دفعت ${_amount(context, cost.paidAmount, currency)}',
          note: cost.isCancelled ? null : _nextDueNote(provider, cost, now),
          muted: cost.isCancelled,
          onTap: () =>
              context.push(AppRouter.moneyCostDetails(planId, cost.id)),
        ),
      for (final category in waiting)
        _MoneyItemRow(
          key: ValueKey('money-item-category-${category.id}'),
          icon: iconFor(category.name),
          title: category.name,
          amount: category.allocatedAmount == null
              ? ''
              : _amount(context, category.allocatedAmount, currency),
          paidRatio: 0,
          paidLine: 'ما دفعت شي',
          note: ('ما انحجز', AarastV3Color.brandAccentStrong),
          onTap: provider.canManageMoney
              ? () => context.push(
                  AppRouter.moneyCostCreate(planId, categoryId: category.id),
                )
              : () => context.push(
                  AppRouter.moneyCategoryDetails(planId, category.id),
                ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows.isEmpty)
          JourneyListState(
            phase: JourneyListPhase.empty,
            section: JourneySection.money,
            emptyTitle: 'ما في بنود بعد',
            emptyAction: provider.canManageMoney ? 'أضف أول بند' : null,
            onEmptyAction: provider.canManageMoney
                ? () => context.push(AppRouter.moneyCategoryCreate(planId))
                : null,
          )
        else
          JourneyBox(
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
                  rows[index],
                ],
              ],
            ),
          ),
        if (provider.hasMoreCosts) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              label: 'عرض كل التكاليف',
              color: AarastV3Color.primary,
              onPressed: () => context.push(AppRouter.moneyCosts(planId)),
            ),
          ),
        ],
        if (provider.canManageMoney) ...[
          const SizedBox(height: 12),
          JourneyBox(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أضف بند',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in suggestions)
                      JourneyChip(
                        label: item.name,
                        icon: item.icon,
                        selected: false,
                        onTap: () => context.push(
                          AppRouter.moneyCategoryCreate(planId),
                          extra: item.name,
                        ),
                      ),
                    JourneyChip(
                      key: const ValueKey('money-empty-add-cost'),
                      label: 'بند ثاني',
                      icon: LucideIcons.plus,
                      selected: false,
                      onTap: () =>
                          context.push(AppRouter.moneyCategoryCreate(planId)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// «دفعة بعد 5 أيام» or «دفعة متأخرة» from the cost's own schedules.
  (String, Color)? _nextDueNote(
    FinanceProvider provider,
    WeddingCost cost,
    DateTime now,
  ) {
    final due =
        provider.dueSchedules
            .where((schedule) => schedule.costId == cost.id)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (due.isEmpty) return null;
    final next = due.first;
    if (next.isOverdueAt(now)) return ('دفعة متأخرة', AarastV3Color.danger);
    final days = DateUtils.dateOnly(
      next.dueDate,
    ).difference(DateUtils.dateOnly(now)).inDays;
    final when = days <= 0
        ? 'اليوم'
        : days == 1
        ? 'بكرة'
        : 'بعد ${arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
    return ('دفعة $when', AarastV3Color.brandAccentStrong);
  }
}

class _MoneyItemRow extends StatelessWidget {
  const _MoneyItemRow({
    required this.icon,
    required this.title,
    required this.amount,
    required this.paidRatio,
    required this.paidLine,
    required this.onTap,
    this.note,
    this.muted = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String amount;
  final double paidRatio;
  final String paidLine;
  final (String, Color)? note;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = muted ? AarastV3Color.textFaint : AarastV3Color.ink;
    return Semantics(
      button: true,
      label: [
        title,
        amount,
        paidLine,
        ?note?.$1,
      ].where((s) => s.isNotEmpty).join('، '),
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JourneyIconTile(
                icon: icon,
                color: muted ? AarastV3Color.textFaint : AarastV3Color.primary,
                soft: muted ? AarastV3Color.line : AarastV3Color.primarySoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: JourneyType.of(
                              JourneyType.bodyLarge,
                              weight: JourneyType.bold,
                              color: ink,
                            ),
                          ),
                        ),
                        if (amount.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          // An amount shrinks before it pushes past the row.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                amount,
                                style: JourneyType.of(
                                  JourneyType.bodyLarge,
                                  weight: JourneyType.bold,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    JourneyBar(
                      value: paidRatio,
                      color: muted
                          ? AarastV3Color.textFaint
                          : AarastV3Color.primary,
                      height: 5,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            paidLine,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                        ),
                        if (note != null)
                          Text(
                            note!.$1,
                            style: JourneyType.of(
                              JourneyType.small,
                              weight: JourneyType.bold,
                              color: note!.$2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
