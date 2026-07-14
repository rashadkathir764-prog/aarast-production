import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/providers/marketplace_provider.dart';
import '../models/cost_draft_intent.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_widgets.dart';

enum _PartyKind { none, provider, external }

class CostFormScreen extends StatefulWidget {
  const CostFormScreen({
    required this.weddingPlanId,
    this.cost,
    this.intent,
    this.initialCategoryId,
    super.key,
  });

  final String weddingPlanId;
  final WeddingCost? cost;
  final CostDraftIntent? intent;
  final String? initialCategoryId;

  @override
  State<CostFormScreen> createState() => _CostFormScreenState();
}

class _CostFormScreenState extends State<CostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _initialPaymentController = TextEditingController();
  final _partyNameController = TextEditingController();
  final _partyPhoneController = TextEditingController();
  final _noteController = TextEditingController();

  String? _categoryId;
  String? _providerId;
  String? _providerName;
  String? _quoteOfferId;
  _PartyKind _partyKind = _PartyKind.none;
  DateTime? _agreementDate;
  DateTime? _dueDate;
  bool _quoteCurrencyResolved = false;
  String? _quoteCurrencyWarning;

  bool get _editing => widget.cost != null;

  @override
  void initState() {
    super.initState();
    final cost = widget.cost;
    final intent = widget.intent;
    _categoryId =
        widget.initialCategoryId ??
        intent?.budgetCategoryId ??
        cost?.budgetCategoryId;
    _titleController.text = intent?.title ?? cost?.title ?? '';
    _totalController.text = intent?.totalAmount ?? cost?.totalAmount ?? '';
    _initialPaymentController.text = intent?.initialPaymentAmount ?? '';
    _partyNameController.text =
        intent?.externalPartyName ?? cost?.partyName ?? '';
    _partyPhoneController.text =
        intent?.externalPartyPhone ?? cost?.partyPhone ?? '';
    _noteController.text = intent?.note ?? cost?.note ?? '';
    _providerId = intent?.providerId ?? cost?.providerId;
    _providerName = intent?.providerName ?? cost?.providerName;
    _quoteOfferId = intent?.quoteOfferId ?? cost?.quoteOfferId;
    _agreementDate = cost?.agreementDate;
    _dueDate = cost?.dueDate ?? intent?.firstPaymentDueDate;
    _partyKind = _providerId != null
        ? _PartyKind.provider
        : _partyNameController.text.trim().isNotEmpty
        ? _PartyKind.external
        : _PartyKind.none;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _initialPaymentController.dispose();
    _partyNameController.dispose();
    _partyPhoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!_quoteCurrencyResolved &&
        provider.loadedPlanId == widget.weddingPlanId &&
        !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveQuoteCurrency(provider.summary.currency);
      });
    }
    final accessBlock = financeWriteAccessBlock(
      context: context,
      provider: provider,
      weddingPlanId: widget.weddingPlanId,
    );
    if (accessBlock != null) return accessBlock;

    return AarastPageScaffold(
      title: _editing ? 'تعديل التكلفة' : 'إضافة تكلفة',
      subtitle: 'سجّل الاتفاق مرة واحدة، ثم أضف دفعاته ومواعيده من داخله.',
      showBack: true,
      onBack: () => context.pop(false),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (widget.intent?.cameFromAcceptedQuote == true) ...[
              const MoneyMessageBanner(
                message:
                    'تمت تعبئة هذه البيانات من عرض وافقت عليه. لن يُحفظ شيء حتى تضغط حفظ التكلفة.',
              ),
              const SizedBox(height: 12),
            ],
            if (_quoteCurrencyWarning != null) ...[
              MoneyMessageBanner(message: _quoteCurrencyWarning!, error: true),
              const SizedBox(height: 12),
            ],
            if (provider.errorMessage != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (provider.categories.isEmpty)
                    _NoCategory(
                      onCreate: () async {
                        final finance = context.read<FinanceProvider>();
                        final changed = await context.push<bool>(
                          AppRouter.moneyCategoryCreate(widget.weddingPlanId),
                        );
                        if (changed == true && mounted) {
                          await finance.loadMoney(widget.weddingPlanId);
                        }
                      },
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue:
                          provider.categories.any(
                            (category) => category.id == _categoryId,
                          )
                          ? _categoryId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف *',
                        prefixIcon: Icon(LucideIcons.tags),
                      ),
                      items: [
                        for (final category in provider.categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() => _categoryId = value),
                      validator: (value) =>
                          value == null ? 'اختر تصنيف التكلفة' : null,
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم التكلفة *',
                      hintText: 'مثال: حجز القاعة',
                      prefixIcon: Icon(LucideIcons.receipt),
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'اكتب اسم التكلفة'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _totalController,
                    key: const Key('cost-total-amount'),
                    readOnly: _quoteOfferId != null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText:
                          'إجمالي التكلفة (${currencyLabelAr(provider.summary.currency)}) *',
                      helperText: _quoteOfferId != null
                          ? 'القيمة مثبتة لأنها مرتبطة بعرض سعر مقبول.'
                          : null,
                      prefixIcon: const Icon(LucideIcons.coins),
                    ),
                    validator: (value) {
                      final amount = moneyValue(value);
                      if (amount <= 0) return 'اكتب تكلفة أكبر من صفر';
                      final paid = moneyValue(widget.cost?.paidAmount);
                      if (_editing && amount < paid) {
                        return 'الإجمالي لا يمكن أن يقل عن المدفوع';
                      }
                      return null;
                    },
                  ),
                  if (!_editing) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _initialPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText:
                            'دفعة أولى (${currencyLabelAr(provider.summary.currency)}) إن دفعت منها الآن',
                        helperText: 'إن لم تدفع شيئًا الآن، اترك الحقل فارغًا.',
                        prefixIcon: const Icon(LucideIcons.banknote),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final paid = moneyValue(text);
                        if (paid <= 0) return 'الدفعة يجب أن تكون أكبر من صفر';
                        if (paid > moneyValue(_totalController.text)) {
                          return 'الدفعة لا يمكن أن تتجاوز التكلفة';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'الجهة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<_PartyKind>(
                    segments: const [
                      ButtonSegment(
                        value: _PartyKind.none,
                        label: Text('بدون جهة'),
                        icon: Icon(LucideIcons.userX),
                      ),
                      ButtonSegment(
                        value: _PartyKind.provider,
                        label: Text('مزود'),
                        icon: Icon(LucideIcons.store),
                      ),
                      ButtonSegment(
                        value: _PartyKind.external,
                        label: Text('خارجية'),
                        icon: Icon(LucideIcons.user),
                      ),
                    ],
                    selected: {_partyKind},
                    onSelectionChanged: (value) {
                      setState(() {
                        _partyKind = value.first;
                        if (_partyKind != _PartyKind.provider) {
                          _providerId = null;
                          _providerName = null;
                          _quoteOfferId = null;
                        }
                        if (_partyKind != _PartyKind.external) {
                          _partyNameController.clear();
                          _partyPhoneController.clear();
                        }
                      });
                    },
                  ),
                  if (_partyKind == _PartyKind.provider) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickProvider,
                      icon: const Icon(LucideIcons.search),
                      label: Text(
                        _providerName == null
                            ? 'اختيار مزود من أعرست'
                            : _providerName!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_providerId == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'اختر مزودًا حقيقيًا من السوق.',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppTheme.danger),
                        ),
                      ),
                  ],
                  if (_partyKind == _PartyKind.external) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _partyNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجهة *',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      validator: (value) =>
                          _partyKind == _PartyKind.external &&
                              value?.trim().isEmpty == true
                          ? 'اكتب اسم الجهة'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _partyPhoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف (اختياري)',
                        prefixIcon: Icon(LucideIcons.phone),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DateField(
                    label: 'تاريخ الاتفاق (اختياري)',
                    value: _agreementDate,
                    onTap: () => _pickDate(agreement: true),
                  ),
                  const SizedBox(height: 10),
                  _DateField(
                    label: 'تاريخ الاستحقاق (اختياري)',
                    value: _dueDate,
                    onTap: () => _pickDate(agreement: false),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      prefixIcon: Icon(LucideIcons.stickyNote),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: provider.isSubmitting ? null : _save,
              icon: provider.isSubmitting
                  ? const AarastInlineSpinner(color: Colors.white)
                  : const Icon(LucideIcons.check),
              label: Text(provider.isSubmitting ? 'جاري الحفظ' : 'حفظ التكلفة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProvider() async {
    final marketplace = context.read<ProviderMarketplaceProvider?>();
    if (marketplace == null) {
      AarastToast.showError(context, 'سوق المزودين غير متاح الآن.');
      return;
    }
    if (marketplace.providers.isEmpty && !marketplace.isLoading) {
      await marketplace.loadMarketplace(includeAccountData: false);
    }
    if (!mounted) return;
    final selected = await showAarastBottomSheet<MarketplaceProvider>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProviderPicker(marketplace: marketplace),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _providerId = selected.id;
      _providerName = selected.businessName;
      if (widget.intent?.providerId != selected.id) _quoteOfferId = null;
    });
  }

  void _resolveQuoteCurrency(String planCurrency) {
    if (_quoteCurrencyResolved) return;
    _quoteCurrencyResolved = true;
    final intent = widget.intent;
    final quoteCurrency = intent?.currency?.trim().toUpperCase();
    final canonicalPlanCurrency = planCurrency.trim().toUpperCase();
    if (intent?.cameFromAcceptedQuote != true ||
        quoteCurrency == null ||
        quoteCurrency.isEmpty ||
        quoteCurrency == canonicalPlanCurrency) {
      return;
    }
    if (_totalController.text.trim() == intent?.totalAmount?.trim()) {
      _totalController.clear();
    }
    setState(() {
      _quoteOfferId = null;
      _quoteCurrencyWarning =
          'عرض السعر بعملة ${currencySpokenLabelAr(quoteCurrency)}، وميزانية الخطة بعملة ${currencySpokenLabelAr(canonicalPlanCurrency)}. أدخل المبلغ بعد تحويله إلى عملة الخطة؛ ستبقى التكلفة مرتبطة بالمزود دون ربط المبلغ بعرض مختلف العملة.';
    });
  }

  Future<void> _pickDate({required bool agreement}) async {
    final current = agreement ? _agreementDate : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ar'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (agreement) {
        _agreementDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) return;
    if (_partyKind == _PartyKind.provider && _providerId == null) {
      AarastToast.showInfo(context, 'اختر مزودًا من أعرست.');
      return;
    }
    final provider = context.read<FinanceProvider>();
    final total = _totalController.text.replaceAll(',', '').trim();
    final initial = _initialPaymentController.text.replaceAll(',', '').trim();
    final cost = widget.cost;
    final ok = cost == null
        ? await provider.createCost(
                planId: widget.weddingPlanId,
                budgetCategoryId: _categoryId!,
                title: _titleController.text.trim(),
                totalAmount: total,
                initialPaymentAmount: initial.isEmpty ? null : initial,
                providerId: _partyKind == _PartyKind.provider
                    ? _providerId
                    : null,
                quoteOfferId: _partyKind == _PartyKind.provider
                    ? _quoteOfferId
                    : null,
                partyName: _partyKind == _PartyKind.external
                    ? _partyNameController.text.trim()
                    : null,
                partyPhone: _partyKind == _PartyKind.external
                    ? _partyPhoneController.text.trim()
                    : null,
                agreementDate: _agreementDate,
                dueDate: _dueDate,
                note: _noteController.text.trim(),
              ) !=
              null
        : await provider.updateCost(
            cost: cost,
            budgetCategoryId: _categoryId!,
            title: _titleController.text.trim(),
            totalAmount: total,
            providerId: _partyKind == _PartyKind.provider ? _providerId : null,
            quoteOfferId: _partyKind == _PartyKind.provider
                ? _quoteOfferId
                : null,
            partyName: _partyKind == _PartyKind.external
                ? _partyNameController.text.trim()
                : null,
            partyPhone: _partyKind == _PartyKind.external
                ? _partyPhoneController.text.trim()
                : null,
            agreementDate: _agreementDate,
            dueDate: _dueDate,
            note: _noteController.text.trim(),
          );
    if (ok && mounted) context.pop(true);
  }
}

class _NoCategory extends StatelessWidget {
  const _NoCategory({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MoneyMessageBanner(
          message: 'أضف تصنيفًا أولًا حتى تكون التكلفة مرتبة وواضحة.',
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onCreate,
          icon: const Icon(LucideIcons.folderPlus),
          label: const Text('إضافة تصنيف'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(LucideIcons.calendarDays),
          suffixIcon: value == null
              ? null
              : IconButton(
                  onPressed: onTap,
                  icon: const Icon(LucideIcons.pencil),
                  tooltip: 'تغيير التاريخ',
                ),
        ),
        child: Text(
          value == null ? 'غير محدد' : formatArabicCompactDate(value!),
        ),
      ),
    );
  }
}

class _ProviderPicker extends StatefulWidget {
  const _ProviderPicker({required this.marketplace});

  final ProviderMarketplaceProvider marketplace;

  @override
  State<_ProviderPicker> createState() => _ProviderPickerState();
}

class _ProviderPickerState extends State<_ProviderPicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final providers = widget.marketplace.providers.where((provider) {
      if (query.isEmpty) return true;
      return provider.businessName.toLowerCase().contains(query) ||
          provider.ownerName.toLowerCase().contains(query) ||
          (provider.city?.nameAr.toLowerCase().contains(query) ?? false);
    }).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اختيار مزود من أعرست',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'ابحث بالاسم أو المدينة',
                  prefixIcon: Icon(LucideIcons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.marketplace.isLoading
                    ? const AarastScreenLoading(label: 'جاري تحميل المزودين')
                    : providers.isEmpty
                    ? const AarastEmptyState(
                        icon: LucideIcons.store,
                        title: 'لا توجد نتائج',
                        message: 'جرّب اسمًا أو مدينة أخرى.',
                      )
                    : ListView.separated(
                        itemCount: providers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final provider = providers[index];
                          return AarastCard(
                            onTap: () => Navigator.pop(context, provider),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.store,
                                  color: AppTheme.burgundy,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.businessName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      if (provider.city != null)
                                        Text(
                                          provider.city!.nameAr,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: AppTheme.muted),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
