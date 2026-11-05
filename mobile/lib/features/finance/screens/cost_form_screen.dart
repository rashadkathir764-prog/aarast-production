import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/month_math.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceProvider, ProviderMarketplaceProvider;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../models/budget_category.dart';
import '../models/cost_draft_intent.dart';
import '../models/funding_source.dart' show CostPayerOption;
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_input_formatter.dart';

part 'cost_form_screen.pieces.dart';
part 'cost_form_screen.plan.dart';
part 'cost_form_screen.save.dart';

enum _PartyKind { none, provider, external }

/// The longest agreement name the server accepts: `@MaxLength(160)` on
/// `title` in backend/src/wedding-costs/dto/create-wedding-cost.dto.ts
/// (J1-09). Change both together.
const _costTitleMaxLength = 160;

/// c10 «اتفاق جديد» and editing one: the item, who it is with, how much,
/// and, for a new agreement, how it will be paid.
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
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _depositController = TextEditingController();
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
  bool _showMore = false;

  _PayPlan _plan = _PayPlan.later;
  int _count = 3;
  DateTime? _restDue;
  late DateTime _firstDue = addMonthsClamped(DateUtils.dateOnly(appNow()), 1);

  String? _categoryError;
  String? _partyError;
  String? _totalError;
  String? _depositError;

  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  bool get _editing => widget.cost != null;

  List<TextEditingController> get _controllers => [
    _titleController,
    _totalController,
    _depositController,
    _partyNameController,
    _partyPhoneController,
    _payerNameController,
    _noteController,
  ];

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
    final initial = moneyValue(intent?.initialPaymentAmount);
    if (initial > 0) {
      _plan = _PayPlan.depositRest;
      _depositController.text = formatMoneyInputValue(initial.round());
    }
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
        : _partyNameController.text.trim().isNotEmpty ||
              intent?.outsideParty == true
        ? _PartyKind.external
        : _PartyKind.none;
    _showMore =
        _payer.isNotEmpty ||
        _agreementDate != null ||
        _noteController.text.trim().isNotEmpty;
    for (final controller in _controllers) {
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
    for (final controller in _controllers) {
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
    String text(String key, String fallback) =>
        data[key]?.toString() ?? fallback;
    _titleController.text = text('title', _titleController.text);
    _totalController.text = formatMoneyInputValue(
      data['total'] ?? _totalController.text,
    );
    _depositController.text = formatMoneyInputValue(
      data['deposit'] ?? _depositController.text,
    );
    _partyNameController.text = text('partyName', _partyNameController.text);
    _partyPhoneController.text = text('partyPhone', _partyPhoneController.text);
    _noteController.text = text('note', _noteController.text);
    _payerNameController.text = text('payerName', _payerNameController.text);
    setState(() {
      _categoryId = data['categoryId']?.toString() ?? _categoryId;
      _providerId = data['providerId']?.toString() ?? _providerId;
      _providerName = data['providerName']?.toString() ?? _providerName;
      _quoteOfferId = data['quoteOfferId']?.toString() ?? _quoteOfferId;
      _agreementDate = DateTime.tryParse(text('agreementDate', ''));
      _partyKind = _PartyKind.values.firstWhere(
        (value) => value.name == data['partyKind']?.toString(),
        orElse: () => _partyKind,
      );
      _payer = text('payer', _payer);
      _plan = _PayPlan.values.firstWhere(
        (value) => value.name == data['plan']?.toString(),
        orElse: () => _plan,
      );
      _count = int.tryParse(text('count', '')) ?? _count;
      _restDue = DateTime.tryParse(text('restDue', '')) ?? _restDue;
      _firstDue = DateTime.tryParse(text('firstDue', '')) ?? _firstDue;
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
      'deposit': _depositController.text,
      'plan': _plan.name,
      'count': '$_count',
      'restDue': _restDue?.toIso8601String(),
      'firstDue': _firstDue.toIso8601String(),
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

  int get _total => moneyValue(_totalController.text).round();
  int get _deposit => moneyValue(_depositController.text).round();

  /// The wedding's date when the plan has one: the default for «الباقي».
  DateTime? _weddingDate(BuildContext context) {
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    if (summary?.planId != widget.weddingPlanId) return null;
    final date = summary?.weddingDate;
    return date == null ? null : DateUtils.dateOnly(date);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!_quoteCurrencyResolved &&
        provider.loadedPlanId == widget.weddingPlanId &&
        !provider.isLoading &&
        provider.hasLoadedMoney &&
        provider.loadErrorMessage == null) {
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

    final currency = provider.summary.currency;
    final weddingDate = _weddingDate(context);
    final restDue = _restDue ?? weddingDate;
    final lines = _editing
        ? const <_PlannedLine>[]
        : _planLines(
            plan: _plan,
            total: _total,
            deposit: _deposit,
            count: _count,
            restDue: restDue,
            firstDue: _firstDue,
          );
    final category = (_categoryId == null
        ? null
        : provider.categoryById(_categoryId!));
    final quoteLocked = _quoteOfferId != null;

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x2,
              0,
            ),
            child: JourneySubHeader(
              title: _editing ? 'تعديل الاتفاق' : 'اتفاق جديد',
              subtitle: _editing
                  ? widget.cost!.title
                  : context.say(
                      'مع مين اتفقت، وبكم، وكيف بتدفع',
                      'مع مين اتفقتِ، وبكم، وكيف بتدفعين',
                    ),
              onBack: () =>
                  context.popOrGo(AppRouter.money(widget.weddingPlanId), false),
            ),
          ),
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                if (widget.intent?.cameFromAcceptedQuote == true) ...[
                  JourneyNote(
                    text: context.say(
                      'عبّينا هذي من العرض اللي وافقت عليه. ما ينحفظ شي لين تضغط حفظ الاتفاق.',
                      'عبّينا هذي من العرض اللي وافقتِ عليه. ما ينحفظ شي لين تضغطين حفظ الاتفاق.',
                    ),
                  ),
                  const SizedBox(height: AarastV3Space.x3),
                ],
                if (_quoteCurrencyWarning != null) ...[
                  JourneyNote(
                    text: _quoteCurrencyWarning!,
                    icon: LucideIcons.alertTriangle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                  const SizedBox(height: AarastV3Space.x3),
                ],
                if (provider.loadErrorMessage != null) ...[
                  JourneyListNotice(
                    offline: false,
                    onRetry: () => provider.loadMoney(widget.weddingPlanId),
                  ),
                  const SizedBox(height: AarastV3Space.x3),
                ],
                _CategoryChips(
                  categories: provider.categories,
                  selectedId: _categoryId,
                  error: _categoryError,
                  onSelect: (id) => _mutateDraft(() {
                    _categoryId = id;
                    _categoryError = null;
                  }),
                  onCreate: provider.canManageBudget ? _createCategory : null,
                ),
                const SizedBox(height: AarastV3Space.x4),
                _PartySection(
                  kind: _partyKind,
                  onKind: _setPartyKind,
                  providerName: _providerName,
                  onPickProvider: _pickProvider,
                  nameController: _partyNameController,
                  phoneController: _partyPhoneController,
                  error: _partyError,
                ),
                const SizedBox(height: AarastV3Space.x4),
                if (quoteLocked)
                  _QuoteTotal(amount: _total, currency: currency)
                else
                  JourneyTextField(
                    key: const Key('cost-total-amount'),
                    label: context.say('بكم اتفقت؟', 'بكم اتفقتِ؟'),
                    controller: _totalController,
                    large: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    suffix: currencyLabelAr(currency),
                    errorText: _totalError,
                    helper: _total <= 0
                        ? null
                        : amountInWords(
                            _total,
                            currency: currencyLabelAr(currency),
                          ),
                    onChanged: (_) => setState(() => _totalError = null),
                  ),
                if (_total > 0 && category?.allocatedAmount != null)
                  _BudgetLine(
                    left: _leftInCategory(category!, widget.cost, _total),
                    currency: currency,
                  ),
                const SizedBox(height: AarastV3Space.x4),
                JourneyTextField(
                  key: const ValueKey('cost-title'),
                  label: context.say(
                    'اسم الاتفاق (لو تبي)',
                    'اسم الاتفاق (لو تبين)',
                  ),
                  hint:
                      _titleFallback(
                        _partyKind,
                        _providerName,
                        _partyNameController.text,
                        category,
                      ) ??
                      context.planWord(
                        'مثلًا: حجز القاعة',
                        'مثلًا: حجز الصالة',
                      ),
                  controller: _titleController,
                  maxLength: _costTitleMaxLength,
                ),
                if (!_editing) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  _PlanSection(
                    plan: _plan,
                    onPlan: (plan) => _mutateDraft(() {
                      _plan = plan;
                      _depositError = null;
                    }),
                    depositController: _depositController,
                    depositError: _depositError,
                    count: _count,
                    onCount: (count) => _mutateDraft(() => _count = count),
                    restDue: restDue,
                    weddingDateKnown: _restDue == null && weddingDate != null,
                    onPickRestDue: () => _pickDate(
                      initial: restDue,
                      onPicked: (date) => _restDue = date,
                    ),
                    firstDue: _firstDue,
                    onPickFirstDue: () => _pickDate(
                      initial: _firstDue,
                      onPicked: (date) => _firstDue = date,
                    ),
                    lines: lines,
                    currency: currency,
                  ),
                ],
                const SizedBox(height: AarastV3Space.x3),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyTextAction(
                    key: const ValueKey('cost-more'),
                    label: _showMore ? 'أقل' : 'تفاصيل أكثر',
                    icon: _showMore
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: context.accent.primary,
                    onPressed: () => setState(() => _showMore = !_showMore),
                  ),
                ),
                if (_showMore)
                  _MoreDetails(
                    payer: _payer,
                    onPayer: (value) => _mutateDraft(
                      () => _payer = _payer == value ? '' : value,
                    ),
                    payerNameController: _payerNameController,
                    canBePrivate:
                        !_editing &&
                        provider.summary.permissions.canRecordPrivateCost,
                    isPrivate: _isPrivate,
                    onPrivate: (value) => setState(() => _isPrivate = value),
                    agreementDate: _agreementDate,
                    onPickAgreementDate: () => _pickDate(
                      initial: _agreementDate,
                      first: DateTime(2020),
                      onPicked: (date) => _agreementDate = date,
                    ),
                    noteController: _noteController,
                  ),
                if (_draft != null) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  AarastV3DraftStatusLine(status: _draft!.status),
                ],
              ],
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const ValueKey('cost-save'),
              label: 'حفظ الاتفاق',
              expand: true,
              large: true,
              loading: provider.isSubmitting,
              onPressed: provider.isSubmitting
                  ? null
                  : () => _save(lines, restDue),
            ),
          ),
        ],
      ),
    );
  }

  void _setPartyKind(_PartyKind kind) {
    _mutateDraft(() {
      _partyKind = kind;
      _partyError = null;
      if (kind != _PartyKind.provider) {
        _providerId = null;
        _providerName = null;
        _quoteOfferId = null;
      }
      if (kind != _PartyKind.external) {
        _partyNameController.clear();
        _partyPhoneController.clear();
      }
    });
    if (kind == _PartyKind.provider && _providerId == null) _pickProvider();
  }

  Future<void> _createCategory() async {
    final created = await context.push<Object?>(
      AppRouter.moneyCategoryCreate(widget.weddingPlanId),
    );
    if (created is String && mounted) {
      _mutateDraft(() {
        _categoryId = created;
        _categoryError = null;
      });
    }
  }

  Future<void> _pickProvider() async {
    final marketplace = context.read<ProviderMarketplaceProvider?>();
    if (marketplace == null) {
      AarastToast.showError(context, 'سوق المزودين مش متاح الحين.');
      return;
    }
    final selected = await showJourneySheet<MarketplaceProvider>(
      context: context,
      builder: (context) => _ProviderPicker(marketplace: marketplace),
    );
    if (selected == null || !mounted) return;
    _mutateDraft(() {
      _providerId = selected.id;
      _providerName = selected.businessName;
      _partyError = null;
      if (widget.intent?.providerId != selected.id) _quoteOfferId = null;
    });
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required void Function(DateTime date) onPicked,
    DateTime? first,
  }) async {
    releaseFieldFocus();
    final now = DateUtils.dateOnly(appNow());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: first ?? now,
      lastDate: now.add(const Duration(days: 3650)),
      locale: const Locale('ar'),
    );
    if (picked == null || !mounted) return;
    _mutateDraft(() => onPicked(picked));
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
          'العرض بعملة ${currencySpokenLabelAr(quoteCurrency)}، وخطتك بعملة ${currencySpokenLabelAr(canonicalPlanCurrency)}. ${context.say('اكتب المبلغ بعد ما تحوّله', 'اكتبي المبلغ بعد ما تحوّلينه')} لعملة خطتك؛ الاتفاق يبقى مع المزود بس ما ينربط بعرض بعملة ثانية.';
    });
  }

  /// Everything a save needs, each with its own message; true when fine.
  bool _validate(List<_PlannedLine> lines) {
    final paid = moneyValue(widget.cost?.paidAmount);
    setState(() {
      _categoryError = _categoryId == null
          ? context.say('اختر البند', 'اختاري البند')
          : null;
      _partyError = switch (_partyKind) {
        _PartyKind.provider when _providerId == null => context.say(
          'اختر المزود',
          'اختاري المزود',
        ),
        _PartyKind.external when _partyNameController.text.trim().isEmpty =>
          context.say('اكتب اسمه', 'اكتبي اسمه'),
        _ => null,
      };
      _totalError = _total <= 0
          ? context.say('اكتب بكم اتفقت', 'اكتبي بكم اتفقتِ')
          : _editing && _total < paid
          ? '${context.say('ما يصير أقل من اللي دفعته', 'ما يصير أقل من اللي دفعتيه')} (${compactMoneyParts(paid, currencyCode: context.read<FinanceProvider>().summary.currency).plainText})'
          : null;
      _depositError = _editing
          ? null
          : _depositProblem(_plan, _deposit, _total, context.journeyProfile);
    });
    final planIncomplete =
        !_editing && _plan != _PayPlan.later && lines.isEmpty;
    if (planIncomplete && _depositError == null) {
      AarastToast.showInfo(
        context,
        context.say(
          'كمّل كيف بتدفع، أو اختر بعدين.',
          'كمّلي كيف بتدفعين، أو اختاري بعدين.',
        ),
      );
    }
    return _categoryError == null &&
        _partyError == null &&
        _totalError == null &&
        _depositError == null &&
        !planIncomplete;
  }
}
