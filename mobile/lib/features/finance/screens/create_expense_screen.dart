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
import '../../../shared/models/quote_finance_context.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../providers/finance_provider.dart';

part 'create_expense_screen.widgets.dart';
part 'create_expense_screen.fields.dart';

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({
    required this.weddingPlanId,
    this.expenseId,
    this.initialExpense,
    this.quoteContext,
    this.initialBudgetCategoryId,
    super.key,
  });

  final String weddingPlanId;
  final String? expenseId;
  final Expense? initialExpense;
  final QuoteFinanceContext? quoteContext;
  final String? initialBudgetCategoryId;

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _budgetCategoryId;
  DateTime? _expenseDate;
  bool _didPrefill = false;

  bool get _isEditMode =>
      widget.expenseId != null || widget.initialExpense != null;

  /// عملة الخطة النشطة كتسمية عربية. تُقرأ دفاعيًا لأن الخطط المحلية أو
  /// اختبارات الشاشة قد تُعرض بدون WeddingPlansProvider.
  String get _currencyLabel {
    final provider = context.read<WeddingPlansProvider?>();
    String? code;
    if (provider != null) {
      for (final plan in provider.plans) {
        if (plan.id == widget.weddingPlanId) {
          code = plan.currency;
          break;
        }
      }
      code ??= provider.selectedPlan?.currency ?? provider.activePlan?.currency;
    }
    return currencyLabelAr(code);
  }

  @override
  void initState() {
    super.initState();
    final initialExpense = widget.initialExpense;
    if (initialExpense != null) {
      _prefillExpense(initialExpense);
    } else if (widget.quoteContext != null) {
      _prefillQuoteContext(widget.quoteContext!);
    } else {
      _budgetCategoryId = widget.initialBudgetCategoryId;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) return;
      _loadFinanceForForm(context.read<FinanceProvider>());
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

    return AarastScreenFrame(
      maxWidth: 500,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(LucideIcons.arrowRight),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'تعديل مصروف مدفوع' : 'تسجيل مصروف مدفوع',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.burgundyDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + keyboardBottom),
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
                          _CategoryDateRow(
                            category: category,
                            expenseDate: _expenseDate,
                            dateLabel: 'تاريخ الدفع',
                            onCategoryTap: _showCategoryPicker,
                            onDateTap: _showCalendarPicker,
                          ),
                          if (category == null) ...[
                            const SizedBox(height: 12),
                            const AarastStatusPill(
                              label:
                                  'كل مبلغ داخل المال يجب أن يرتبط بتصنيف مالي.',
                              color: AppTheme.gold,
                              icon: LucideIcons.tags,
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _titleController,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'عنوان المصروف المدفوع',
                              hintText: 'مثال: دفعة لمورد أو شراء ورد',
                              prefixIcon: Icon(LucideIcons.receipt),
                            ),
                            validator: _required('عنوان المصروف مطلوب'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _amountController,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'المبلغ المدفوع',
                              suffixText: _currencyLabel,
                              prefixIcon: const Icon(LucideIcons.wallet),
                            ),
                            validator: _positiveRequired(
                              'المبلغ المدفوع مطلوب',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const AarastStatusPill(
                            label: 'يُحفظ هذا السجل كمصروف مدفوع فعلاً فقط.',
                            color: AppTheme.success,
                            icon: LucideIcons.checkCircle,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _noteController,
                            textAlign: TextAlign.right,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظات (اختياري)',
                              hintText:
                                  'أضف تفاصيل الدفعة أو الجهة المستلمة...',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            AarastStatusPill(
                              label: provider.errorMessage!,
                              color: AppTheme.danger,
                              icon: LucideIcons.alertCircle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AarastButton(
                      label: _isEditMode ? 'حفظ التعديلات' : 'حفظ المصروف',
                      icon: _isEditMode ? LucideIcons.save : LucideIcons.check,
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
    _expenseDate = expense.expenseDate;
    _didPrefill = true;
  }

  void _prefillQuoteContext(QuoteFinanceContext context) {
    _titleController.text = context.title;
    _amountController.text = context.amount?.trim() ?? '';
    _noteController.text = context.note;
    _didPrefill = true;
  }

  Future<void> _showCalendarPicker() async {
    return _pickDateFor(
      title: 'تاريخ الدفع',
      current: _expenseDate,
      onSelected: (date) => setState(() => _expenseDate = date),
    );
  }

  Future<void> _pickDateFor({
    required String title,
    required DateTime? current,
    required ValueChanged<DateTime> onSelected,
  }) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    var tempDate = current ?? now;

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
                  AarastSectionHeader(title: title, icon: LucideIcons.calendar),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(sheetContext).copyWith(
                      colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
                        primary: AppTheme.burgundy,
                        onPrimary: Colors.white,
                        surface: AppTheme.surface,
                        onSurface: AppTheme.ink,
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
                  AarastButton(
                    label: 'تأكيد التاريخ',
                    icon: LucideIcons.check,
                    onPressed: () => Navigator.of(sheetContext).pop(tempDate),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) onSelected(selected);
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
                    title: 'التصنيف المالي',
                    icon: LucideIcons.tags,
                  ),
                  const SizedBox(height: 14),
                  if (provider.budgetCategories.isEmpty) ...[
                    const AarastStatusPill(
                      label: 'أضف بند ميزانية أولاً ثم سجّل المصروف.',
                      color: AppTheme.gold,
                      icon: LucideIcons.folderPlus,
                    ),
                    const SizedBox(height: 12),
                    AarastButton(
                      label: 'إضافة بند ميزانية',
                      icon: LucideIcons.plus,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(
                          AppRouter.createBudgetCategory(widget.weddingPlanId),
                        );
                      },
                    ),
                  ] else
                    for (final category in provider.budgetCategories)
                      _CategoryRow(
                        label: category.name,
                        icon: LucideIcons.folder,
                        selected: category.id == _budgetCategoryId,
                        onTap: () =>
                            Navigator.of(sheetContext).pop(category.id),
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
      setState(() => _budgetCategoryId = selected);
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
    if (_budgetCategoryId == null) {
      AarastToast.showError(context, 'اختر تصنيف مالي قبل حفظ المصروف.');
      return;
    }
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<FinanceProvider>();
    final editingExpense = _isEditMode ? _editingExpense(provider) : null;
    final rawNote = _noteController.text.trim();
    final note = rawNote.isEmpty ? null : rawNote;
    final saved = _isEditMode
        ? editingExpense != null &&
              await provider.updateExpense(
                weddingPlanId: widget.weddingPlanId,
                expense: editingExpense,
                title: _titleController.text.trim(),
                amount: _amountController.text.trim(),
                budgetCategoryId: _budgetCategoryId,
                status: 'PAID',
                expenseDate: _expenseDate,
                note: note,
              )
        : await provider.createExpense(
            weddingPlanId: widget.weddingPlanId,
            title: _titleController.text.trim(),
            amount: _amountController.text.trim(),
            budgetCategoryId: _budgetCategoryId,
            status: 'PAID',
            expenseDate: _expenseDate,
            note: note,
          );

    if (_isEditMode && editingExpense == null && mounted) {
      AarastToast.showError(context, 'تعذر فتح المصروف للتعديل');
      return;
    }

    if (saved && mounted) {
      final notice = provider.noticeMessage;
      final message =
          notice ??
          (_isEditMode ? 'تم حفظ التعديلات بنجاح' : 'تم حفظ المصروف بنجاح');
      AarastToast.showSuccess(context, message);
      _goBack(changed: true);
    }
  }

  Expense? _editingExpense(FinanceProvider provider) {
    final expense = widget.initialExpense;
    if (expense != null) return expense;
    return _expenseFromProvider(provider);
  }
}
