import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show
        MarketplaceProvider,
        ProviderMarketplaceProvider,
        providerDirectoryErrorMessage;
import '../models/cost_draft_intent.dart';
import '../models/funding_source.dart' show CostPayerOption;
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_input_formatter.dart';
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
  final _payerNameController = TextEditingController();
  final _noteController = TextEditingController();

  /// Who pays: '' (not set) or a CostPayerOption code.
  String _payer = '';
  bool _isPrivate = false;
  String? _categoryId;
  String? _providerId;
  String? _providerName;
  String? _quoteOfferId;
  _PartyKind _partyKind = _PartyKind.none;
  DateTime? _agreementDate;
  bool _quoteCurrencyResolved = false;
  String? _quoteCurrencyWarning;
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

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
    _totalController.text = formatMoneyInputValue(
      intent?.totalAmount ?? cost?.totalAmount,
    );
    _initialPaymentController.text = formatMoneyInputValue(
      intent?.initialPaymentAmount,
    );
    _partyNameController.text =
        intent?.externalPartyName ?? cost?.partyName ?? '';
    _partyPhoneController.text =
        intent?.externalPartyPhone ?? cost?.partyPhone ?? '';
    _noteController.text = intent?.note ?? cost?.note ?? '';
    _payer = cost?.payer ?? '';
    _payerNameController.text = cost?.payerName ?? '';
    _providerId = intent?.providerId ?? cost?.providerId;
    _providerName = intent?.providerName ?? cost?.providerName;
    _quoteOfferId = intent?.quoteOfferId ?? cost?.quoteOfferId;
    _agreementDate = cost?.agreementDate;
    _partyKind = _providerId != null
        ? _PartyKind.provider
        : _partyNameController.text.trim().isNotEmpty
        ? _PartyKind.external
        : _PartyKind.none;
    for (final controller in [
      _titleController,
      _totalController,
      _initialPaymentController,
      _partyNameController,
      _partyPhoneController,
      _payerNameController,
      _noteController,
    ]) {
      controller.addListener(_handleDraftFieldChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didConfigureDraft || _editing) return;
    _didConfigureDraft = true;
    final store = context.read<AarastFormDraftStore?>();
    if (store == null) return;
    _draft = AarastFormDraftCoordinator(
      store: store,
      scope: _draftScope,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    for (final controller in [
      _titleController,
      _totalController,
      _initialPaymentController,
      _partyNameController,
      _partyPhoneController,
      _payerNameController,
      _noteController,
    ]) {
      controller
        ..removeListener(_handleDraftFieldChanged)
        ..dispose();
    }
    _draft?.dispose();
    super.dispose();
  }

  String get _draftScope {
    final quoteId = widget.intent?.quoteOfferId?.trim();
    final suffix = quoteId?.isNotEmpty == true ? 'quote:$quoteId' : 'new';
    return 'cost:${widget.weddingPlanId}:$suffix';
  }

  Future<void> _restoreDraft() async {
    final data = await _draft?.restore();
    if (!mounted || data == null) return;
    _restoringDraft = true;
    _titleController.text = data['title']?.toString() ?? _titleController.text;
    _totalController.text = formatMoneyInputValue(
      data['total'] ?? _totalController.text,
    );
    _initialPaymentController.text = formatMoneyInputValue(
      data['initialPayment'] ?? _initialPaymentController.text,
    );
    _partyNameController.text =
        data['partyName']?.toString() ?? _partyNameController.text;
    _partyPhoneController.text =
        data['partyPhone']?.toString() ?? _partyPhoneController.text;
    _noteController.text = data['note']?.toString() ?? _noteController.text;
    _payerNameController.text =
        data['payerName']?.toString() ?? _payerNameController.text;
    final partyKind = _PartyKind.values.firstWhere(
      (value) => value.name == data['partyKind']?.toString(),
      orElse: () => _PartyKind.none,
    );
    setState(() {
      _categoryId = data['categoryId']?.toString() ?? _categoryId;
      _providerId = data['providerId']?.toString() ?? _providerId;
      _providerName = data['providerName']?.toString() ?? _providerName;
      _quoteOfferId = data['quoteOfferId']?.toString() ?? _quoteOfferId;
      _agreementDate = DateTime.tryParse(
        data['agreementDate']?.toString() ?? '',
      );
      _partyKind = partyKind;
      _payer = data['payer']?.toString() ?? _payer;
    });
    _restoringDraft = false;
  }

  void _handleDraftFieldChanged() {
    if (mounted) setState(() {});
    _scheduleDraft();
  }

  void _scheduleDraft() {
    if (_restoringDraft) return;
    _draft?.schedule({
      'categoryId': _categoryId,
      'title': _titleController.text,
      'total': _totalController.text,
      'initialPayment': _initialPaymentController.text,
      'partyKind': _partyKind.name,
      'providerId': _providerId,
      'providerName': _providerName,
      'quoteOfferId': _quoteOfferId,
      'partyName': _partyNameController.text,
      'partyPhone': _partyPhoneController.text,
      'agreementDate': _agreementDate?.toIso8601String(),
      'payer': _payer,
      'payerName': _payerNameController.text,
      'note': _noteController.text,
    });
  }

  void _mutateDraft(VoidCallback change) {
    setState(change);
    _scheduleDraft();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!_quoteCurrencyResolved &&
        provider.loadedPlanId == widget.weddingPlanId &&
        !provider.isLoading &&
        provider.hasLoadedMoney &&
        provider.errorMessage == null) {
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

    return MoneySubpageScaffold(
      title: _editing ? 'تعديل التكلفة' : 'إضافة تكلفة',
      subtitle: 'سجّل الاتفاق مرة واحدة، ثم أضف دفعاته ومواعيده من داخله.',
      showBack: true,
      onBack: () => context.pop(false),
      bottomNavigationBar: AarastV3FormActionBar(
        label: 'حفظ التكلفة',
        icon: LucideIcons.check,
        loading: provider.isSubmitting,
        onPressed: provider.isSubmitting ? null : _save,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            AarastV3FocusPrompt(
              question: _editing
                  ? 'ما الذي تغيّر في هذا الاتفاق؟'
                  : 'ما التكلفة التي اتفقت عليها؟',
              supportingText:
                  'الاسم والقيمة هما الأساس؛ اربط المزود والتفاصيل فقط عندما تحتاجها.',
              icon: LucideIcons.receipt,
            ),
            const SizedBox(height: 12),
            if (_draft != null) ...[
              AarastV3DraftStatusLine(status: _draft!.status),
              const SizedBox(height: 10),
            ],
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
            MoneySectionCard(
              title: 'بيانات التكلفة',
              subtitle: 'التصنيف والاسم والقيمة المتفق عليها.',
              icon: LucideIcons.receipt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (provider.categories.isEmpty)
                    _NoCategory(
                      onCreate: () async {
                        final created = await context.push<Object?>(
                          AppRouter.moneyCategoryCreate(widget.weddingPlanId),
                        );
                        if (created is String && mounted) {
                          setState(() => _categoryId = created);
                        }
                      },
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'cost-category-${_categoryId ?? 'none'}-${provider.categories.length}',
                      ),
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
                      onChanged: (value) =>
                          _mutateDraft(() => _categoryId = value),
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
                    inputFormatters: [MoneyInputFormatter()],
                    textInputAction: TextInputAction.next,
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
                      inputFormatters: [MoneyInputFormatter()],
                      textInputAction: TextInputAction.done,
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
            const SizedBox(height: AppTheme.space10),
            MoneyDisclosureCard(
              title: 'الجهة المرتبطة',
              subtitle: _partyKind == _PartyKind.none
                  ? 'بدون مزود حالياً'
                  : _partyKind == _PartyKind.provider
                  ? (_providerName ?? 'مزود من اعّرست')
                  : (_partyNameController.text.trim().isEmpty
                        ? 'مزود خارجي'
                        : _partyNameController.text.trim()),
              icon: LucideIcons.store,
              initiallyExpanded: _partyKind != _PartyKind.none,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_PartyKind>(
                    segments: const [
                      ButtonSegment(
                        value: _PartyKind.none,
                        label: Text('بدون مزود'),
                        icon: Icon(LucideIcons.userX),
                      ),
                      ButtonSegment(
                        value: _PartyKind.provider,
                        label: Text('مزود من اعّرست'),
                        icon: Icon(LucideIcons.store),
                      ),
                      ButtonSegment(
                        value: _PartyKind.external,
                        label: Text('مزود خارجي'),
                        icon: Icon(LucideIcons.user),
                      ),
                    ],
                    selected: {_partyKind},
                    onSelectionChanged: (value) {
                      _mutateDraft(() {
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
                            ? 'اختيار مزود من اعّرست'
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
                      textInputAction: TextInputAction.next,
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
                      textInputAction: TextInputAction.done,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(LucideIcons.phone),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space10),
            MoneyDisclosureCard(
              title: 'تفاصيل إضافية',
              subtitle: 'تاريخ الاتفاق وملاحظة قصيرة عند الحاجة',
              icon: LucideIcons.fileText,
              initiallyExpanded:
                  _agreementDate != null ||
                  _payer.isNotEmpty ||
                  _noteController.text.trim().isNotEmpty,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'مين يدفع هذه التكلفة؟',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AarastChoicePillRow<String>(
                    key: const ValueKey('cost-payer'),
                    value: _payer,
                    options: [('', 'غير محدد'), ...CostPayerOption.values],
                    onChanged: (value) => _mutateDraft(() => _payer = value),
                  ),
                  if (_payer == 'FAMILY' || _payer == 'OTHER') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _payerNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'من بالتحديد؟ (مثال: الوالد)',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                    ),
                  ],
                  // V1 checklist 4.10: the owner or partner may keep a new
                  // cost to themselves.
                  if (widget.cost == null &&
                      provider.summary.permissions.canRecordPrivateCost) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const ValueKey('cost-private'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(LucideIcons.lock),
                      title: const Text('تكلفة خاصة بي'),
                      subtitle: const Text(
                        'لا يراها شريكك ولا تدخل في أرقامه. تستطيع مشاركتها لاحقًا.',
                      ),
                      value: _isPrivate,
                      onChanged: (value) => setState(() => _isPrivate = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _DateField(
                    label: 'تاريخ الاتفاق',
                    value: _agreementDate,
                    onTap: _pickAgreementDate,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      prefixIcon: Icon(LucideIcons.stickyNote),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (moneyValue(_totalController.text) > 0) ...[
                  _CostSaveSummary(
                    total: moneyValue(_totalController.text).toDouble(),
                    initialPayment: moneyValue(
                      _initialPaymentController.text,
                    ).toDouble(),
                    currency: provider.summary.currency,
                    budgetRemaining: provider.summary.hasBudget
                        ? moneyValue(
                            provider.summary.budget.remaining,
                          ).toDouble()
                        : null,
                    previousTotal: moneyValue(
                      widget.cost?.totalAmount,
                    ).toDouble(),
                  ),
                  const SizedBox(height: AppTheme.space12),
                ],
              ],
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
    final selected = await showAarastBottomSheet<MarketplaceProvider>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ProviderPicker(marketplace: marketplace),
    );
    if (selected == null || !mounted) return;
    _mutateDraft(() {
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
    if (moneyValue(_totalController.text) == moneyValue(intent?.totalAmount)) {
      _totalController.clear();
    }
    _mutateDraft(() {
      _quoteOfferId = null;
      _quoteCurrencyWarning =
          'عرض السعر بعملة ${currencySpokenLabelAr(quoteCurrency)}، وميزانية الخطة بعملة ${currencySpokenLabelAr(canonicalPlanCurrency)}. أدخل المبلغ بعد تحويله إلى عملة الخطة؛ ستبقى التكلفة مرتبطة بالمزود دون ربط المبلغ بعرض مختلف العملة.';
    });
  }

  Future<void> _pickAgreementDate() async {
    releaseFieldFocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _agreementDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('ar'),
    );
    if (picked == null || !mounted) return;
    _mutateDraft(() => _agreementDate = picked);
  }

  String? get _payerOrNull => _payer.isEmpty ? null : _payer;

  /// A name only goes with a payer it describes (family or other).
  String? get _payerNameOrNull {
    final name = _payerNameController.text.trim();
    return (_payer == 'FAMILY' || _payer == 'OTHER') && name.isNotEmpty
        ? name
        : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) return;
    if (_partyKind == _PartyKind.provider && _providerId == null) {
      AarastToast.showInfo(context, 'اختر مزودًا من اعّرست.');
      return;
    }
    final provider = context.read<FinanceProvider>();
    final total = _totalController.text.replaceAll(',', '').trim();
    final initial = _initialPaymentController.text.replaceAll(',', '').trim();
    final cost = widget.cost;
    WeddingCost? createdCost;
    final ok = cost == null
        ? (createdCost = await provider.createCost(
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
                payer: _payerOrNull,
                payerName: _payerNameOrNull,
                agreementDate: _agreementDate,
                note: _noteController.text.trim(),
                isPrivate: _isPrivate,
              )) !=
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
            payer: _payerOrNull,
            payerName: _payerNameOrNull,
            agreementDate: _agreementDate,
            note: _noteController.text.trim(),
          );
    if (ok && mounted) {
      await _draft?.clear();
      if (!mounted) return;
      final router = GoRouter.of(context);
      AarastFormSuccess.show(
        context,
        message: context.read<FinanceProvider>().savedMessage(
          cost == null ? 'تمت إضافة التكلفة.' : 'تم حفظ التكلفة.',
        ),
        nextLabel: createdCost == null ? null : 'فتح التكلفة',
        onNext: createdCost == null
            ? null
            : () => router.push(
                AppRouter.moneyCostDetails(
                  widget.weddingPlanId,
                  createdCost!.id,
                ),
              ),
      );
      context.pop(true);
    }
  }
}

class _CostSaveSummary extends StatelessWidget {
  const _CostSaveSummary({
    required this.total,
    required this.initialPayment,
    required this.currency,
    this.budgetRemaining,
    this.previousTotal = 0,
  });

  final double total;
  final double initialPayment;
  final String currency;
  final double? budgetRemaining;
  final double previousTotal;

  @override
  Widget build(BuildContext context) {
    final paid = initialPayment.clamp(0, total).toDouble();
    final remaining = (total - paid).clamp(0, total).toDouble();
    final budgetAfterSave = budgetRemaining == null
        ? null
        : budgetRemaining! - (total - previousTotal);
    return Container(
      key: const ValueKey('cost-save-summary'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ملخص قبل الحفظ',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CostSaveMetric(
                label: 'الإجمالي',
                value: total,
                currency: currency,
              ),
              _CostSaveMetric(
                label: 'المدفوع الآن',
                value: paid,
                currency: currency,
              ),
              _CostSaveMetric(
                label: 'غير مدفوع',
                value: remaining,
                currency: currency,
              ),
            ],
          ),
          if (budgetAfterSave != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: budgetAfterSave < 0
                    ? AppTheme.dangerSoft
                    : AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: Row(
                children: [
                  Icon(
                    budgetAfterSave < 0
                        ? LucideIcons.alertTriangle
                        : LucideIcons.walletCards,
                    size: 17,
                    color: budgetAfterSave < 0
                        ? AppTheme.danger
                        : AppTheme.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      budgetAfterSave < 0
                          ? 'بعد الحفظ ستتجاوز الميزانية بمقدار'
                          : 'بعد الحفظ سيتبقى من الميزانية',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MoneyAmountText(
                    amount: budgetAfterSave.abs(),
                    currency: currency,
                    color: budgetAfterSave < 0
                        ? AppTheme.danger
                        : AppTheme.textPrimary,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CostSaveMetric extends StatelessWidget {
  const _CostSaveMetric({
    required this.label,
    required this.value,
    required this.currency,
  });

  final String label;
  final double value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          MoneyAmountText(
            amount: value,
            currency: currency,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
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
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<MarketplaceProvider> _providers = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
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
      _errorMessage = null;
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
        _errorMessage = null;
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
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _errorMessage = providerDirectoryErrorMessage(error);
      });
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
                'اختيار مزود من اعّرست',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'ابحث باسم المزود',
                  prefixIcon: Icon(LucideIcons.search),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const AarastScreenLoading(label: 'جاري تحميل المزودين')
                    : _errorMessage != null && _providers.isEmpty
                    ? AarastErrorState(
                        title: 'تعذر تحميل المزودين',
                        message: _errorMessage!,
                        onRetry: () => _load(reset: true),
                      )
                    : _providers.isEmpty
                    ? const AarastEmptyState(
                        icon: LucideIcons.store,
                        title: 'لا توجد نتائج',
                        message: 'جرّب اسم مزود آخر.',
                      )
                    : ListView.separated(
                        itemCount: _providers.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == _providers.length) {
                            return Center(
                              child: TextButton.icon(
                                onPressed: _isLoadingMore
                                    ? null
                                    : () => _load(reset: false),
                                icon: _isLoadingMore
                                    ? const AarastInlineSpinner()
                                    : const Icon(LucideIcons.chevronDown),
                                label: Text(
                                  _isLoadingMore
                                      ? 'جاري التحميل'
                                      : 'عرض مزودين أكثر',
                                ),
                              ),
                            );
                          }
                          final provider = _providers[index];
                          return AarastCard(
                            onTap: () => Navigator.pop(context, provider),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.store,
                                  color: AppTheme.brand,
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
                                              ?.copyWith(
                                                color: AppTheme.textSecondary,
                                              ),
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
