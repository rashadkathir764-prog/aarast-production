import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
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
      actions: [
        IconButton.filledTonal(
          key: const ValueKey('money-budget-add-category'),
          onPressed: _openCategoryCreate,
          tooltip: 'إضافة تصنيف',
          icon: const Icon(LucideIcons.plus, size: 20),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
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
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'الميزانية العامة (اختياري)',
                      hintText: 'مثال: 3,000,000',
                      prefixIcon: const Icon(LucideIcons.walletCards),
                      suffixText: currencyLabelAr(_currency),
                    ),
                    validator: _validateTotal,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'العملة',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AarastChoicePillRow<String>(
                    value: _currency,
                    options: weddingCurrencyOptions,
                    onChanged: currencyLocked
                        ? null
                        : (value) => setState(() => _currency = value),
                  ),
                  if (currencyLocked) ...[
                    const SizedBox(height: 6),
                    Text(
                      'لا يمكن تغيير العملة بعد تسجيل أول تكلفة.',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
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
            Text(
              'التصنيفات',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'قسّم الميزانية بطريقة تناسب زفافك.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 10),
            if (_rows.isEmpty)
              AarastEmptyState(
                icon: LucideIcons.tags,
                title: 'لا توجد تصنيفات بعد',
                message: 'استخدم زر الإضافة أعلى الشاشة لإنشاء أول تصنيف.',
              )
            else
              for (var index = 0; index < _rows.length; index++) ...[
                _BudgetCategoryRow(
                  key: ValueKey(_rows[index].key),
                  row: _rows[index],
                  currency: _currency,
                  onTap: () => _openCategory(_rows[index]),
                ),
                const SizedBox(height: 10),
              ],
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
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: provider.isSubmitting ? null : _save,
              icon: provider.isSubmitting
                  ? const AarastInlineSpinner(color: Colors.white)
                  : const Icon(LucideIcons.check),
              label: Text(
                provider.isSubmitting ? 'جاري الحفظ' : 'حفظ الميزانية',
              ),
            ),
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
    _totalController.text = provider.summary.budget.total ?? '';
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
          ),
        ),
      );
    setState(() {});
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
    if (ok && mounted) context.pop(true);
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
        color: over ? AppTheme.dangerSoft : AppTheme.empty,
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
                  color: AppTheme.burgundy,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                color: over ? AppTheme.danger : AppTheme.burgundy,
                backgroundColor: AppTheme.border,
              ),
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
            color: AppTheme.muted,
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
  }) : key = id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}',
       name = TextEditingController(text: name),
       amount = TextEditingController(text: amount ?? '');

  final String key;
  final String? id;
  final int costsCount;
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('money-budget-category-${row.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.burgundySoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  LucideIcons.tag,
                  color: AppTheme.burgundy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      row.costsCount == 0
                          ? 'لا توجد تكاليف بعد'
                          : 'مرتبط بـ ${row.costsCount} تكلفة',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: row.amount.text.trim().isEmpty
                    ? Text(
                        'بلا مخصص',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : MoneyAmountText(
                        amount: row.amount.text,
                        currency: currency,
                        style: Theme.of(context).textTheme.labelLarge,
                        color: AppTheme.burgundy,
                        textAlign: TextAlign.end,
                      ),
              ),
              const SizedBox(width: 5),
              const Icon(
                LucideIcons.chevronLeft,
                size: 17,
                color: AppTheme.disabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
