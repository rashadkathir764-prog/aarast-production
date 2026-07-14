import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/aarast_ui.dart';
import '../models/budget_category.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_widgets.dart';

class BudgetCategoryFormScreen extends StatefulWidget {
  const BudgetCategoryFormScreen({
    required this.weddingPlanId,
    this.category,
    this.initialName,
    super.key,
  });

  final String weddingPlanId;
  final BudgetCategory? category;
  final String? initialName;

  @override
  State<BudgetCategoryFormScreen> createState() =>
      _BudgetCategoryFormScreenState();
}

class _BudgetCategoryFormScreenState extends State<BudgetCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  String? _draftError;

  bool get _editing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.category?.name ?? widget.initialName ?? '',
    );
    _amountController = TextEditingController(
      text: widget.category?.allocatedAmount ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final accessBlock = financeWriteAccessBlock(
      context: context,
      provider: provider,
      weddingPlanId: widget.weddingPlanId,
    );
    if (accessBlock != null) return accessBlock;

    return AarastPageScaffold(
      title: _editing ? 'تعديل التصنيف' : 'تصنيف جديد',
      subtitle: 'استخدم اسمًا واضحًا يفهمه كل المشاركين.',
      showBack: true,
      onBack: () => context.pop(false),
      child: Form(
        key: _formKey,
        child: ListView(
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
                children: [
                  TextFormField(
                    key: const ValueKey('money-category-form-name'),
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم التصنيف',
                      hintText: 'مثال: القاعة',
                      prefixIcon: Icon(LucideIcons.tag),
                    ),
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'اكتب اسم التصنيف'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('money-category-form-amount'),
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'المخصص (اختياري)',
                      helperText: 'يمكنك تركه فارغًا وتحديده لاحقًا.',
                      prefixIcon: Icon(LucideIcons.coins),
                    ),
                    validator: (value) {
                      final text = value?.replaceAll(',', '').trim() ?? '';
                      if (text.isEmpty) return null;
                      final amount = num.tryParse(text);
                      return amount == null || amount < 0
                          ? 'المبلغ غير صحيح'
                          : null;
                    },
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
              label: Text(provider.isSubmitting ? 'جاري الحفظ' : 'حفظ التصنيف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final amount = _amountController.text.replaceAll(',', '').trim();
    final category = widget.category;
    final normalizedName = _normalizedCategoryName(_nameController.text);
    final duplicate = provider.categories.any(
      (item) =>
          item.id != category?.id &&
          _normalizedCategoryName(item.name) == normalizedName,
    );
    if (duplicate) {
      setState(() => _draftError = 'يوجد تصنيف بهذا الاسم بالفعل.');
      return;
    }
    final allocation = moneyValue(amount);
    final totalBudget = moneyValue(provider.summary.budget.total);
    final otherAllocations = provider.categories
        .where((item) => item.id != category?.id)
        .fold<num>(0, (sum, item) => sum + moneyValue(item.allocatedAmount));
    if (allocation > 0 && totalBudget <= 0) {
      setState(
        () => _draftError = 'حدد الميزانية العامة قبل تخصيص مبلغ لهذا التصنيف.',
      );
      return;
    }
    if (totalBudget > 0 && otherAllocations + allocation > totalBudget) {
      setState(() => _draftError = 'المخصص يتجاوز المتبقي من الميزانية.');
      return;
    }
    setState(() => _draftError = null);
    final ok = category == null
        ? await provider.createCategory(
            planId: widget.weddingPlanId,
            name: _nameController.text.trim(),
            allocatedAmount: amount.isEmpty ? null : amount,
          )
        : await provider.updateCategory(
            category: category,
            name: _nameController.text.trim(),
            allocatedAmount: amount.isEmpty ? null : amount,
          );
    if (ok && mounted) context.pop(true);
  }
}

String _normalizedCategoryName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
