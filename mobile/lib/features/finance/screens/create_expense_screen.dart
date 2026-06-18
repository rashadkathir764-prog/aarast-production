import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../providers/finance_provider.dart';

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({
    required this.weddingPlanId,
    this.expenseId,
    this.initialExpense,
    super.key,
  });

  final String weddingPlanId;
  final String? expenseId;
  final Expense? initialExpense;

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _budgetCategoryId;
  String _status = 'PLANNED';
  DateTime? _expenseDate;
  bool _didPrefill = false;

  bool get _isEditMode =>
      widget.expenseId != null || widget.initialExpense != null;

  @override
  void initState() {
    super.initState();
    final initialExpense = widget.initialExpense;
    if (initialExpense != null) {
      _prefillExpense(initialExpense);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FinanceProvider>();
      _loadFinanceForForm(provider);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEditMode || _didPrefill) return;

    final expense = _expenseFromProvider(context.read<FinanceProvider>());
    if (expense != null) _prefillExpense(expense);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final category = _selectedCategory(provider.budgetCategories);
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _goBack,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            tooltip: 'رجوع',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isEditMode ? 'تعديل مصروف' : 'إضافة مصروف',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppTheme.dMaroonDeep,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      28 + keyboardBottom,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ExpenseHero(isEditMode: _isEditMode),
                            const SizedBox(height: 18),
                            AarastCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _titleController,
                                    textAlign: TextAlign.right,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'عنوان المصروف',
                                      hintText: 'مثال: دفعة قاعة الأفراح',
                                      prefixIcon: Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                    ),
                                    validator: _required('عنوان المصروف مطلوب'),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _amountController,
                                    textAlign: TextAlign.right,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'المبلغ',
                                      suffixText: 'ر.ي',
                                      prefixIcon: Icon(
                                        Icons.account_balance_wallet_outlined,
                                      ),
                                    ),
                                    validator: _nonNegativeRequired(
                                      'المبلغ غير صحيح',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final categoryField = _SelectorField(
                                        label: 'التصنيف',
                                        value: category?.name ?? 'بدون تصنيف',
                                        icon: Icons.folder_outlined,
                                        selected: category != null,
                                        onTap: _showCategoryPicker,
                                      );
                                      final dateField = _SelectorField(
                                        label: 'التاريخ',
                                        value: _expenseDate == null
                                            ? 'اختياري'
                                            : _formatDate(_expenseDate!),
                                        icon: Icons.calendar_month_rounded,
                                        selected: _expenseDate != null,
                                        onTap: _showCalendarPicker,
                                      );

                                      if (constraints.maxWidth < 330) {
                                        return Column(
                                          children: [
                                            categoryField,
                                            const SizedBox(height: 12),
                                            dateField,
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(child: categoryField),
                                          const SizedBox(width: 12),
                                          Expanded(child: dateField),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  const Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      'حالة المصروف',
                                      style: TextStyle(
                                        color: AppTheme.dInk,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _StatusChip(
                                        label: 'مخطط',
                                        icon: Icons.schedule_rounded,
                                        color: AppTheme.dGoldDeep,
                                        selected: _status == 'PLANNED',
                                        onTap: () {
                                          setState(() => _status = 'PLANNED');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _StatusChip(
                                        label: 'مدفوع',
                                        icon: Icons.check_circle_rounded,
                                        color: AppTheme.dGreen,
                                        selected: _status == 'PAID',
                                        onTap: () {
                                          setState(() => _status = 'PAID');
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _StatusChip(
                                        label: 'ملغي',
                                        icon: Icons.block_rounded,
                                        color: AppTheme.dMuted,
                                        selected: _status == 'CANCELLED',
                                        onTap: () {
                                          setState(() => _status = 'CANCELLED');
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _noteController,
                                    textAlign: TextAlign.right,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'ملاحظات (اختياري)',
                                      hintText:
                                          'أضيفي تفاصيل الدفعة أو الجهة المستلمة...',
                                      alignLabelWithHint: true,
                                    ),
                                  ),
                                  if (provider.errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    AarastStatusPill(
                                      label: provider.errorMessage!,
                                      color: AppTheme.danger,
                                      icon: Icons.error_outline_rounded,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            PrimaryActionButton(
                              label: _isEditMode
                                  ? 'حفظ التعديلات'
                                  : 'حفظ المصروف',
                              icon: _isEditMode
                                  ? Icons.save_outlined
                                  : Icons.check_rounded,
                              isLoading: provider.isSubmitting,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BudgetCategory? _selectedCategory(List<BudgetCategory> categories) {
    for (final category in categories) {
      if (category.id == _budgetCategoryId) return category;
    }
    return null;
  }

  Future<void> _loadFinanceForForm(FinanceProvider provider) async {
    final shouldLoad =
        provider.budgetCategories.isEmpty ||
        (_isEditMode && _expenseFromProvider(provider) == null);
    if (shouldLoad) {
      await provider.loadFinance(widget.weddingPlanId);
    }
    if (!mounted || !_isEditMode || _didPrefill) return;

    final expense = _expenseFromProvider(provider);
    if (expense != null) {
      setState(() => _prefillExpense(expense));
    }
  }

  Expense? _expenseFromProvider(FinanceProvider provider) {
    final expenseId = widget.expenseId;
    if (expenseId == null) return null;
    for (final expense in provider.expenses) {
      if (expense.id == expenseId) return expense;
    }
    return null;
  }

  void _prefillExpense(Expense expense) {
    _titleController.text = expense.title;
    _amountController.text = expense.amount;
    _noteController.text = expense.note ?? '';
    _budgetCategoryId = expense.budgetCategoryId;
    _status = expense.status;
    _expenseDate = expense.expenseDate;
    _didPrefill = true;
  }

  Future<void> _showCalendarPicker() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    var tempDate = _expenseDate ?? now;

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'تاريخ المصروف',
                    icon: Icons.calendar_month_rounded,
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(sheetContext).copyWith(
                      colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
                        primary: AppTheme.dMaroon,
                        onPrimary: Colors.white,
                        surface: AppTheme.dCard2,
                        onSurface: AppTheme.dInk,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 10),
                      onDateChanged: (date) => tempDate = date,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryActionButton(
                    label: 'تأكيد التاريخ',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(sheetContext).pop(tempDate),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) setState(() => _expenseDate = selected);
  }

  Future<void> _showCategoryPicker() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<FinanceProvider>();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'تصنيف الميزانية',
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 14),
                  _CategoryRow(
                    label: 'بدون تصنيف',
                    icon: Icons.remove_circle_outline_rounded,
                    selected: _budgetCategoryId == null,
                    onTap: () => Navigator.of(sheetContext).pop(''),
                  ),
                  for (final category in provider.budgetCategories)
                    _CategoryRow(
                      label: category.name,
                      icon: Icons.folder_outlined,
                      selected: category.id == _budgetCategoryId,
                      onTap: () => Navigator.of(sheetContext).pop(category.id),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selected != null) {
      setState(() => _budgetCategoryId = selected.isEmpty ? null : selected);
    }
  }

  void _goBack({bool changed = false}) {
    if (context.canPop()) {
      context.pop(changed);
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final note = _noteController.text.trim();
    final editingExpense = _isEditMode ? _editingExpense(provider) : null;
    final saved = _isEditMode
        ? editingExpense != null &&
              await provider.updateExpense(
                weddingPlanId: widget.weddingPlanId,
                expense: editingExpense,
                title: _titleController.text.trim(),
                amount: _amountController.text.trim(),
                budgetCategoryId: _budgetCategoryId,
                status: _status,
                expenseDate: _expenseDate,
                note: note.isEmpty ? null : note,
              )
        : await provider.createExpense(
            weddingPlanId: widget.weddingPlanId,
            title: _titleController.text.trim(),
            amount: _amountController.text.trim(),
            budgetCategoryId: _budgetCategoryId,
            status: _status,
            expenseDate: _expenseDate,
            note: note.isEmpty ? null : note,
          );

    if (_isEditMode && editingExpense == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح المصروف للتعديل')));
      return;
    }

    if (saved && mounted) {
      final notice = provider.noticeMessage;
      final message =
          notice ??
          (_isEditMode ? 'تم حفظ التعديلات بنجاح' : 'تم حفظ المصروف بنجاح');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      _goBack(changed: true);
    }
  }

  Expense? _editingExpense(FinanceProvider provider) {
    final expense = widget.initialExpense;
    if (expense != null) return expense;
    return _expenseFromProvider(provider);
  }
}

class _ExpenseHero extends StatelessWidget {
  const _ExpenseHero({required this.isEditMode});

  final bool isEditMode;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCreamBg,
      border: Border.all(color: AppTheme.dGold.withAlpha(45)),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'راجعي تفاصيل المصروف' : 'سجلي كل دفعة بوضوح',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dMaroonDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditMode
                      ? 'أي تعديل هنا سينعكس على ملخص الميزانية والمصاريف.'
                      : 'التفاصيل الصغيرة تمنع مفاجآت الميزانية لاحقاً.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.dCard2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.dMaroon : AppTheme.dLine,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.dMaroon : AppTheme.dGoldDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.dInkSoft),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.dMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(24) : AppTheme.dCard2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? color : AppTheme.dLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : AppTheme.dMuted, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppTheme.dMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        color: selected ? AppTheme.dPinkBg : AppTheme.dCard2,
        border: Border.all(color: selected ? AppTheme.dMaroon : AppTheme.dLine),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.dMaroon : AppTheme.dGoldDeep),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AppTheme.dMaroon : AppTheme.dInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.dMaroon),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.dLine,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

FormFieldValidator<String> _required(String message) {
  return (value) => value == null || value.trim().isEmpty ? message : null;
}

FormFieldValidator<String> _nonNegativeRequired(String message) {
  return (value) {
    final rawValue = value?.trim() ?? '';
    final parsed = num.tryParse(rawValue);
    if (parsed == null || parsed < 0) return message;
    return null;
  };
}

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
