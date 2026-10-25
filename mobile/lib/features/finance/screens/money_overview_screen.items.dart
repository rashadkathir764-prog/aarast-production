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
    // c02: the mahr is its own section above «عرسك» (C1): the groom's
    // agreement with the bride's family, or the bride's mahr coming in.
    final mahrItemIds = {
      for (final category in provider.categories)
        if (category.isMahr) category.id,
    };
    final mahrCosts = [
      for (final cost in provider.costs)
        if (mahrItemIds.contains(cost.budgetCategoryId) && !cost.isCancelled)
          cost,
    ];
    final costs = [
      ...provider.costs.where(
        (cost) =>
            !cost.isCancelled && !mahrItemIds.contains(cost.budgetCategoryId),
      ),
      ...provider.costs.where(
        (cost) =>
            cost.isCancelled && !mahrItemIds.contains(cost.budgetCategoryId),
      ),
    ];
    final withCosts = {
      for (final cost in provider.costs) cost.budgetCategoryId,
    };
    final waiting = provider.categories
        .where(
          (category) => !category.isMahr && !withCosts.contains(category.id),
        )
        .toList(growable: false);
    final mahr = provider.summary.mahr;
    final brideMahr = mahr != null && mahr.side == MahrSide.receives
        ? mahr
        : null;
    final hasMahrSection = mahrCosts.isNotEmpty || brideMahr != null;
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
              ? context.say('ما دفعت شي', 'ما دفعتِ شي')
              : moneyValue(cost.paidAmount) >= moneyValue(cost.totalAmount)
              ? 'خالص'
              : '${context.say('دفعت', 'دفعتِ')} ${_amount(context, cost.paidAmount, currency)}',
          note: cost.isCancelled ? null : _nextDueNote(provider, cost, now),
          muted: cost.isCancelled,
          private: cost.isPrivate,
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
          paidLine: context.say('ما دفعت شي', 'ما دفعتِ شي'),
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

    String? mahrDue(DateTime? day) =>
        day == null ? null : 'الباقي ${formatArabicDayMonth(day)}';
    final mahrRows = <Widget>[
      for (final cost in mahrCosts)
        _MoneyItemRow(
          key: ValueKey('money-item-mahr-${cost.id}'),
          icon: LucideIcons.heartHandshake,
          title: cost.title,
          amount: _amount(context, cost.totalAmount, currency),
          paidRatio: moneyValue(cost.totalAmount) <= 0
              ? 0
              : moneyValue(cost.paidAmount) / moneyValue(cost.totalAmount),
          paidLine: moneyValue(cost.paidAmount) <= 0
              ? context.say('ما سلّمت شي', 'ما سلّمتِ شي')
              : moneyValue(cost.paidAmount) >= moneyValue(cost.totalAmount)
              ? 'سُلّم كامل'
              : '${context.say('سلّمت', 'سلّمتِ')} ${_amount(context, cost.paidAmount, currency)}',
          note: switch (mahrDue(_nextDueDay(provider, cost))) {
            final due? => (due, AarastV3Color.brandAccentStrong),
            null => null,
          },
          private: cost.isPrivate,
          onTap: () =>
              context.push(AppRouter.moneyCostDetails(planId, cost.id)),
        ),
      if (brideMahr != null)
        _MoneyItemRow(
          key: const ValueKey('money-item-mahr-received'),
          icon: LucideIcons.heartHandshake,
          title: 'المهر',
          amount: _amount(context, brideMahr.total, currency),
          paidRatio: moneyValue(brideMahr.total) <= 0
              ? 0
              : moneyValue(brideMahr.settled) / moneyValue(brideMahr.total),
          paidLine: 'وصلك ${_amount(context, brideMahr.settled, currency)}',
          note: switch (mahrDue(brideMahr.nextDueAt)) {
            final due? => (due, AarastV3Color.brandAccentStrong),
            null => null,
          },
          onTap: () => context.push(AppRouter.moneyFunding(planId)),
        ),
    ];

    Widget sectionTitle(String title, String? total) => JourneySectionTitle(
      title,
      action: total,
      actionColor: AarastV3Color.textMuted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasMahrSection) ...[
          sectionTitle(
            brideMahr != null
                ? 'المهر يوصلك من العريس'
                : 'الاتفاق مع أهل العروسة',
            mahr == null ? null : _amount(context, mahr.total, currency),
          ),
          JourneyBox(
            key: const ValueKey('money-mahr-section'),
            padding: EdgeInsets.zero,
            child: Column(children: mahrRows),
          ),
          sectionTitle(
            'عرسك',
            provider.summary.budget.total == null
                ? null
                : _amount(context, provider.summary.budget.total, currency),
          ),
        ],
        if (rows.isEmpty)
          JourneyListState(
            phase: JourneyListPhase.empty,
            section: JourneySection.money,
            emptyTitle: 'ما في بنود بعد',
            emptyAction: provider.canManageMoney
                ? context.say('أضف أول بند', 'أضيفي أول بند')
                : null,
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
        // The server sends the agreements a page at a time; the rest load
        // here, in the same list.
        if (provider.hasMoreCosts) ...[
          const SizedBox(height: 8),
          Center(
            child: JourneyTextAction(
              key: const ValueKey('money-items-more'),
              label: provider.isLoadingMoreCosts ? 'يحمّل…' : 'باقي البنود',
              color: context.accent.primary,
              onPressed: provider.isLoadingMoreCosts
                  ? null
                  : provider.loadMoreCosts,
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
                  context.say('أضف بند', 'أضيفي بند'),
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

  /// The day the cost's next payment is due, if one is pending.
  DateTime? _nextDueDay(FinanceProvider provider, WeddingCost cost) {
    final due =
        provider.dueSchedules
            .where((schedule) => schedule.costId == cost.id)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (due.isNotEmpty) return due.first.dueDate;
    // The mahr's rest is usually weeks away, past the due list's 30 days:
    // the summary names its day.
    return provider.summary.mahr?.nextDueAt;
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
    this.private = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String amount;
  final double paidRatio;
  final String paidLine;
  final (String, Color)? note;
  final bool muted;

  /// V1 checklist 4.10: a cost only its owner sees carries a lock. The
  /// design draws no private item; the lock is the shipped privacy cue.
  final bool private;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = muted ? AarastV3Color.textFaint : AarastV3Color.ink;
    return Semantics(
      button: true,
      label: [
        title,
        if (private) 'خاص بك',
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
                color: muted ? AarastV3Color.textFaint : context.accent.primary,
                soft: muted ? AarastV3Color.line : context.accent.primarySoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (private) ...[
                          const Icon(
                            LucideIcons.lock,
                            key: ValueKey('cost-private-lock'),
                            size: 14,
                            color: AarastV3Color.textMuted,
                          ),
                          const SizedBox(width: 4),
                        ],
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
                          : context.accent.primary,
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
