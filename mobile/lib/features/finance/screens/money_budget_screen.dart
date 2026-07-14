import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
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
        provider.loadedPlanId == widget.weddingPlanId) {
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

    return AarastPageScaffold(
      title: 'إدارة الميزانية',
      subtitle: 'حدد السقف المالي ثم وزّعه على التصنيفات.',
      showBack: true,
      onBack: () => context.pop(false),
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
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _totalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'الميزانية العامة (اختياري)',
                      hintText: 'مثال: 3,000,000',
                      prefixIcon: Icon(LucideIcons.walletCards),
                    ),
                    validator: _validateTotal,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_currency),
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'العملة',
                      helperText: currencyLocked
                          ? 'لا يمكن تغيير العملة بعد تسجيل أول تكلفة.'
                          : null,
                      prefixIcon: const Icon(LucideIcons.coins),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'YER', child: Text('ريال يمني')),
                      DropdownMenuItem(value: 'SAR', child: Text('ريال سعودي')),
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('دولار أمريكي'),
                      ),
                    ],
                    onChanged: currencyLocked
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _currency = value);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 330;
                      final cards = [
                        MoneyMetricCard(
                          label: 'الموزع',
                          amount: allocated,
                          currency: _currency,
                          icon: LucideIcons.pieChart,
                        ),
                        MoneyMetricCard(
                          label: total <= 0 ? 'غير موزع' : 'المتبقي للتوزيع',
                          amount: total <= 0 ? 0 : unallocated,
                          currency: _currency,
                          icon: LucideIcons.scale,
                          color: unallocated < 0
                              ? AppTheme.danger
                              : AppTheme.success,
                        ),
                      ];
                      if (narrow) {
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 10),
                            cards[1],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 10),
                          Expanded(child: cards[1]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AarastSectionHeader(
              title: 'التصنيفات',
              icon: LucideIcons.tags,
              actionLabel: 'إضافة تصنيف',
              onAction: _addRow,
            ),
            const SizedBox(height: 10),
            if (_rows.isEmpty)
              const AarastEmptyState(
                icon: LucideIcons.tags,
                title: 'أضف تصنيفًا واحدًا',
                message: 'مثل القاعة، التصوير، الضيافة أو الملابس.',
              )
            else
              for (var index = 0; index < _rows.length; index++) ...[
                _CategoryEditorRow(
                  key: ValueKey(_rows[index].key),
                  fieldIndex: index,
                  row: _rows[index],
                  canRemove: _rows[index].costsCount == 0,
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeRow(index),
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
    if (_hydrated || provider.loadedPlanId != widget.weddingPlanId) return;
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
    if (_rows.isEmpty) {
      _rows.add(_CategoryDraft(name: '', amount: null));
    }
    setState(() {});
  }

  String? _validateTotal(String? value) {
    final text = value?.replaceAll(',', '').trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = num.tryParse(text);
    if (parsed == null || parsed <= 0) return 'اكتب ميزانية أكبر من صفر';
    return null;
  }

  void _addRow() {
    setState(() {
      _draftError = null;
      _rows.add(_CategoryDraft(name: '', amount: null));
    });
  }

  void _removeRow(int index) {
    final row = _rows[index];
    if (row.costsCount > 0) {
      AarastToast.showInfo(context, 'لا يمكن حذف تصنيف مرتبط بتكاليف.');
      return;
    }
    setState(() {
      _draftError = null;
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rows.isEmpty) {
      setState(() => _draftError = 'أضف تصنيفًا واحدًا على الأقل.');
      return;
    }
    final normalizedNames = <String>{};
    for (final row in _rows) {
      if (!normalizedNames.add(_normalizedCategoryName(row.name.text))) {
        setState(() => _draftError = 'لا يمكن تكرار اسم التصنيف.');
        return;
      }
    }
    final total = moneyValue(_totalController.text);
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

class _CategoryEditorRow extends StatelessWidget {
  const _CategoryEditorRow({
    required this.fieldIndex,
    required this.row,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int fieldIndex;
  final _CategoryDraft row;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('money-budget-category-name-$fieldIndex'),
                  controller: row.name,
                  decoration: const InputDecoration(
                    labelText: 'اسم التصنيف',
                    prefixIcon: Icon(LucideIcons.tag),
                  ),
                  validator: (value) => value?.trim().isEmpty == true
                      ? 'اسم التصنيف مطلوب'
                      : null,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                tooltip: canRemove ? 'حذف التصنيف' : 'التصنيف مرتبط بتكاليف',
                icon: const Icon(LucideIcons.trash2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('money-budget-category-amount-$fieldIndex'),
            controller: row.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'المخصص (اختياري)',
              prefixIcon: Icon(LucideIcons.coins),
            ),
            validator: (value) {
              final text = value?.replaceAll(',', '').trim() ?? '';
              if (text.isEmpty) return null;
              final parsed = num.tryParse(text);
              return parsed == null || parsed < 0 ? 'المبلغ غير صحيح' : null;
            },
            onChanged: (_) => onChanged(),
          ),
          if (row.costsCount > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'مرتبط بـ ${row.costsCount} تكلفة',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
