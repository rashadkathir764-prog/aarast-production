import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/models/quote_finance_context.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../debts/providers/debt_installment_provider.dart';
import '../../marketplace/models/provider_budget_match_intent.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../providers/finance_provider.dart';

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
  final _hallNameController = TextEditingController();
  final _hallTotalController = TextEditingController();
  final _hallContactNameController = TextEditingController();
  final _hallContactPhoneController = TextEditingController();
  final _hallAddressController = TextEditingController();

  String? _budgetCategoryId;
  String _status = 'PLANNED';
  String _paymentType = 'عربون';
  String _paymentMethod = 'نقداً';
  DateTime? _expenseDate;
  DateTime? _bookingDate;
  DateTime? _remainingDueDate;
  DateTime? _weddingDate;
  bool _didPrefill = false;
  bool _showHallDetails = false;
  bool _createRemainingReminder = true;
  final Set<String> _includedServices = <String>{};

  bool get _isEditMode =>
      widget.expenseId != null || widget.initialExpense != null;

  @override
  void initState() {
    super.initState();
    _hallTotalController.addListener(_refreshHallTotals);
    _amountController.addListener(_refreshHallTotals);
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
      final provider = context.read<FinanceProvider>();
      if (AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) {
        setState(() {
          _applyCategoryDefaults(_selectedCategory(provider.budgetCategories));
        });
        return;
      }
      _loadFinanceForForm(provider);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeddingDate());
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
    _hallNameController.dispose();
    _hallTotalController.dispose();
    _hallContactNameController.dispose();
    _hallContactPhoneController.dispose();
    _hallAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final category = _selectedCategory(provider.budgetCategories);
    final isHallExpense = _isHallCategory(category);
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
                    icon: const Icon(Icons.arrow_forward_rounded),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditMode ? 'تعديل مصروف' : 'إضافة مصروف',
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
                            dateLabel: isHallExpense
                                ? 'تاريخ الدفع'
                                : 'التاريخ',
                            onCategoryTap: _showCategoryPicker,
                            onDateTap: _showCalendarPicker,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _titleController,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'عنوان المصروف',
                              hintText: 'مثال: دفعة صالة الأفراح',
                              prefixIcon: Icon(Icons.receipt_long_outlined),
                            ),
                            validator: _required('عنوان المصروف مطلوب'),
                          ),
                          const SizedBox(height: 14),
                          if (isHallExpense) ...[
                            _HallExpenseFields(
                              hallNameController: _hallNameController,
                              hallTotalController: _hallTotalController,
                              amountController: _amountController,
                              contactNameController: _hallContactNameController,
                              contactPhoneController:
                                  _hallContactPhoneController,
                              addressController: _hallAddressController,
                              paymentType: _paymentType,
                              paymentMethod: _paymentMethod,
                              bookingDate: _bookingDate,
                              weddingDate: _weddingDate,
                              remainingDueDate: _remainingDueDate,
                              showDetails: _showHallDetails,
                              createRemainingReminder: _createRemainingReminder,
                              includedServices: _includedServices,
                              totalAmount: _hallTotal,
                              paidAmount: _paymentAmount,
                              remainingAmount: _hallRemaining,
                              duplicateWarning: _hasPossibleHallDuplicate(
                                provider.expenses,
                              ),
                              onChooseProvider: () =>
                                  _openProviderMatches(category),
                              onPaymentTypeChanged: (value) {
                                setState(() => _paymentType = value);
                              },
                              onPaymentMethodChanged: (value) {
                                setState(() => _paymentMethod = value);
                              },
                              onBookingDateTap: () => _pickDateFor(
                                title: 'تاريخ الحجز',
                                current: _bookingDate,
                                onSelected: (date) =>
                                    setState(() => _bookingDate = date),
                              ),
                              onRemainingDueDateTap: () => _pickDateFor(
                                title: 'موعد دفع الباقي',
                                current: _remainingDueDate,
                                onSelected: (date) =>
                                    setState(() => _remainingDueDate = date),
                              ),
                              onToggleDetails: () {
                                setState(
                                  () => _showHallDetails = !_showHallDetails,
                                );
                              },
                              onToggleReminder: (value) {
                                setState(
                                  () => _createRemainingReminder = value,
                                );
                              },
                              onServiceToggled: (service) {
                                setState(() {
                                  if (_includedServices.contains(service)) {
                                    _includedServices.remove(service);
                                  } else {
                                    _includedServices.add(service);
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (!isHallExpense) ...[
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
                            const SizedBox(height: 18),
                          ],
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'حالة المصروف',
                              style: TextStyle(
                                color: AppTheme.ink,
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
                                color: AppTheme.gold,
                                selected: _status == 'PLANNED',
                                onTap: () {
                                  setState(() => _status = 'PLANNED');
                                },
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(
                                label: 'مدفوع',
                                icon: Icons.check_circle_rounded,
                                color: AppTheme.success,
                                selected: _status == 'PAID',
                                onTap: () {
                                  setState(() => _status = 'PAID');
                                },
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(
                                label: 'ملغي',
                                icon: Icons.block_rounded,
                                color: AppTheme.muted,
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
                                  'أضف تفاصيل الدفعة أو الجهة المستلمة...',
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
                    AarastButton(
                      label: _isEditMode ? 'حفظ التعديلات' : 'حفظ المصروف',
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
    );
  }

  BudgetCategory? _selectedCategory(List<BudgetCategory> categories) {
    for (final category in categories) {
      if (category.id == _budgetCategoryId) return category;
    }
    return null;
  }

  num get _hallTotal => _moneyValue(_hallTotalController.text) ?? 0;
  num get _paymentAmount => _moneyValue(_amountController.text) ?? 0;
  num get _hallRemaining => (_hallTotal - _paymentAmount).clamp(0, _hallTotal);

  void _refreshHallTotals() {
    if (!mounted) return;
    setState(() {
      if (_hallTotal > 0 && _paymentAmount >= _hallTotal) {
        _createRemainingReminder = false;
      } else if (_hallTotal > 0 && _paymentAmount < _hallTotal) {
        _createRemainingReminder = true;
        _remainingDueDate ??= _defaultRemainingDueDate();
      }
    });
  }

  Future<void> _loadWeddingDate() async {
    try {
      final plansProvider = context.read<WeddingPlansProvider>();
      final selected = plansProvider.selectedPlan;
      final active = plansProvider.activePlan;
      final localDate = selected?.weddingDate ?? active?.weddingDate;
      if (localDate != null) {
        if (mounted) setState(() => _weddingDate = localDate);
        return;
      }
      if (AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) return;
      await plansProvider.loadWeddingPlan(widget.weddingPlanId);
      if (!mounted) return;
      setState(() {
        _weddingDate = plansProvider.selectedPlan?.weddingDate;
        _remainingDueDate ??= _defaultRemainingDueDate();
      });
    } catch (_) {
      // Some focused widget tests mount this screen without the plan provider.
    }
  }

  DateTime _defaultRemainingDueDate() {
    final weddingDate = _weddingDate;
    if (weddingDate != null) {
      return weddingDate.subtract(const Duration(days: 7));
    }
    return DateTime.now().add(const Duration(days: 7));
  }

  void _applyCategoryDefaults(BudgetCategory? category) {
    if (!_isHallCategory(category) || _isEditMode) return;
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = 'دفعة صالة الأفراح';
    }
    if (_hallTotalController.text.trim().isEmpty &&
        category?.targetAmount?.trim().isNotEmpty == true) {
      _hallTotalController.text = category!.targetAmount!.trim();
    }
    _status = 'PAID';
    _expenseDate ??= DateTime.now();
    _bookingDate ??= DateTime.now();
    _remainingDueDate ??= _defaultRemainingDueDate();
  }

  bool _isHallCategory(BudgetCategory? category) {
    final value = _normalizeArabic(category?.name ?? '');
    if (value.isEmpty) return false;
    return value.contains('صالة') ||
        value.contains('الصالة') ||
        value.contains('صاله') ||
        value.contains('الصاله') ||
        value.contains('قاعة') ||
        value.contains('القاعة') ||
        value.contains('قاعه') ||
        value.contains('القاعه') ||
        value.contains('hall') ||
        value.contains('venue');
  }

  bool _hasPossibleHallDuplicate(List<Expense> expenses) {
    final hallName = _normalizeArabic(_hallNameController.text);
    if (hallName.isEmpty) return false;
    return expenses.any((expense) {
      if (_isEditMode && expense.id == widget.expenseId) return false;
      final haystack = _normalizeArabic(
        '${expense.title} ${expense.note ?? ''}',
      );
      return haystack.contains(hallName);
    });
  }

  void _openProviderMatches(BudgetCategory? category) {
    final allocated = _hallTotal > 0
        ? _moneyPayload(_hallTotal)
        : category?.targetAmount;
    context.push(
      AppRouter.planProviders(widget.weddingPlanId),
      extra: ProviderBudgetMatchIntent(
        budgetCategoryName: category?.name ?? 'الصالة',
        allocatedAmount: allocated,
      ),
    );
  }

  Future<void> _loadFinanceForForm(FinanceProvider provider) async {
    final shouldLoad =
        provider.budgetCategories.isEmpty ||
        (_isEditMode && _expenseFromProvider(provider) == null);
    if (shouldLoad) {
      await provider.loadFinance(widget.weddingPlanId);
    }
    if (mounted) {
      setState(() {
        _applyCategoryDefaults(_selectedCategory(provider.budgetCategories));
      });
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

  void _prefillQuoteContext(QuoteFinanceContext context) {
    _titleController.text = context.title;
    _amountController.text = context.amount?.trim() ?? '';
    _noteController.text = context.note;
    _status = 'PLANNED';
    _didPrefill = true;
  }

  Future<void> _showCalendarPicker() async {
    return _pickDateFor(
      title: 'تاريخ المصروف',
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
                  AarastSectionHeader(
                    title: title,
                    icon: Icons.calendar_month_rounded,
                  ),
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
      setState(() {
        _budgetCategoryId = selected.isEmpty ? null : selected;
        _applyCategoryDefaults(_selectedCategory(provider.budgetCategories));
      });
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
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<FinanceProvider>();
    final category = _selectedCategory(provider.budgetCategories);
    final isHallExpense = _isHallCategory(category);
    final note = _expenseNote(isHallExpense: isHallExpense);
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
                note: note,
              )
        : await provider.createExpense(
            weddingPlanId: widget.weddingPlanId,
            title: _titleController.text.trim(),
            amount: _amountController.text.trim(),
            budgetCategoryId: _budgetCategoryId,
            status: _status,
            expenseDate: _expenseDate,
            note: note,
          );

    if (_isEditMode && editingExpense == null && mounted) {
      AarastToast.showError(context, 'تعذر فتح المصروف للتعديل');
      return;
    }

    if (saved && mounted) {
      if (!_isEditMode && isHallExpense && !_isHallFullyPaid) {
        final reminderCreated = await _createRemainingHallReminder();
        if (!mounted) return;
        if (!reminderCreated && mounted) {
          AarastToast.showError(
            context,
            'تم حفظ الدفعة، لكن تعذر إنشاء تذكير دفع الباقي.',
          );
        }
      }
      final notice = provider.noticeMessage;
      final message =
          notice ??
          (_isEditMode ? 'تم حفظ التعديلات بنجاح' : 'تم حفظ المصروف بنجاح');
      AarastToast.showSuccess(context, message);
      _goBack(changed: true);
    }
  }

  bool get _isHallFullyPaid => _hallTotal > 0 && _paymentAmount >= _hallTotal;

  String? _expenseNote({required bool isHallExpense}) {
    final userNote = _noteController.text.trim();
    if (!isHallExpense) return userNote.isEmpty ? null : userNote;

    final lines = <String>[
      'تفاصيل الصالة:',
      if (_hallNameController.text.trim().isNotEmpty)
        'اسم الصالة: ${_hallNameController.text.trim()}',
      if (_hallTotal > 0)
        'إجمالي تكلفة الصالة: ${_moneyPayload(_hallTotal)} ر.ي',
      if (_paymentAmount > 0)
        'مبلغ هذه الدفعة: ${_moneyPayload(_paymentAmount)} ر.ي',
      'نوع الدفعة: $_paymentType',
      'طريقة الدفع: $_paymentMethod',
      if (_bookingDate != null) 'تاريخ الحجز: ${_formatDate(_bookingDate!)}',
      if (_weddingDate != null) 'تاريخ المناسبة: ${_formatDate(_weddingDate!)}',
      if (_hallRemaining > 0) 'المتبقي: ${_moneyPayload(_hallRemaining)} ر.ي',
      if (_hallRemaining > 0 && _remainingDueDate != null)
        'موعد دفع الباقي: ${_formatDate(_remainingDueDate!)}',
      if (_hallContactNameController.text.trim().isNotEmpty)
        'اسم المسؤول: ${_hallContactNameController.text.trim()}',
      if (_hallContactPhoneController.text.trim().isNotEmpty)
        'رقم المسؤول: ${_hallContactPhoneController.text.trim()}',
      if (_hallAddressController.text.trim().isNotEmpty)
        'عنوان الصالة: ${_hallAddressController.text.trim()}',
      if (_includedServices.isNotEmpty)
        'الخدمات المشمولة: ${_includedServices.join('، ')}',
      if (userNote.isNotEmpty) 'ملاحظات: $userNote',
    ];
    return lines.join('\n');
  }

  Future<bool> _createRemainingHallReminder() async {
    if (!_createRemainingReminder || _hallRemaining <= 0) return true;

    final hallName = _hallNameController.text.trim().isEmpty
        ? 'الصالة'
        : _hallNameController.text.trim();
    try {
      final debtProvider = context.read<DebtInstallmentProvider>();
      final debt = await debtProvider.createDebt(
        weddingPlanId: widget.weddingPlanId,
        creditorName: hallName,
        title: 'باقي $hallName',
        totalAmount: _moneyPayload(_hallRemaining),
        dueDate: _remainingDueDate ?? _defaultRemainingDueDate(),
        status: 'OPEN',
        note:
            'باقي تكلفة الصالة بعد دفعة ${_moneyPayload(_paymentAmount)} ر.ي.',
      );
      if (debt == null) return false;
      return debtProvider.createInstallment(
        debtId: debt.id,
        amount: _moneyPayload(_hallRemaining),
        dueDate: _remainingDueDate ?? _defaultRemainingDueDate(),
        status: 'PENDING',
        note: 'تذكير دفع باقي الصالة.',
      );
    } catch (_) {
      return false;
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
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft),
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
                  isEditMode ? 'راجع تفاصيل المصروف' : 'سجّل كل دفعة بوضوح',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditMode
                      ? 'أي تعديل هنا سينعكس على ملخص الميزانية والمصاريف.'
                      : 'التفاصيل الصغيرة تمنع مفاجآت الميزانية لاحقاً.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
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

class _CategoryDateRow extends StatelessWidget {
  const _CategoryDateRow({
    required this.category,
    required this.expenseDate,
    required this.dateLabel,
    required this.onCategoryTap,
    required this.onDateTap,
  });

  final BudgetCategory? category;
  final DateTime? expenseDate;
  final String dateLabel;
  final VoidCallback onCategoryTap;
  final VoidCallback onDateTap;

  @override
  Widget build(BuildContext context) {
    final categoryField = _SelectorField(
      label: 'التصنيف',
      value: category?.name ?? 'بدون تصنيف',
      icon: Icons.folder_outlined,
      selected: category != null,
      onTap: onCategoryTap,
    );
    final dateField = _SelectorField(
      label: dateLabel,
      value: expenseDate == null ? 'لم يحدد بعد' : _formatDate(expenseDate!),
      icon: Icons.calendar_month_rounded,
      selected: expenseDate != null,
      onTap: onDateTap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            children: [categoryField, const SizedBox(height: 12), dateField],
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
    );
  }
}

class _HallExpenseFields extends StatelessWidget {
  const _HallExpenseFields({
    required this.hallNameController,
    required this.hallTotalController,
    required this.amountController,
    required this.contactNameController,
    required this.contactPhoneController,
    required this.addressController,
    required this.paymentType,
    required this.paymentMethod,
    required this.bookingDate,
    required this.weddingDate,
    required this.remainingDueDate,
    required this.showDetails,
    required this.createRemainingReminder,
    required this.includedServices,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.duplicateWarning,
    required this.onChooseProvider,
    required this.onPaymentTypeChanged,
    required this.onPaymentMethodChanged,
    required this.onBookingDateTap,
    required this.onRemainingDueDateTap,
    required this.onToggleDetails,
    required this.onToggleReminder,
    required this.onServiceToggled,
  });

  final TextEditingController hallNameController;
  final TextEditingController hallTotalController;
  final TextEditingController amountController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;
  final TextEditingController addressController;
  final String paymentType;
  final String paymentMethod;
  final DateTime? bookingDate;
  final DateTime? weddingDate;
  final DateTime? remainingDueDate;
  final bool showDetails;
  final bool createRemainingReminder;
  final Set<String> includedServices;
  final num totalAmount;
  final num paidAmount;
  final num remainingAmount;
  final bool duplicateWarning;
  final VoidCallback onChooseProvider;
  final ValueChanged<String> onPaymentTypeChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onBookingDateTap;
  final VoidCallback onRemainingDueDateTap;
  final VoidCallback onToggleDetails;
  final ValueChanged<bool> onToggleReminder;
  final ValueChanged<String> onServiceToggled;

  static const _paymentTypes = [
    'عربون',
    'دفعة أولى',
    'دفعة ثانية',
    'دفعة نهائية',
    'مبلغ كامل',
  ];
  static const _paymentMethods = [
    'نقداً',
    'حوالة',
    'كريمي',
    'بنك',
    'شيك',
    'أخرى',
  ];
  static const _services = [
    'كوشة',
    'صوت',
    'إضاءة',
    'تصوير',
    'عشاء',
    'ضيافة',
    'مواقف',
    'حراسة',
  ];

  @override
  Widget build(BuildContext context) {
    final hasRemaining = remainingAmount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: hallNameController,
          textAlign: TextAlign.right,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'اسم الصالة',
            hintText: 'مثال: قاعة الملكة',
            prefixIcon: const Icon(Icons.apartment_rounded),
            suffixIcon: IconButton(
              tooltip: 'اختيار من الموردين',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: onChooseProvider,
            ),
          ),
          validator: _required('اسم الصالة مطلوب'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: hallTotalController,
          textAlign: TextAlign.right,
          textInputAction: TextInputAction.next,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'إجمالي تكلفة الصالة',
            suffixText: 'ر.ي',
            prefixIcon: Icon(Icons.price_check_rounded),
          ),
          validator: _positiveRequired('إجمالي تكلفة الصالة مطلوب'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: amountController,
          textAlign: TextAlign.right,
          textInputAction: TextInputAction.next,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'مبلغ هذه الدفعة',
            suffixText: 'ر.ي',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          validator: _nonNegativeRequired('مبلغ الدفعة غير صحيح'),
        ),
        const SizedBox(height: 14),
        _ChoiceGroup(
          title: 'نوع الدفعة',
          values: _paymentTypes,
          selected: paymentType,
          onSelected: onPaymentTypeChanged,
        ),
        const SizedBox(height: 14),
        _ChoiceGroup(
          title: 'طريقة الدفع',
          values: _paymentMethods,
          selected: paymentMethod,
          onSelected: onPaymentMethodChanged,
        ),
        const SizedBox(height: 14),
        _SelectorField(
          label: 'تاريخ الحجز / الاتفاق',
          value: bookingDate == null
              ? 'لم يحدد بعد'
              : _formatDate(bookingDate!),
          icon: Icons.event_available_rounded,
          selected: bookingDate != null,
          onTap: onBookingDateTap,
        ),
        if (weddingDate != null) ...[
          const SizedBox(height: 12),
          _ReadOnlyInfoRow(
            label: 'تاريخ المناسبة',
            value: _formatDate(weddingDate!),
            icon: Icons.favorite_rounded,
          ),
        ],
        const SizedBox(height: 14),
        _HallPaymentSummary(
          totalAmount: totalAmount,
          paidAmount: paidAmount,
          remainingAmount: remainingAmount,
        ),
        if (hasRemaining) ...[
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: createRemainingReminder,
            onChanged: onToggleReminder,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'ذكرني بدفع الباقي',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'سيظهر الباقي ضمن الدفعات القادمة.',
              textAlign: TextAlign.right,
            ),
            activeThumbColor: AppTheme.burgundy,
            activeTrackColor: AppTheme.burgundySoft,
          ),
          _SelectorField(
            label: 'موعد دفع الباقي',
            value: remainingDueDate == null
                ? 'قبل المناسبة أو اختر تاريخاً'
                : _formatDate(remainingDueDate!),
            icon: Icons.notifications_active_outlined,
            selected: remainingDueDate != null,
            onTap: onRemainingDueDateTap,
          ),
        ],
        if (duplicateWarning) ...[
          const SizedBox(height: 12),
          const AarastStatusPill(
            label: 'هذه الصالة مضافة مسبقاً. راجعها حتى لا يتكرر الحجز.',
            color: AppTheme.gold,
            icon: Icons.info_outline_rounded,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onToggleDetails,
          icon: Icon(
            showDetails
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
          ),
          label: const Text('تفاصيل الصالة'),
        ),
        if (showDetails) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: contactNameController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'اسم المسؤول',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: contactPhoneController,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم المسؤول',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'عنوان الصالة',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'الخدمات المشمولة',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final service in _services)
                FilterChip(
                  label: Text(service),
                  selected: includedServices.contains(service),
                  onSelected: (_) => onServiceToggled(service),
                  selectedColor: AppTheme.burgundySoft,
                  checkmarkColor: AppTheme.burgundy,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(value),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
                selectedColor: AppTheme.burgundySoft,
                labelStyle: TextStyle(
                  color: selected == value ? AppTheme.burgundy : AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReadOnlyInfoRow extends StatelessWidget {
  const _ReadOnlyInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
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

class _HallPaymentSummary extends StatelessWidget {
  const _HallPaymentSummary({
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
  });

  final num totalAmount;
  final num paidAmount;
  final num remainingAmount;

  @override
  Widget build(BuildContext context) {
    final percentage = totalAmount <= 0
        ? 0
        : ((paidAmount / totalAmount) * 100).clamp(0, 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      child: Column(
        children: [
          _SummaryLine(label: 'إجمالي الصالة', value: totalAmount),
          _SummaryLine(label: 'المدفوع الآن', value: paidAmount),
          _SummaryLine(label: 'المتبقي', value: remainingAmount),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 7,
            color: AppTheme.burgundy,
            backgroundColor: AppTheme.border,
          ),
          const SizedBox(height: 6),
          Text(
            'نسبة الدفع: $percentage%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${_formatMoney(value)} ر.ي',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.burgundy : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.burgundy : AppTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.muted,
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
            color: selected ? color.withAlpha(24) : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? color : AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? color : AppTheme.muted, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppTheme.muted,
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
        color: selected ? AppTheme.burgundySoft : AppTheme.surface,
        border: Border.all(
          color: selected ? AppTheme.burgundy : AppTheme.border,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.burgundy : AppTheme.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AppTheme.burgundy : AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.burgundy),
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
          color: AppTheme.border,
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
    final parsed = _moneyValue(rawValue);
    if (parsed == null || parsed < 0) return message;
    return null;
  };
}

FormFieldValidator<String> _positiveRequired(String message) {
  return (value) {
    final parsed = _moneyValue(value);
    if (parsed == null || parsed <= 0) return message;
    return null;
  };
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}

num? _moneyValue(String? value) {
  final clean = value?.replaceAll(',', '').trim() ?? '';
  if (clean.isEmpty) return null;
  return num.tryParse(clean);
}

String _moneyPayload(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _formatMoney(num value) {
  final text = _moneyPayload(value);
  final parts = text.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  if (parts.length > 1) buffer.write('.${parts[1]}');
  return buffer.toString();
}

String _normalizeArabic(String value) {
  return value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
      .trim();
}
