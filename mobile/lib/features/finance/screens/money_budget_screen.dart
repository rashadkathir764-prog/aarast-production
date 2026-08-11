import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_input_formatter.dart';
import '../widgets/money_widgets.dart';

class MoneyBudgetScreen extends StatefulWidget {
  const MoneyBudgetScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<MoneyBudgetScreen> createState() => _MoneyBudgetScreenState();
}

class _MoneyBudgetScreenState extends State<MoneyBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalController = TextEditingController();
  final _rows = <_CategoryDraft>[];
  String _currency = defaultCurrencyCode;
  bool _hydrated = false;
  String? _draftError;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
      if (mounted) _hydrate(context.read<FinanceProvider>());
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _totalController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!_hydrated &&
        !provider.isLoading &&
        provider.loadedPlanId == widget.weddingPlanId &&
        provider.hasLoadedMoney &&
        provider.errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hydrate(provider);
      });
    }
    final accessBlock = financeWriteAccessBlock(
      context: context,
      provider: provider,
      weddingPlanId: widget.weddingPlanId,
    );
    if (accessBlock != null) return accessBlock;

    final total = moneyValue(_totalController.text);
    final currencyLocked = provider.summary.costs.count > 0;
    final allocated = _rows.fold<num>(
      0,
      (sum, row) => sum + moneyValue(row.amount.text),
    );
    final unallocated = total - allocated;

    return MoneySubpageScaffold(
      title: 'إدارة الميزانية',
      subtitle: 'حدد السقف المالي ثم وزّعه على التصنيفات.',
      showBack: true,
      onBack: () => context.pop(false),
      actions: const [MoneyPrivacyButton(compact: true)],
      bottomNavigationBar: AarastV3FormActionBar(
        label: 'حفظ الميزانية',
        icon: LucideIcons.check,
        loading: provider.isSubmitting,
        onPressed: provider.isSubmitting ? null : _save,
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const AarastV3FocusPrompt(
              question: 'ما السقف الذي تريد الالتزام به؟',
              supportingText:
                  'ابدأ بالميزانية العامة، ثم وزّعها على البنود التي تهمك.',
              icon: LucideIcons.walletCards,
            ),
            if (_draft != null) ...[
              const SizedBox(height: 8),
              AarastV3DraftStatusLine(status: _draft!.status),
            ],
            const SizedBox(height: 16),
            if (provider.errorMessage != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            if (_draftError != null) ...[
              MoneyMessageBanner(message: _draftError!, error: true),
              const SizedBox(height: 12),
            ],
            MoneySectionCard(
              title: 'الميزانية العامة',
              subtitle: 'هذا هو الحد الذي تريد ألا تتجاوزه في الخطة.',
              icon: LucideIcons.walletCards,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('money-budget-total'),
                    controller: _totalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [MoneyInputFormatter()],
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'الميزانية العامة',
                      hintText: 'مثال: 3,000,000',
                      prefixIcon: const Icon(LucideIcons.walletCards),
                      suffixText: currencyLabelAr(_currency),
                    ),
                    validator: _validateTotal,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (currencyLocked)
                    _LockedCurrencyRow(currency: _currency)
                  else ...[
                    Text(
                      'العملة',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AarastChoicePillRow<String>(
                      value: _currency,
                      options: weddingCurrencyOptions,
                      onChanged: (value) {
                        setState(() => _currency = value);
                        _draft?.changed();
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  _AllocationSummary(
                    allocated: allocated,
                    unallocated: total <= 0 ? 0 : unallocated,
                    total: total,
                    currency: _currency,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AarastV3SectionHeader(
              title: 'التصنيفات',
              subtitle: 'قسّم الميزانية بطريقة تناسب زفافك.',
              action: TextButton.icon(
                key: const ValueKey('money-budget-add-category'),
                onPressed: _openCategoryCreate,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.brand,
                  backgroundColor: AppTheme.brandMuted,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: AppTheme.brand.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: const Text(
                  'إضافة تصنيف',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_rows.isEmpty)
              AarastEmptyState(
                icon: LucideIcons.tags,
                title: 'لا توجد تصنيفات بعد',
                message: 'أضف أول تصنيف لتوزيع جزء من ميزانيتك عليه.',
              )
            else
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: AppTheme.borderStrong),
                  ),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < _rows.length; index++) ...[
                      _BudgetCategoryRow(
                        key: ValueKey(_rows[index].key),
                        row: _rows[index],
                        currency: _currency,
                        onTap: () => _openCategory(_rows[index]),
                      ),
                      if (index != _rows.length - 1)
                        const Divider(
                          height: 1,
                          indent: 54,
                          color: AppTheme.borderStrong,
                        ),
                    ],
                  ],
                ),
              ),
            if (total <= 0 && allocated > 0) ...[
              const SizedBox(height: 4),
              const MoneyMessageBanner(
                message:
                    'حدد الميزانية العامة قبل توزيع مبالغ على التصنيفات، أو اترك كل المخصصات فارغة.',
                error: true,
              ),
            ] else if (unallocated < 0) ...[
              const SizedBox(height: 4),
              const MoneyMessageBanner(
                message: 'مجموع المخصصات يتجاوز الميزانية العامة.',
                error: true,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _hydrate(FinanceProvider provider) {
    if (_hydrated ||
        provider.loadedPlanId != widget.weddingPlanId ||
        !provider.hasLoadedMoney ||
        provider.errorMessage != null) {
      return;
    }
    _hydrated = true;
    _totalController.text = formatMoneyInputValue(
      provider.summary.budget.total,
    );
    _currency = provider.summary.currency;
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(
        provider.categories.map(
          (category) => _CategoryDraft(
            id: category.id,
            name: category.name,
            amount: category.allocatedAmount,
            costsCount: category.costsCount,
            confirmedCost: category.confirmedCost,
            paid: category.paid,
            remainingAllocation: category.remainingAllocation,
          ),
        ),
      );
    setState(() {});
    _configureDraft();
  }

  String? _validateTotal(String? value) {
    final text = value?.replaceAll(',', '').trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = num.tryParse(text);
    if (parsed == null || parsed <= 0) return 'اكتب ميزانية أكبر من صفر';
    return null;
  }

  Future<void> _openCategoryCreate() async {
    final createdId = await context.push<String?>(
      AppRouter.moneyCategoryCreate(widget.weddingPlanId),
    );
    if (createdId != null && mounted) await _refreshCategories();
  }

  Future<void> _openCategory(_CategoryDraft row) async {
    final id = row.id;
    if (id == null) return;
    final changed = await context.push<bool>(
      AppRouter.moneyCategoryDetails(widget.weddingPlanId, id),
    );
    if (changed == true && mounted) await _refreshCategories();
  }

  Future<void> _refreshCategories() async {
    final provider = context.read<FinanceProvider>();
    await provider.loadMoney(widget.weddingPlanId);
    if (!mounted || provider.errorMessage != null) return;
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(
        provider.categories.map(
          (category) => _CategoryDraft(
            id: category.id,
            name: category.name,
            amount: category.allocatedAmount,
            costsCount: category.costsCount,
            confirmedCost: category.confirmedCost,
            paid: category.paid,
            remainingAllocation: category.remainingAllocation,
          ),
        ),
      );
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final total = moneyValue(_totalController.text);
    if (total <= 0 && _rows.isEmpty) {
      setState(() => _draftError = 'حدد ميزانية أو أضف تصنيفًا قبل الحفظ.');
      return;
    }
    final normalizedNames = <String>{};
    for (final row in _rows) {
      if (!normalizedNames.add(_normalizedCategoryName(row.name.text))) {
        setState(() => _draftError = 'لا يمكن تكرار اسم التصنيف.');
        return;
      }
    }
    final allocated = _rows.fold<num>(
      0,
      (sum, row) => sum + moneyValue(row.amount.text),
    );
    if (total <= 0 && allocated > 0) {
      setState(
        () =>
            _draftError = 'حدد الميزانية العامة قبل توزيع مبالغ على التصنيفات.',
      );
      return;
    }
    if (total > 0 && allocated > total) {
      setState(() => _draftError = 'مجموع المخصصات يتجاوز الميزانية العامة.');
      return;
    }
    setState(() => _draftError = null);
    final ok = await context.read<FinanceProvider>().saveBudget(
      planId: widget.weddingPlanId,
      totalBudget: _totalController.text.trim().isEmpty
          ? null
          : _totalController.text.replaceAll(',', '').trim(),
      currency: _currency,
      categories: [
        for (final row in _rows)
          (
            id: row.id,
            name: row.name.text.trim(),
            allocatedAmount: row.amount.text.trim().isEmpty
                ? null
                : row.amount.text.replaceAll(',', '').trim(),
          ),
      ],
    );
    if (ok && mounted) {
      await _draft?.clear();
      if (!mounted) return;
      AarastFormSuccess.show(context, message: 'تم حفظ الميزانية.');
      context.pop(true);
    }
  }

  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'budget:${widget.weddingPlanId}',
      fields: {'total': _totalController},
      readExtras: () => {'currency': _currency},
      restoreExtras: (data) {
        if (!mounted) return;
        final currency = data['currency']?.toString();
        if (currency != null &&
            weddingCurrencyOptions.any((option) => option.$1 == currency)) {
          setState(() => _currency = currency);
        }
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }
}

String _normalizedCategoryName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({
    required this.allocated,
    required this.unallocated,
    required this.total,
    required this.currency,
  });

  final num allocated;
  final num unallocated;
  final num total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final over = unallocated < 0;
    final ratio = total <= 0 ? 0.0 : (allocated / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: over ? AppTheme.dangerSoft : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: over
              ? AppTheme.danger.withValues(alpha: .22)
              : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AllocationValue(
                  label: 'موزع على التصنيفات',
                  amount: allocated,
                  currency: currency,
                  color: AppTheme.brand,
                ),
              ),
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: AppTheme.border,
              ),
              Expanded(
                child: _AllocationValue(
                  label: total <= 0 ? 'بانتظار الميزانية' : 'متبقي للتوزيع',
                  amount: unallocated,
                  currency: currency,
                  color: over ? AppTheme.danger : AppTheme.success,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            AarastV3ProgressLine(
              value: ratio,
              height: 6,
              color: over ? AppTheme.danger : AppTheme.brand,
              backgroundColor: AppTheme.border,
              semanticsLabel: 'توزيع الميزانية على التصنيفات',
            ),
          ],
        ],
      ),
    );
  }
}

class _AllocationValue extends StatelessWidget {
  const _AllocationValue({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final num amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: MoneyAmountText(
            amount: amount,
            currency: currency,
            color: color,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _CategoryDraft {
  _CategoryDraft({
    this.id,
    required String name,
    required String? amount,
    this.costsCount = 0,
    this.confirmedCost = '0',
    this.paid = '0',
    this.remainingAllocation,
  }) : key = id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}',
       name = TextEditingController(text: name),
       amount = TextEditingController(text: formatMoneyInputValue(amount));

  final String key;
  final String? id;
  final int costsCount;
  final String confirmedCost;
  final String paid;
  final String? remainingAllocation;
  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _BudgetCategoryRow extends StatelessWidget {
  const _BudgetCategoryRow({
    required this.row,
    required this.currency,
    required this.onTap,
    super.key,
  });

  final _CategoryDraft row;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final allocated = moneyValue(row.amount.text);
    final costs = moneyValue(row.confirmedCost);
    final remaining = row.remainingAllocation == null
        ? allocated - costs
        : moneyValue(row.remainingAllocation);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('money-budget-category-${row.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.brandMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    LucideIcons.tag,
                    color: AppTheme.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.name.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            row.costsCount == 0
                                ? 'بلا تكاليف'
                                : '${row.costsCount} تكلفة',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            LucideIcons.chevronLeft,
                            size: 17,
                            color: AppTheme.textDisabled,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryMoneyMetric(
                              label: 'المخصص',
                              amount: allocated,
                              currency: currency,
                            ),
                          ),
                          Expanded(
                            child: _CategoryMoneyMetric(
                              label: 'التكاليف',
                              amount: costs,
                              currency: currency,
                            ),
                          ),
                          Expanded(
                            child: _CategoryMoneyMetric(
                              label: remaining < 0 ? 'تجاوز' : 'المتاح',
                              amount: remaining.abs(),
                              currency: currency,
                              color: remaining < 0
                                  ? AppTheme.danger
                                  : AppTheme.success,
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
      ),
    );
  }
}

class _CategoryMoneyMetric extends StatelessWidget {
  const _CategoryMoneyMetric({
    required this.label,
    required this.amount,
    required this.currency,
    this.color,
  });

  final String label;
  final num amount;
  final String currency;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: MoneyAmountText(
            amount: amount,
            currency: currency,
            color: color ?? AppTheme.textPrimary,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _LockedCurrencyRow extends StatelessWidget {
  const _LockedCurrencyRow({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.coins, size: 19, color: AppTheme.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currencySpokenLabelAr(currency),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'ثابتة بعد تسجيل أول تكلفة',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.lock, size: 16, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}
