import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../models/budget_category.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_input_formatter.dart';

/// c09 «بند جديد» and editing one: its name and, if known, how much it is
/// expected to cost (D109 «تقديرك»: free, may pass the budget with a word,
/// never refused). Its share of the budget is set where the budget is
/// shared out (w19) and is kept here as it is. No grams, karats or other
/// currencies: the plan keeps one currency, and gold is an ordinary item
/// (C20).
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
      text: formatMoneyInputValue(widget.category?.estimatedAmount),
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
      context.popOrGo(AppRouter.money(widget.weddingPlanId), false);
    } else {
      context.popOrGo<String?>(AppRouter.money(widget.weddingPlanId));
    }
  }

  int? get _amount {
    final text = _amountController.text.replaceAll(',', '').trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  String _plain(num value, String currency) =>
      compactMoneyParts(value, currencyCode: currency).plainText;

  /// By how much the wedding's items would pass the budget with [amount]
  /// as this item's estimate; 0 when they would not, or when it cannot be
  /// told here (the item has agreements: they decide its cost, D105).
  num _overBudget(FinanceProvider provider, int? amount) {
    final budget = provider.summary.budget.total;
    final expected = provider.summary.expected;
    if (budget == null || expected == null || amount == null) return 0;
    final item = provider.summary.categories
        .where((entry) => entry.categoryId == widget.category?.id)
        .firstOrNull;
    if (item != null && moneyValue(item.confirmedCost) > 0) return 0;
    final others =
        moneyValue(expected.wedding.expected) - moneyValue(item?.expectedCost);
    final over = others + amount - moneyValue(budget);
    return over > 0 ? over : 0;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final accessBlock = financeWriteAccessBlock(
      context: context,
      provider: provider,
      weddingPlanId: widget.weddingPlanId,
      ownerOnly: true,
    );
    if (accessBlock != null) return accessBlock;

    final currency = provider.summary.currency;
    final amount = _amount;
    final over = _overBudget(provider, amount);
    final isGold = _nameController.text.contains('ذهب');

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
              title: _editing ? 'تعديل البند' : 'بند جديد',
              subtitle: _editing
                  ? widget.category!.name
                  : 'لعرسك، ويدخل في الميزانية',
              onBack: _goBack,
            ),
          ),
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                if (provider.loadErrorMessage != null) ...[
                  JourneyListNotice(
                    offline: false,
                    onRetry: () => provider.loadMoney(widget.weddingPlanId),
                  ),
                  const SizedBox(height: AarastV3Space.x3),
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
                const SizedBox(height: AarastV3Space.x3),
                JourneyTextField(
                  key: const ValueKey('money-category-form-amount'),
                  label: context.say('كم تتوقع يكلف؟', 'كم تتوقعين يكلف؟'),
                  hint: context.say(
                    'تقدر تتركه لبعدين',
                    'تقدرين تتركينه لبعدين',
                  ),
                  controller: _amountController,
                  large: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  suffix: currencyLabelAr(currency),
                  errorText: _amountError,
                  // Said, never refused (D109).
                  helper: over > 0
                      ? 'بهذا التقدير تصير بنود العرس فوق الميزانية بـ${_plain(over, currency)}'
                      : amount != null && amount > 0
                      ? amountInWords(
                          amount,
                          currency: currencyLabelAr(currency),
                        )
                      : 'رقم تقريبي يكفي، ونقارنه بميزانيتك',
                  helperColor: over > 0 ? AarastV3Color.danger : null,
                  onChanged: (_) => setState(() => _amountError = null),
                ),
                if (isGold) ...[
                  const SizedBox(height: AarastV3Space.x3),
                  JourneyNote(
                    text: context.say(
                      'الذهب ما يظهر في خطتك إلا لأنك أضفته.',
                      'الذهب ما يظهر في خطتك إلا لأنك أضفتيه.',
                    ),
                    icon: LucideIcons.gem,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                  ),
                ],
                if (_draft != null) ...[
                  const SizedBox(height: AarastV3Space.x3),
                  AarastV3DraftStatusLine(status: _draft!.status),
                ],
              ],
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const ValueKey('category-save'),
              label: _editing
                  ? 'حفظ البند'
                  : context.say('أضف البند', 'أضيفي البند'),
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
    setState(() {
      _nameError = name.isEmpty
          ? context.say('اكتب اسم البند', 'اكتبي اسم البند')
          : duplicate
          ? 'عندك بند بهذا الاسم'
          : null;
      _amountError = _amountController.text.trim().isNotEmpty && _amount == null
          ? 'المبلغ مش صحيح'
          : null;
    });
    return _nameError == null && _amountError == null;
  }

  Future<void> _save() async {
    final provider = context.read<FinanceProvider>();
    if (!_validate(provider)) return;
    final amount = _amount;
    final estimate = amount == null ? null : '$amount';
    final name = _nameController.text.trim();
    final category = widget.category;
    if (category == null) {
      final createdId = await provider.createCategory(
        planId: widget.weddingPlanId,
        name: name,
      );
      if (!mounted) return;
      if (createdId == null) {
        AarastToast.showError(
          context,
          provider.errorMessage ?? 'ما انضاف البند',
        );
        return;
      }
      final created = provider.categoryById(createdId);
      if (estimate != null && created != null) {
        final estimated = await provider.setItemEstimate(
          category: created,
          estimatedAmount: estimate,
        );
        if (!mounted) return;
        // The item is there either way; say what did not keep.
        if (!estimated) {
          AarastToast.showError(
            context,
            'انضاف البند، وما انحفظ التقدير. ${provider.errorMessage ?? ''}'
                .trim(),
          );
        }
      }
      await _draft?.clear();
      if (mounted) {
        context.popOrGo<String>(
          AppRouter.money(widget.weddingPlanId),
          createdId,
        );
      }
      return;
    }
    // Its share of the budget stays as it is (w19 sets it).
    var saved = true;
    if (name != category.name) {
      saved = await provider.updateCategory(
        category: category,
        name: name,
        allocatedAmount: category.allocatedAmount,
      );
    }
    final current = category.estimatedAmount == null
        ? null
        : '${moneyValue(category.estimatedAmount).round()}';
    if (saved && estimate != current) {
      saved = await provider.setItemEstimate(
        category: provider.categoryById(category.id) ?? category,
        estimatedAmount: estimate,
      );
    }
    if (!mounted) return;
    if (!saved) {
      AarastToast.showError(context, provider.errorMessage ?? 'ما انحفظ البند');
      return;
    }
    await _draft?.clear();
    if (mounted) context.popOrGo(AppRouter.money(widget.weddingPlanId), true);
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
