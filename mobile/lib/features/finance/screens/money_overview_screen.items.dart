part of 'money_overview_screen.dart';

// c02 «البنود» (D102, D105, D109): the wedding's items, each once. First how
// they stand against the budget and how complete the recorded cost is; then
// the items with an agreement (what is left on them and when), the items
// still at their estimate, and the mahr outside the budget. «أضف بند» last.

class _MoneyItemsTab extends StatefulWidget {
  const _MoneyItemsTab({
    required this.planId,
    required this.provider,
    required this.catalog,
  });

  final String planId;
  final FinanceProvider provider;
  final MoneyStarterCatalog catalog;

  @override
  State<_MoneyItemsTab> createState() => _MoneyItemsTabState();
}

enum _ItemsFilter { all, agreed, open }

class _MoneyItemsTabState extends State<_MoneyItemsTab> {
  /// Cancelled agreements, folded away like «اللي خلصت» in the tasks.
  bool _showCancelled = false;
  _ItemsFilter _filter = _ItemsFilter.all;

  @override
  Widget build(BuildContext context) {
    final planId = widget.planId;
    final provider = widget.provider;
    final catalog = widget.catalog;
    final summary = provider.summary;
    final currency = summary.currency;
    String money(Object? value) => _figure(context, value, currency);
    // c02: the mahr is its own section, outside the budget (C1): the
    // groom's agreement with the bride's family, or the bride's mahr coming
    // in.
    final mahrItemIds = {
      for (final category in provider.categories)
        if (category.isMahr) category.id,
    };
    final mahrCosts = [
      for (final cost in provider.costs)
        if (mahrItemIds.contains(cost.budgetCategoryId) && !cost.isCancelled)
          cost,
    ];
    // Each item's live agreements; a cancelled one no longer holds its
    // item (it waits again), and is folded away under its own count.
    final costsByItem = <String, List<WeddingCost>>{};
    for (final cost in provider.costs) {
      if (cost.isCancelled) continue;
      costsByItem.putIfAbsent(cost.budgetCategoryId, () => []).add(cost);
    }
    final cancelled = [
      for (final cost in provider.costs)
        if (cost.isCancelled && !mahrItemIds.contains(cost.budgetCategoryId))
          cost,
    ];
    final wedding = [
      for (final item in summary.categories)
        if (!item.isMahr) item,
    ];
    bool agreedOn(MoneyCategorySummary item) =>
        (costsByItem[item.categoryId]?.isNotEmpty ?? false) ||
        moneyValue(item.confirmedCost) > 0;
    final agreed = [
      for (final item in wedding)
        if (agreedOn(item)) item,
    ];
    final open = [
      for (final item in wedding)
        if (!agreedOn(item)) item,
    ];
    // D102: each item's next wedding due, as the server lists them.
    final dues = <String, List<MoneyObligation>>{};
    for (final line in summary.obligations) {
      final item = line.budgetCategoryId;
      if (line.isLoan || item == null) continue;
      dues.putIfAbsent(item, () => []).add(line);
    }
    final mahr = summary.mahr;
    final brideMahr = mahr != null && mahr.side == MahrSide.receives
        ? mahr
        : null;
    final starterIcons = {
      for (final group in catalog.groups)
        for (final item in group.categories) item.name: item.icon,
    };
    IconData iconFor(String? name) =>
        starterIcons[name?.trim()] ?? LucideIcons.wallet;

    final have = {
      for (final category in provider.categories) category.name.trim(),
    };
    // What most weddings have and this one does not list: the catalog's
    // recommended items first.
    final missingCommon = [
      for (final item in catalog.categories)
        if (item.recommended && !have.contains(item.name.trim())) item,
    ];
    final suggestions = [
      ...missingCommon,
      for (final item in catalog.categories)
        if (!item.recommended && !have.contains(item.name.trim())) item,
    ].take(3).toList(growable: false);

    final services = _servicesInMotion(context);
    final profile = context.journeyProfile;
    final manage = provider.canManageMoney;
    final manageBudget = provider.canManageBudget;
    void openItem(String id) =>
        context.push(AppRouter.moneyCategoryDetails(planId, id));

    Widget agreedRow(MoneyCategorySummary item) {
      final mine = costsByItem[item.categoryId] ?? const <WeddingCost>[];
      final count = mine.isNotEmpty ? mine.length : item.costsCount;
      final expense = mine.isNotEmpty && mine.every((cost) => cost.isExpense);
      final payers = {
        for (final cost in mine) payerKey(cost.payer, cost.payerName),
      };
      final group = payers.length == 1
          ? summary.payers
                .where(
                  (group) =>
                      payerKey(group.payer, group.payerName) == payers.single,
                )
                .firstOrNull
          : null;
      final lines = dues[item.categoryId] ?? const <MoneyObligation>[];
      final dated = [
        for (final line in lines)
          if (line.dueDate != null) line,
      ]..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      final outstanding = moneyValue(item.outstanding);
      final estimate = moneyValue(item.estimatedAmount);
      final ownEstimate =
          !item.estimateFromAllocation && item.estimatedAmount != null;
      return _ItemLine(
        key: ValueKey('money-item-${item.categoryId}'),
        icon: iconFor(item.name),
        title: item.name,
        private: mine.isNotEmpty && mine.every((cost) => cost.isPrivate),
        facts: [
          if (mine.length == 1)
            (mine.single.partyLabel ?? mine.single.title, null)
          else if (count > 1)
            (
              arabicCount(
                count,
                one: 'اتفاق واحد',
                two: 'اتفاقين',
                few: 'اتفاقات',
                many: 'اتفاق',
              ),
              null,
            ),
          if (group != null && !group.ownerMoney)
            (
              'على ${payerLabel(group.payer, group.payerName, bridePlan: profile.isBride, owner: profile.readerIsOwner)}',
              null,
            ),
        ],
        state: outstanding <= 0
            ? const [('خالص', AarastV3Color.mint)]
            : [
                // Joined: «باقي» never wraps away from its figure.
                ('باقي\u00A0${money(outstanding)}', AarastV3Color.ink),
                if (dated.isNotEmpty)
                  dated.first.isOverdue
                      ? ('متأخرة', AarastV3Color.danger)
                      : ('الجاية ${_dayWords(dated.first.dueDate!)}', null)
                else if (lines.any(
                  (line) => line.kind == MoneyObligationKind.undated,
                ))
                  ('بدون موعد', AarastV3Color.amber),
              ],
        // Against the item's own estimate: by how much, not the agreed
        // figure again (it is the row's own).
        under: !ownEstimate || moneyValue(item.confirmedCost) == estimate
            ? null
            : moneyValue(item.confirmedCost) > estimate
            ? (
                'أكثر من ${context.ownerDid('تقديرك', 'تقديرك', groom: 'التقدير', bride: 'التقدير')} بـ${money(moneyValue(item.confirmedCost) - estimate)}',
                AarastV3Color.danger,
              )
            : (
                'أقل من ${context.ownerDid('تقديرك', 'تقديرك', groom: 'التقدير', bride: 'التقدير')} بـ${money(estimate - moneyValue(item.confirmedCost))}',
                null,
              ),
        figure: money(item.confirmedCost),
        figureNote: expense ? 'مصروف' : 'اتفاق',
        onTap: () => openItem(item.categoryId),
      );
    }

    Widget openRow(MoneyCategorySummary item) {
      final service = services[item.categoryId];
      final market = item.providerCategoryIds.isNotEmpty;
      return _ItemLine(
        key: ValueKey('money-item-category-${item.categoryId}'),
        icon: iconFor(item.name),
        title: item.name,
        quiet: true,
        facts: [
          if (service != null)
            (service.detail, AarastV3Color.brandAccentStrong)
          else if (market && manage)
            (
              context.ownerDid(
                'ما طلبت عروض بعد',
                'ما طلبتِ عروض بعد',
                groom: 'ما في عروض بعد',
                bride: 'ما في عروض بعد',
              ),
              null,
            ),
        ],
        figure: item.estimate == null ? '—' : money(item.estimate),
        figureNote: item.estimate == null
            ? 'بدون تقدير'
            : item.estimateFromAllocation
            ? 'المخصص'
            : 'تقدير',
        onTap: () => openItem(item.categoryId),
      );
    }

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

    Widget listOf(List<Widget> rows) => JourneyBox(
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
    );

    final filter = _filter;
    final showAgreed = filter != _ItemsFilter.open;
    final showOpen = filter != _ItemsFilter.agreed;
    final nothing = wedding.isEmpty && mahrRows.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nothing)
          JourneyListState(
            phase: JourneyListPhase.empty,
            section: JourneySection.money,
            emptyTitle: 'ما في بنود بعد',
            emptyAction: manageBudget
                ? context.say('أضف أول بند', 'أضيفي أول بند')
                : null,
            onEmptyAction: manageBudget
                ? () => context.push(AppRouter.moneyCategoryCreate(planId))
                : null,
          )
        else ...[
          _ItemsBudgetBox(
            summary: summary,
            onBudget: manageBudget
                ? () => context.push(AppRouter.moneyBudget(planId))
                : null,
          ),
          const SizedBox(height: AarastV3Space.x3),
          _RecordedCostBox(
            summary: summary,
            missing: manageBudget
                ? [for (final item in missingCommon.take(3)) item.name]
                : const [],
            onExplain: () => showJourneySheet<void>(
              context: context,
              builder: (_) => const _ItemsExplainSheet(),
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          Wrap(
            spacing: AarastV3Space.x2,
            runSpacing: AarastV3Space.x2,
            children: [
              for (final (choice, label, count) in [
                (_ItemsFilter.all, 'الكل', wedding.length + mahrRows.length),
                (
                  _ItemsFilter.agreed,
                  context.ownerDid(
                    'اتفقت',
                    'اتفقتِ',
                    groom: 'عليها اتفاق',
                    bride: 'عليها اتفاق',
                  ),
                  agreed.length + mahrRows.length,
                ),
                (
                  _ItemsFilter.open,
                  context.ownerDid(
                    'ما اتفقت',
                    'ما اتفقتِ',
                    groom: 'بدون اتفاق',
                    bride: 'بدون اتفاق',
                  ),
                  open.length,
                ),
              ])
                JourneyChip(
                  key: ValueKey('money-items-filter-${choice.name}'),
                  label: '$label $count',
                  selected: filter == choice,
                  onTap: () => setState(() => _filter = choice),
                ),
            ],
          ),
          if (showAgreed && agreed.isNotEmpty) ...[
            JourneySectionTitle(
              context.ownerDid(
                'اتفقت عليها',
                'اتفقتِ عليها',
                groom: 'عليها اتفاق',
                bride: 'عليها اتفاق',
              ),
              action: arabicCount(
                agreed.length,
                one: 'بند واحد',
                two: 'بندين',
                few: 'بنود',
                many: 'بند',
              ),
              actionColor: AarastV3Color.textMuted,
            ),
            listOf([for (final item in agreed) agreedRow(item)]),
          ],
          if (showOpen && open.isNotEmpty) ...[
            JourneySectionTitle(
              context.ownerDid(
                'ما اتفقت عليها بعد',
                'ما اتفقتِ عليها بعد',
                groom: 'بدون اتفاق بعد',
                bride: 'بدون اتفاق بعد',
              ),
              action: 'بالتقدير',
              actionColor: AarastV3Color.textMuted,
            ),
            listOf([for (final item in open) openRow(item)]),
          ],
          if (showAgreed && mahrRows.isNotEmpty) ...[
            JourneySectionTitle(
              // Its row is «المهر»: the title says whose agreement it is.
              brideMahr != null
                  ? 'المهر يوصلك من العريس'
                  : 'الاتفاق مع أهل العروسة',
              action: 'برا الميزانية',
              actionColor: AarastV3Color.textMuted,
            ),
            JourneyBox(
              key: const ValueKey('money-mahr-section'),
              padding: EdgeInsets.zero,
              child: Column(children: mahrRows),
            ),
          ],
        ],
        if (cancelled.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x1),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('money-items-toggle-cancelled'),
              label: _showCancelled
                  ? 'خبّي الملغية'
                  : 'الملغية · ${cancelled.length}',
              icon: _showCancelled
                  ? LucideIcons.chevronUp
                  : LucideIcons.chevronDown,
              color: AarastV3Color.textMuted,
              onPressed: () => setState(() => _showCancelled = !_showCancelled),
            ),
          ),
          if (_showCancelled)
            listOf([
              for (final cost in cancelled)
                _MoneyItemRow(
                  key: ValueKey('money-item-${cost.id}'),
                  icon: iconFor(
                    provider.categoryById(cost.budgetCategoryId)?.name ??
                        cost.categoryName,
                  ),
                  title: _itemTitle(cost),
                  amount: _amount(context, cost.totalAmount, currency),
                  paidRatio: 0,
                  paidLine: 'ملغي',
                  note: null,
                  muted: true,
                  private: cost.isPrivate,
                  onTap: () =>
                      context.push(AppRouter.moneyCostDetails(planId, cost.id)),
                ),
            ]),
        ],
        // The server sends the agreements a page at a time; the rest load
        // here, so each item names who it is with.
        if (provider.hasMoreCosts) ...[
          const SizedBox(height: AarastV3Space.x2),
          Center(
            child: JourneyTextAction(
              key: const ValueKey('money-items-more'),
              label: provider.isLoadingMoreCosts ? 'يحمّل…' : 'باقي الاتفاقات',
              color: context.accent.primary,
              onPressed: provider.isLoadingMoreCosts
                  ? null
                  : provider.loadMoreCosts,
            ),
          ),
        ],
        if (manageBudget && showOpen) ...[
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
    final item = widget.provider
        .categoryById(cost.budgetCategoryId)
        ?.name
        .trim();
    if (item == null || item.isEmpty || item == 'أخرى') return cost.title;
    final shared = widget.provider.costs
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
  Map<String, ProviderBoardRow> _servicesInMotion(BuildContext context) => {
    for (final entry in moneyItemsOnBoard(
      context,
      widget.provider,
      widget.planId,
    ).entries)
      if (entry.value.stage > 0) entry.key: entry.value,
  };

  /// The day the cost's next payment is due, if one is pending.
  DateTime? _nextDueDay(FinanceProvider provider, WeddingCost cost) {
    final due =
        widget.provider.dueSchedules
            .where((schedule) => schedule.costId == cost.id)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (due.isNotEmpty) return due.first.dueDate;
    // The mahr's rest is usually weeks away, past the due list's 30 days:
    // the summary names its day.
    return widget.provider.summary.mahr?.nextDueAt;
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
                        // Flexible: a long note wraps at a large font,
                        // never runs off the card.
                        if (note != null)
                          Flexible(
                            child: Text(
                              note!.$1,
                              textAlign: TextAlign.end,
                              style: JourneyType.of(
                                JourneyType.small,
                                weight: JourneyType.bold,
                                color: note!.$2,
                              ),
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
