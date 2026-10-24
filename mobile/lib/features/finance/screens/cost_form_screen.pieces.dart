part of 'cost_form_screen.dart';

/// What the item keeps after this agreement (an edited agreement's old
/// amount counted back when it stays in the same item).
num _leftInCategory(BudgetCategory category, WeddingCost? editing, int total) {
  final left = moneyValue(category.remainingAllocation);
  final previous = editing?.budgetCategoryId == category.id
      ? moneyValue(editing?.totalAmount)
      : 0;
  return left + previous - total;
}

/// The agreement's name when none is typed: who it is with, else the item.
String? _titleFallback(
  _PartyKind kind,
  String? providerName,
  String partyName,
  BudgetCategory? category,
) {
  if (kind == _PartyKind.provider && providerName != null) return providerName;
  final party = partyName.trim();
  if (kind == _PartyKind.external && party.isNotEmpty) return party;
  return category?.name;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: JourneyType.of(
          JourneyType.small,
          weight: JourneyType.bold,
          color: AarastV3Color.textMuted,
        ),
      ),
    );
  }
}

/// «البند»: the plan's items as chips, and a new one.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.error,
    required this.onSelect,
    required this.onCreate,
  });

  final List<BudgetCategory> categories;
  final String? selectedId;
  final String? error;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('البند'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in categories)
              JourneyChip(
                key: ValueKey('cost-category-${category.id}'),
                label: category.name,
                selected: category.id == selectedId,
                onTap: () => onSelect(category.id),
              ),
            JourneyChip(
              key: const ValueKey('cost-category-create'),
              label: 'بند جديد',
              icon: LucideIcons.plus,
              onTap: onCreate,
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ),
      ],
    );
  }
}

/// «مع مين؟»: a provider on Aarast, someone outside it, or nobody yet.
class _PartySection extends StatelessWidget {
  const _PartySection({
    required this.kind,
    required this.onKind,
    required this.providerName,
    required this.onPickProvider,
    required this.nameController,
    required this.phoneController,
    required this.error,
  });

  final _PartyKind kind;
  final ValueChanged<_PartyKind> onKind;
  final String? providerName;
  final VoidCallback onPickProvider;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('مع مين؟'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in const [
              (_PartyKind.provider, 'من اعّرست'),
              (_PartyKind.external, 'برا اعّرست'),
              (_PartyKind.none, 'بدون'),
            ])
              JourneyChip(
                key: ValueKey('cost-party-${value.name}'),
                label: label,
                selected: kind == value,
                onTap: () => onKind(value),
              ),
          ],
        ),
        if (kind == _PartyKind.provider) ...[
          const SizedBox(height: 10),
          JourneyBox(
            key: const ValueKey('cost-provider-card'),
            padding: EdgeInsets.zero,
            child: JourneyListRow(
              icon: LucideIcons.store,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              title:
                  providerName ?? context.say('اختر المزود', 'اختاري المزود'),
              subtitle: providerName == null ? 'من سوق اعّرست' : 'من اعّرست',
              trailing: Text(
                providerName == null ? context.say('اختر', 'اختاري') : 'تغيير',
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: context.accent.primary,
                ),
              ),
              onTap: onPickProvider,
            ),
          ),
        ],
        if (kind == _PartyKind.external) ...[
          const SizedBox(height: 10),
          JourneyTextField(
            key: const ValueKey('cost-party-name'),
            label: 'اسمه',
            hint: 'مثلًا: محل الورد',
            controller: nameController,
            icon: LucideIcons.user,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          JourneyTextField(
            key: const ValueKey('cost-party-phone'),
            label: context.say('رقمه (لو تبي)', 'رقمه (لو تبين)'),
            controller: phoneController,
            icon: LucideIcons.phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ),
      ],
    );
  }
}

/// An accepted quote's amount: agreed, so not typed again.
class _QuoteTotal extends StatelessWidget {
  const _QuoteTotal({required this.amount, required this.currency});

  final num amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final value = amount.round();
    return JourneyBox(
      key: const ValueKey('cost-quote-total'),
      color: context.accent.primarySoft,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.say('بكم اتفقت؟', 'بكم اتفقتِ؟'),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${formatMoneyInputValue(value)} ${currencyLabelAr(currency)}',
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
                color: context.accent.primaryDark,
              ),
            ),
          ),
          Text(
            context.say(
              'مثبت من العرض اللي وافقت عليه',
              'مثبت من العرض اللي وافقتِ عليه',
            ),
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: context.accent.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// «أقل من بندك بـ 100 ألف»: the agreement against what the item has left.
class _BudgetLine extends StatelessWidget {
  const _BudgetLine({required this.left, required this.currency});

  /// What stays in the item after this agreement; negative when over.
  final num left;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final over = left < 0;
    final amount = compactMoneyParts(
      left.abs(),
      currencyCode: currency,
    ).plainText;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        left == 0
            ? 'بقد بندك بالضبط'
            : over
            ? 'أكثر من بندك بـ $amount'
            : 'أقل من بندك بـ $amount',
        key: const ValueKey('cost-budget-line'),
        style: JourneyType.of(
          JourneyType.small,
          weight: JourneyType.bold,
          color: over ? AarastV3Color.danger : AarastV3Color.mint,
        ),
      ),
    );
  }
}

/// Picks a provider from the marketplace, searching by name.
class _ProviderPicker extends StatefulWidget {
  const _ProviderPicker({required this.marketplace});

  final ProviderMarketplaceProvider marketplace;

  @override
  State<_ProviderPicker> createState() => _ProviderPickerState();
}

class _ProviderPickerState extends State<_ProviderPicker> {
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<MarketplaceProvider> _providers = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _failed = false;
  int _page = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _loadGeneration += 1;
    _searchDebounce?.cancel();
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(reset: true),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_isLoadingMore || !_hasMore)) return;
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    final nextPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _isLoading = true;
        _failed = false;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final results = await widget.marketplace.searchProvidersForMoneyLink(
        search: _searchController.text.trim(),
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _providers = reset ? results : [..._providers, ...results];
        _page = nextPage;
        _hasMore = results.length == _pageSize;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget list;
    if (_isLoading) {
      list = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.providers,
      );
    } else if (_failed && _providers.isEmpty) {
      list = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.providers,
        onRetry: () => _load(reset: true),
      );
    } else if (_providers.isEmpty) {
      list = const JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.providers,
        emptyIcon: LucideIcons.store,
        emptyTitle: 'ما لقينا أحد بهذا الاسم',
      );
    } else {
      list = JourneyBox(
        padding: EdgeInsets.zero,
        child: JourneyList(
          children: [
            for (final provider in _providers)
              JourneyListRow(
                key: ValueKey('cost-provider-option-${provider.id}'),
                icon: LucideIcons.store,
                color: AarastV3Color.cobalt,
                soft: AarastV3Color.cobaltSoft,
                title: provider.businessName,
                subtitle: provider.city?.nameAr ?? 'من اعّرست',
                onTap: () => Navigator.pop(context, provider),
              ),
          ],
        ),
      );
    }
    return JourneySheetBody(
      title: context.say('مع مين اتفقت؟', 'مع مين اتفقتِ؟'),
      children: [
        JourneyTextField(
          key: const ValueKey('cost-provider-search'),
          label: context.say('ابحث بالاسم', 'ابحثي بالاسم'),
          controller: _searchController,
          icon: LucideIcons.search,
          autofocus: true,
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 12),
        list,
        if (_hasMore && _providers.isNotEmpty && !_isLoading)
          Center(
            child: JourneyTextAction(
              label: _isLoadingMore ? 'نجيب أكثر…' : 'مزودين أكثر',
              color: context.accent.primary,
              onPressed: _isLoadingMore ? null : () => _load(reset: false),
            ),
          ),
      ],
    );
  }
}

/// «تفاصيل أكثر»: who pays, whether it is private, when it was agreed, and a
/// note.
class _MoreDetails extends StatelessWidget {
  const _MoreDetails({
    required this.payer,
    required this.onPayer,
    required this.payerNameController,
    required this.canBePrivate,
    required this.isPrivate,
    required this.onPrivate,
    required this.agreementDate,
    required this.onPickAgreementDate,
    required this.noteController,
  });

  final String payer;
  final ValueChanged<String> onPayer;
  final TextEditingController payerNameController;
  final bool canBePrivate;
  final bool isPrivate;
  final ValueChanged<bool> onPrivate;
  final DateTime? agreementDate;
  final VoidCallback onPickAgreementDate;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const _FieldLabel('مين يدفعه؟'),
        Wrap(
          key: const ValueKey('cost-payer'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in CostPayerOption.values)
              JourneyChip(
                label: label,
                selected: payer == value,
                onTap: () => onPayer(value),
              ),
          ],
        ),
        if (payer == 'FAMILY' || payer == 'OTHER') ...[
          const SizedBox(height: 10),
          JourneyTextField(
            label: 'مين بالضبط؟',
            hint: context.say('مثلًا: الوالد', 'مثلًا: الوالدة'),
            controller: payerNameController,
            icon: LucideIcons.user,
          ),
        ],
        // V1 checklist 4.10: the owner or partner may keep a new cost to
        // themselves.
        if (canBePrivate) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('cost-private'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(LucideIcons.lock),
            title: const Text('خاص بي'),
            subtitle: const Text('ما يشوفه شريكك ولا يدخل في أرقامه.'),
            value: isPrivate,
            onChanged: onPrivate,
          ),
        ],
        const SizedBox(height: 12),
        JourneyPickerField(
          key: const ValueKey('cost-agreement-date'),
          label: 'متى اتفقتوا؟',
          value: agreementDate == null
              ? null
              : formatArabicWeekdayDayMonth(agreementDate!),
          placeholder: context.say('اختر اليوم', 'اختاري اليوم'),
          icon: LucideIcons.calendarDays,
          onTap: onPickAgreementDate,
        ),
        const SizedBox(height: 12),
        JourneyTextField(
          key: const ValueKey('cost-note'),
          label: 'ملاحظة',
          controller: noteController,
          maxLength: 1000,
        ),
      ],
    );
  }
}
