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

    final services = _servicesInMotion(context);
    final now = appNow();
    // D59: the owner reads what they did; anyone else reads it unowned.
    final nothingPaid = context.ownerDid(
      'ما دفعت شي',
      'ما دفعتِ شي',
      groom: 'ما اندفع شي',
      bride: 'ما اندفع شي',
    );
    final rows = <Widget>[
      for (final cost in costs)
        _MoneyItemRow(
          key: ValueKey('money-item-${cost.id}'),
          icon: iconFor(
            provider.categoryById(cost.budgetCategoryId)?.name ??
                cost.categoryName,
          ),
          title: _itemTitle(cost),
          amount: _amount(context, cost.totalAmount, currency),
          paidRatio: moneyValue(cost.totalAmount) <= 0
              ? 0
              : moneyValue(cost.paidAmount) / moneyValue(cost.totalAmount),
          paidLine: cost.isCancelled
              ? 'ملغي'
              : moneyValue(cost.paidAmount) <= 0
              ? nothingPaid
              : moneyValue(cost.paidAmount) >= moneyValue(cost.totalAmount)
              ? 'خالص'
              : '${_whoPaid(context, provider.summary, cost)} ${_amount(context, cost.paidAmount, currency)}',
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
          paidLine: nothingPaid,
          note: (
            services[category.id]?.detail ?? 'ما انحجز',
            AarastV3Color.brandAccentStrong,
          ),
          // A row opens the thing it names. An item with a service under
          // way opens where that service is (its note says so); an item on
          // its own opens the item, whoever is reading. It used to open a
          // blank «agreement» form for whoever may manage the money: the
          // row looked the same and landed the reader in a creation form
          // they had not asked for. Adding the agreement is still one tap
          // away, from the item's own «أضف اتفاق».
          onTap: switch (services[category.id]) {
            final service? => () => context.push(
              AppRouter.providerRequests(planId, itemKey: service.key),
            ),
            null => () => context.push(
              AppRouter.moneyCategoryDetails(planId, category.id),
            ),
          },
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
              ? context.ownerDid(
                  'ما سلّمت شي',
                  'ما سلّمتِ شي',
                  groom: 'العريس ما سلّم شي',
                  bride: 'العروسة ما سلّمت شي',
                )
              : moneyValue(cost.paidAmount) >= moneyValue(cost.totalAmount)
              ? 'سُلّم كامل'
              : '${context.ownerDid('سلّمت', 'سلّمتِ', groom: 'العريس سلّم', bride: 'العروسة سلّمت')} ${_amount(context, cost.paidAmount, currency)}',
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
            emptyAction: provider.canManageBudget
                ? context.say('أضف أول بند', 'أضيفي أول بند')
                : null,
            onEmptyAction: provider.canManageBudget
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
          const SizedBox(height: AarastV3Space.x2),
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
        if (provider.canManageBudget) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyBox(
            padding: const EdgeInsets.all(AarastV3Space.x4),
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
                const SizedBox(height: AarastV3Space.x2),
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

  /// c02 names the wedding's item, the name the providers tab uses too. Who
  /// it is with is on the agreement's page; its own title only tells two
  /// agreements on one item apart, and stands in for the catch-all «أخرى».
  String _itemTitle(WeddingCost cost) {
    final item = provider.categoryById(cost.budgetCategoryId)?.name.trim();
    if (item == null || item.isEmpty || item == 'أخرى') return cost.title;
    final shared = provider.costs
        .where(
          (other) =>
              other.budgetCategoryId == cost.budgetCategoryId &&
              !other.isCancelled,
        )
        .length;
    return shared > 1 ? '$item · ${cost.title}' : item;
  }

  /// The plan's items whose service has started on the providers tab, with
  /// that tab's own words.
  Map<String, ProviderBoardRow> _servicesInMotion(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider?>();
    if (marketplace == null) return const {};
    final rows = buildProviderBoard(
      items: [
        for (final category in provider.categories)
          if (!category.isMahr)
            (
              id: category.id,
              name: category.name,
              providerCategoryIds: provider.providerCategoryIdsFor(category.id),
            ),
      ],
      costs: [
        for (final cost in provider.costs)
          (
            budgetCategoryId: cost.budgetCategoryId,
            providerId: cost.providerId,
            partyName: cost.partyName,
          ),
      ],
      costItemById: {
        for (final cost in provider.costs) cost.id: cost.budgetCategoryId,
      },
      reader: context.journeyProfile,
      quotes: marketplace.quotesForPlan(planId),
    );
    return {
      for (final row in rows)
        if (row.stage > 0 && row.budgetCategoryId != null)
          row.budgetCategoryId!: row,
    };
  }

  /// Who paid what was paid of an agreement (D59): the owner in their own
  /// voice (or named to anyone else), someone who paid for the owner by
  /// their name with the verb agreeing («الوالد دفع», «العروسة دفعت»). The
  /// server says whose money each payer's payments were.
  String _whoPaid(
    BuildContext context,
    MoneySummary summary,
    WeddingCost cost,
  ) {
    final profile = context.journeyProfile;
    final key = payerKey(cost.payer, cost.payerName);
    final group = summary.payers
        .where((group) => payerKey(group.payer, group.payerName) == key)
        .firstOrNull;
    if (group == null || group.ownerMoney) {
      return profile.ownerDid(
        'دفعت',
        'دفعتِ',
        groom: 'العريس دفع',
        bride: 'العروسة دفعت',
      );
    }
    return payerPaidLine(
      group.payer,
      payerLabel(
        group.payer,
        group.payerName,
        bridePlan: profile.isBride,
        owner: profile.readerIsOwner,
      ),
      profile,
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
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JourneyIconTile(
                icon: icon,
                color: muted ? AarastV3Color.textFaint : context.accent.primary,
                soft: muted ? AarastV3Color.line : context.accent.primarySoft,
              ),
              const SizedBox(width: AarastV3Space.x3),
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
                          const SizedBox(width: AarastV3Space.x1),
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
                          const SizedBox(width: AarastV3Space.x2),
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
                    const SizedBox(height: AarastV3Space.x2),
                    JourneyBar(
                      value: paidRatio,
                      color: muted
                          ? AarastV3Color.textFaint
                          : context.accent.primary,
                      height: 5,
                    ),
                    const SizedBox(height: AarastV3Space.x1),
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
