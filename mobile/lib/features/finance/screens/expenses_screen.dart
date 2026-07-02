import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../providers/finance_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    required this.weddingPlanId,
    this.initialBudgetCategoryId,
    super.key,
  });

  final String weddingPlanId;
  final String? initialBudgetCategoryId;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _searchController = TextEditingController();
  _ExpenseFilter _filter = _ExpenseFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final category = _initialCategory(provider.budgetCategories);
    final expenses = _visibleExpenses(provider.expenses);
    final total = expenses.fold<num>(
      0,
      (sum, expense) => sum + _moneyValue(expense.amount),
    );

    return AarastScreenFrame(
      maxWidth: 520,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () => provider.loadFinance(widget.weddingPlanId),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'رجوع',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category == null
                        ? 'كل المصاريف'
                        : 'مصاريف ${category.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.burgundyDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(
                    AppRouter.createExpense(widget.weddingPlanId),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'إضافة مصروف',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.burgundy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(count: expenses.length, total: total),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث عن مصروف أو ملاحظة...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'مسح البحث',
                      ),
              ),
            ),
            const SizedBox(height: 12),
            _FilterRow(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 14),
            if (provider.isLoading && provider.expenses.isEmpty)
              const _Skeleton(height: 220)
            else if (expenses.isEmpty)
              const AarastEmptyState(
                title: 'لا توجد مصاريف مطابقة',
                message: 'غيّر البحث أو الفلتر لعرض سجلات أخرى.',
                icon: Icons.search_off_rounded,
              )
            else
              for (final expense in expenses) ...[
                _ExpenseCard(
                  expense: expense,
                  categoryName: _categoryName(
                    provider.budgetCategories,
                    expense.budgetCategoryId,
                  ),
                  isBusy: provider.isSubmitting,
                  onEdit: () => _openEditExpense(expense),
                  onDelete: () => _confirmDeleteExpense(provider, expense),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  BudgetCategory? _initialCategory(List<BudgetCategory> categories) {
    final id = widget.initialBudgetCategoryId;
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  List<Expense> _visibleExpenses(List<Expense> expenses) {
    final query = _normalize(_searchController.text);
    return expenses.where((expense) {
      if (widget.initialBudgetCategoryId != null &&
          expense.budgetCategoryId != widget.initialBudgetCategoryId) {
        return false;
      }
      if (_filter.status != null && expense.status != _filter.status) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = _normalize('${expense.title} ${expense.note ?? ''}');
      return haystack.contains(query);
    }).toList();
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }

  Future<void> _openEditExpense(Expense expense) async {
    if (expense.id.startsWith('local-')) {
      AarastToast.showInfo(
        context,
        'هذا المصروف محفوظ على هذا الجهاز وقيد المزامنة. انتظر اكتمال المزامنة قبل تعديله.',
      );
      return;
    }

    final changed = await context.push<bool>(
      AppRouter.editExpense(widget.weddingPlanId, expense.id),
      extra: expense,
    );
    if (changed == true && mounted) {
      await context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    }
  }

  Future<void> _confirmDeleteExpense(
    FinanceProvider provider,
    Expense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المصروف؟'),
        content: Text('سيتم حذف "${expense.title}" من السجل المالي.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await provider.deleteExpense(
      weddingPlanId: widget.weddingPlanId,
      expense: expense,
    );
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'تم حذف المصروف');
    } else if (provider.errorMessage != null) {
      AarastToast.showError(context, provider.errorMessage!);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count, required this.total});

  final int count;
  final num total;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppTheme.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count سجل',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${_formatMoney(total)} ر.ي',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.burgundy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});

  final _ExpenseFilter selected;
  final ValueChanged<_ExpenseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _ExpenseFilter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: selected == filter,
              showCheckmark: false,
              onSelected: (_) => onChanged(filter),
              selectedColor: AppTheme.burgundy,
              backgroundColor: AppTheme.surface,
              side: const BorderSide(color: AppTheme.border),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected == filter ? Colors.white : AppTheme.muted,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.categoryName,
    required this.isBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final String categoryName;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _expenseStatusColor(expense.status);
    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(Icons.receipt_long_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AarastStatusPill(
                      label: _expenseStatusLabel(expense.status),
                      color: color,
                    ),
                    AarastStatusPill(
                      label: categoryName,
                      color: AppTheme.gold,
                      icon: Icons.folder_outlined,
                    ),
                    if (expense.expenseDate != null)
                      AarastStatusPill(
                        label: formatArabicCompactDate(expense.expenseDate!),
                        color: AppTheme.muted,
                        icon: Icons.calendar_month_rounded,
                      ),
                  ],
                ),
                if (expense.hasNote) ...[
                  const SizedBox(height: 8),
                  Text(
                    expense.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatMoney(_moneyValue(expense.amount))} ر.ي',
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.burgundy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              PopupMenuButton<_ExpenseAction>(
                enabled: !isBusy,
                tooltip: 'خيارات المصروف',
                onSelected: (action) {
                  if (action == _ExpenseAction.edit) onEdit();
                  if (action == _ExpenseAction.delete) onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ExpenseAction.edit,
                    child: Text('تعديل'),
                  ),
                  PopupMenuItem(
                    value: _ExpenseAction.delete,
                    child: Text('حذف'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
    );
  }
}

enum _ExpenseFilter {
  all(null, 'الكل'),
  paid('PAID', 'مدفوع'),
  planned('PLANNED', 'مخطط'),
  cancelled('CANCELLED', 'ملغي');

  const _ExpenseFilter(this.status, this.label);
  final String? status;
  final String label;
}

enum _ExpenseAction { edit, delete }

String _categoryName(List<BudgetCategory> categories, String? id) {
  if (id == null || id.trim().isEmpty) return 'غير مصنف';
  for (final category in categories) {
    if (category.id == id) return category.name;
  }
  return 'غير مصنف';
}

Color _expenseStatusColor(String status) {
  return switch (status) {
    'PAID' => AppTheme.success,
    'CANCELLED' => AppTheme.muted,
    _ => AppTheme.gold,
  };
}

String _expenseStatusLabel(String status) {
  return switch (status) {
    'PAID' => 'مدفوع',
    'CANCELLED' => 'ملغي',
    _ => 'مخطط',
  };
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .trim();
}

num _moneyValue(String? value) =>
    num.tryParse(value?.replaceAll(',', '').trim() ?? '') ?? 0;

String _formatMoney(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}
