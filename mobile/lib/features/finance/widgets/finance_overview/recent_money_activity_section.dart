import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/offline/offline_status_widgets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/widgets/aarast_ui.dart';
import '../../models/budget_category.dart';
import '../../models/expense.dart';
import '../../models/financial_commitment.dart';
import '../../models/money_formatters.dart';
import 'finance_overview_components.dart';

class RecentMoneyActivitySection extends StatelessWidget {
  const RecentMoneyActivitySection({
    required this.expenses,
    required this.payments,
    required this.budgetCategories,
    required this.isBusy,
    required this.canManageFinancialRecords,
    required this.currencyCode,
    required this.onEditExpense,
    required this.onOpenPayment,
    required this.onDeleteExpense,
    this.onViewAllExpenses,
    super.key,
  });

  final List<Expense> expenses;
  final List<FinancialPaymentRecord> payments;
  final List<BudgetCategory> budgetCategories;
  final bool isBusy;
  final bool canManageFinancialRecords;
  final String currencyCode;
  final ValueChanged<Expense> onEditExpense;
  final ValueChanged<FinancialPaymentRecord> onOpenPayment;
  final ValueChanged<Expense> onDeleteExpense;
  final VoidCallback? onViewAllExpenses;

  @override
  Widget build(BuildContext context) {
    final events = _buildRecentMoneyEvents(
      expenses: expenses,
      payments: payments,
    ).take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'آخر الحركات',
          icon: LucideIcons.clock,
          actionLabel: onViewAllExpenses == null ? null : 'عرض المصاريف',
          onAction: onViewAllExpenses,
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'لا توجد حركات مالية بعد. سجّل دفعة أو مصروفًا عند خروج المال فعلًا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.muted.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.ink.withValues(alpha: 0.05),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final event = events[index];
                final expense = event.expense;
                if (expense != null) {
                  return _ExpenseRow(
                    expense: expense,
                    currencyCode: currencyCode,
                    categoryName: _categoryName(
                      budgetCategories,
                      expense.budgetCategoryId,
                    ),
                    isBusy: isBusy,
                    onTap: canManageFinancialRecords
                        ? () => onEditExpense(expense)
                        : null,
                    onEdit: canManageFinancialRecords
                        ? () => onEditExpense(expense)
                        : null,
                    onDelete: canManageFinancialRecords
                        ? () => onDeleteExpense(expense)
                        : null,
                  );
                }
                return FinanceTapInlineTile(
                  onTap: () {
                    final payment = event.payment;
                    if (payment != null) onOpenPayment(payment);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FinanceMoneyEventTile(
                      title: event.title,
                      subtitle: event.subtitle,
                      amount: event.amount,
                      icon: event.icon,
                      color: event.color,
                      currencyCode: currencyCode,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RecentMoneyEvent {
  _RecentMoneyEvent.expense(Expense value)
    : expense = value,
      payment = null,
      occurredAt = value.expenseDate ?? value.createdAt;

  _RecentMoneyEvent.payment(FinancialPaymentRecord value)
    : expense = null,
      payment = value,
      occurredAt = value.paidAt;

  final Expense? expense;
  final FinancialPaymentRecord? payment;
  final DateTime occurredAt;

  String get title => expense?.title ?? payment!.title;
  String get subtitle =>
      expense == null ? _shortDate(payment!.paidAt) : _shortDate(occurredAt);
  String get amount => expense?.amount ?? payment!.signedAmount;
  IconData get icon => expense == null
      ? (payment!.isReversal ? LucideIcons.undo2 : LucideIcons.banknote)
      : LucideIcons.receipt;
  Color get color => expense == null
      ? (payment!.isReversal ? AppTheme.danger : AppTheme.success)
      : _expenseStatusColor(expense!.status);
}

List<_RecentMoneyEvent> _buildRecentMoneyEvents({
  required List<Expense> expenses,
  required List<FinancialPaymentRecord> payments,
}) {
  final events = <_RecentMoneyEvent>[
    for (final payment in payments) _RecentMoneyEvent.payment(payment),
    for (final expense in expenses) _RecentMoneyEvent.expense(expense),
  ];
  events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return events;
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.currencyCode,
    required this.categoryName,
    required this.isBusy,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Expense expense;
  final String currencyCode;
  final String categoryName;
  final bool isBusy;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = _expenseStatusColor(expense.status);
    final isPaid = expense.status == 'PAID';

    return AarastPressable(
      clip: false,
      semanticLabel: 'فتح المصروف ${expense.title}',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isPaid ? LucideIcons.receipt : LucideIcons.calendarClock,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      AarastStatusPill(
                        label: _expenseStatusLabel(expense.status),
                        color: statusColor,
                      ),
                      AarastStatusPill(
                        label: categoryName,
                        color: AppTheme.gold,
                        icon: LucideIcons.folder,
                      ),
                      if (expense.expenseDate != null)
                        AarastStatusPill(
                          label: _shortDate(expense.expenseDate!),
                          color: AppTheme.muted,
                          icon: LucideIcons.calendarDays,
                        ),
                      OfflinePendingBadge(
                        entityType: 'expense',
                        entityId: expense.id,
                      ),
                    ],
                  ),
                  if (expense.hasNote) ...[
                    const SizedBox(height: 8),
                    Text(
                      expense.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.ink.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _AnimatedMoneyText(
              value: expense.amount,
              currencyCode: currencyCode,
              style: const TextStyle(
                color: AppTheme.burgundy,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 2),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<_ExpenseAction>(
                enabled: !isBusy,
                tooltip: 'خيارات المصروف',
                icon: const Icon(
                  LucideIcons.moreVertical,
                  color: AppTheme.muted,
                ),
                onSelected: (action) {
                  if (action == _ExpenseAction.edit) {
                    onEdit?.call();
                  } else {
                    onDelete?.call();
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: _ExpenseAction.edit,
                      child: _ExpenseMenuItem(
                        icon: LucideIcons.pencil,
                        label: 'تعديل',
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: _ExpenseAction.delete,
                      child: _ExpenseMenuItem(
                        icon: LucideIcons.trash2,
                        label: 'حذف',
                        color: AppTheme.danger,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _ExpenseAction { edit, delete }

class _ExpenseMenuItem extends StatelessWidget {
  const _ExpenseMenuItem({
    required this.icon,
    required this.label,
    this.color = AppTheme.ink,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _AnimatedMoneyText extends StatelessWidget {
  const _AnimatedMoneyText({
    required this.value,
    required this.currencyCode,
    this.style,
  });

  final String value;
  final String currencyCode;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cleaned = value.replaceAll(',', '').replaceAll(' ر.ي', '').trim();
    final targetValue = double.tryParse(cleaned) ?? 0.0;
    if (targetValue.isNaN || targetValue.isInfinite || targetValue == 0.0) {
      return Text(
        formatCompactMoney(targetValue, currencyCode: currencyCode),
        textDirection: TextDirection.ltr,
        style: style,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        final formatted = formatCompactMoney(val, currencyCode: currencyCode);
        return Text(formatted, style: style);
      },
    );
  }
}

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

String _shortDate(DateTime date) => formatArabicCompactDate(date);
