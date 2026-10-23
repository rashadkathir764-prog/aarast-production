import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/budget_category.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_input_formatter.dart';

/// c09 «بند جديد» and editing one: its name and roughly how much it gets
/// from the budget. No grams, karats or other currencies: the plan keeps
/// one currency, and gold is an ordinary item (C20).
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
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  String? _nameError;
  String? _amountError;
  AarastFormDraftBinding? _draft;

  bool get _editing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.category?.name ?? widget.initialName ?? '',
    );
    _amountController = TextEditingController(
      text: formatMoneyInputValue(widget.category?.allocatedAmount),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
      _configureDraft();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_editing) {
      context.pop(false);
    } else {
      context.pop<String?>(null);
    }
  }

  int? get _amount {
    final text = _amountController.text.replaceAll(',', '').trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  /// What the budget has left for this item: the total less every other
  /// item's share.
  num _budgetLeft(FinanceProvider provider) {
    final total = moneyValue(provider.summary.budget.total);
    final others = provider.categories
        .where((item) => item.id != widget.category?.id)
        .fold<num>(0, (sum, item) => sum + moneyValue(item.allocatedAmount));
    return total - others;
  }

  String _plain(num value, String currency) =>
      compactMoneyParts(value, currencyCode: currency).plainText;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final accessBlock = financeWriteAccessBlock(
      context: context,
      provider: provider,
      weddingPlanId: widget.weddingPlanId,
    );
    if (accessBlock != null) return accessBlock;

    final currency = provider.summary.currency;
    final hasBudget = moneyValue(provider.summary.budget.total) > 0;
    final left = _budgetLeft(provider);
    final amount = _amount;
    final isGold = _nameController.text.contains('ذهب');

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: _editing ? 'تعديل البند' : 'بند جديد',
              subtitle: _editing
                  ? widget.category!.name
                  : 'لعرسك، ويدخل في الميزانية',
              onBack: _goBack,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (provider.errorMessage != null) ...[
                  JourneyListNotice(
                    offline: false,
                    onRetry: () => provider.loadMoney(widget.weddingPlanId),
                  ),
                  const SizedBox(height: 12),
                ],
                JourneyTextField(
                  key: const ValueKey('money-category-form-name'),
                  label: 'اسم البند',
                  hint: 'مثلًا: التصوير',
                  controller: _nameController,
                  icon: LucideIcons.tag,
                  maxLength: 120,
                  errorText: _nameError,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _nameError = null),
                ),
                const SizedBox(height: 14),
                JourneyTextField(
                  key: const ValueKey('money-category-form-amount'),
                  label: 'كم تخصص له تقريبًا؟',
                  hint: 'تقدر تتركه لبعدين',
                  controller: _amountController,
                  large: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  suffix: currencyLabelAr(currency),
                  errorText: _amountError,
                  helper: amount != null && amount > 0
                      ? amountInWords(
                          amount,
                          currency: currencyLabelAr(currency),
                        )
                      : hasBudget
                      ? 'باقي في ميزانيتك ${_plain(left, currency)}'
                      : null,
                  onChanged: (_) => setState(() => _amountError = null),
                ),
                if (isGold) ...[
                  const SizedBox(height: 12),
                  const JourneyNote(
                    text: 'الذهب ما يظهر في خطتك إلا لأنك أضفته.',
                    icon: LucideIcons.gem,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                  ),
                ],
                if (_draft != null) ...[
                  const SizedBox(height: 12),
                  AarastV3DraftStatusLine(status: _draft!.status),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: JourneyButton(
              key: const ValueKey('category-save'),
              label: _editing ? 'حفظ البند' : 'أضف البند',
              expand: true,
              large: true,
              loading: provider.isSubmitting,
              onPressed: provider.isSubmitting ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  /// Each problem with its own message; true when the item can be saved.
  bool _validate(FinanceProvider provider) {
    final name = _nameController.text.trim();
    final normalized = _normalizedCategoryName(name);
    final duplicate = provider.categories.any(
      (item) =>
          item.id != widget.category?.id &&
          _normalizedCategoryName(item.name) == normalized,
    );
    final amount = _amount ?? 0;
    final currency = provider.summary.currency;
    final hasBudget = moneyValue(provider.summary.budget.total) > 0;
    final left = _budgetLeft(provider);
    setState(() {
      _nameError = name.isEmpty
          ? 'اكتب اسم البند'
          : duplicate
          ? 'عندك بند بهذا الاسم'
          : null;
      _amountError = _amountController.text.trim().isNotEmpty && _amount == null
          ? 'المبلغ مو صحيح'
          : amount > 0 && !hasBudget
          ? 'حدد ميزانيتك أول، بعدين خصص للبنود'
          : hasBudget && amount > left
          ? 'أكثر من الباقي في ميزانيتك (${_plain(left, currency)})'
          : null;
    });
    return _nameError == null && _amountError == null;
  }

  Future<void> _save() async {
    final provider = context.read<FinanceProvider>();
    if (!_validate(provider)) return;
    final amount = _amount;
    final allocated = amount == null ? null : '$amount';
    final category = widget.category;
    if (category == null) {
      final createdId = await provider.createCategory(
        planId: widget.weddingPlanId,
        name: _nameController.text.trim(),
        allocatedAmount: allocated,
      );
      if (createdId != null && mounted) {
        await _draft?.clear();
        if (mounted) context.pop<String>(createdId);
      }
      return;
    }
    final saved = await provider.updateCategory(
      category: category,
      name: _nameController.text.trim(),
      allocatedAmount: allocated,
    );
    if (saved && mounted) {
      await _draft?.clear();
      if (mounted) context.pop(true);
    }
  }

  void _configureDraft() {
    if (_draft != null) return;
    final categoryId = widget.category?.id ?? 'new';
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'budget-category:${widget.weddingPlanId}:$categoryId',
      fields: {'name': _nameController, 'amount': _amountController},
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
