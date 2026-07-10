import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../marketplace/models/provider_budget_match_intent.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/financial_commitment.dart';
import '../models/money_summary.dart';
import '../providers/finance_provider.dart';

class BudgetCategoryDetailsScreen extends StatefulWidget {
  const BudgetCategoryDetailsScreen({
    required this.weddingPlanId,
    required this.budgetCategoryId,
    super.key,
  });

  final String weddingPlanId;
  final String budgetCategoryId;

  @override
  State<BudgetCategoryDetailsScreen> createState() =>
      _BudgetCategoryDetailsScreenState();
}

class _BudgetCategoryDetailsScreenState
    extends State<BudgetCategoryDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final currencyLabel = _planCurrencyLabel(context, widget.weddingPlanId);
    final category = _findCategory(provider.budgetCategories);
    final expenses = provider.expenses
        .where((expense) => expense.budgetCategoryId == widget.budgetCategoryId)
        .toList();
    final commitments =
        provider.financialCommitments
            .where(
              (commitment) =>
                  commitment.budgetCategoryId == widget.budgetCategoryId &&
                  !commitment.isCancelled,
            )
            .toList()
          ..sort(_compareCommitmentDueDate);
    final payments = provider.financialPaymentRecords
        .where((payment) => payment.budgetCategoryId == widget.budgetCategoryId)
        .toList();
    final movements = _categoryMovements(expenses, payments);
    final summary = category == null
        ? null
        : _categorySummary(provider.moneySummary, category, expenses);

    return AarastScreenFrame(
      maxWidth: 520,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () => provider.loadFinance(widget.weddingPlanId),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: [
            _Header(title: category?.name ?? 'تفاصيل بند', onBack: _goBack),
            const SizedBox(height: 14),
            if (provider.isLoading && category == null)
              const _Skeleton(height: 220)
            else if (category == null)
              const AarastEmptyState(
                title: 'البند غير موجود',
                message: 'ربما تم حذف هذا البند أو لم يتم تحميل البيانات بعد.',
                icon: LucideIcons.folderX,
              )
            else ...[
              _CategoryHero(
                category: category,
                summary: summary!,
                currencyLabel: currencyLabel,
              ),
              const SizedBox(height: 20),
              AarastSectionHeader(
                title: 'المستحقات المرتبطة',
                icon: LucideIcons.wallet,
                actionLabel: 'إضافة مستحق',
                onAction: () => _openCreateCommitment(category),
              ),
              const SizedBox(height: 12),
              if (commitments.isEmpty)
                const _QuietEmpty(
                  message: 'لا توجد مستحقات مرتبطة بهذا البند بعد.',
                )
              else
                for (final commitment in commitments) ...[
                  _FinanceRecordTile(
                    icon: LucideIcons.wallet,
                    color: _commitmentColor(commitment),
                    title: commitment.title,
                    subtitle: _commitmentSubtitle(commitment),
                    amount: commitment.remainingAmount,
                    currencyLabel: currencyLabel,
                    amountLabel: 'المتبقي',
                    onTap: () => _openCommitment(commitment),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 20),
              const AarastSectionHeader(
                title: 'حركات البند',
                icon: LucideIcons.receipt,
              ),
              const SizedBox(height: 12),
              if (movements.isEmpty)
                const _QuietEmpty(
                  message: 'لا توجد دفعات أو مصاريف مسجلة لهذا البند.',
                )
              else
                for (final movement in movements) ...[
                  _FinanceRecordTile(
                    icon: movement.icon,
                    color: movement.color,
                    title: movement.title,
                    subtitle: movement.subtitle,
                    amount: movement.amount,
                    currencyLabel: currencyLabel,
                    amountLabel: movement.amountLabel,
                    onTap: () => _openMovement(movement),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 10),
              _CategoryActionsCard(
                onEdit: () => _showEditSheet(category),
                onProviders: () => _openProviders(category),
                onDelete:
                    expenses.isEmpty && commitments.isEmpty && payments.isEmpty
                    ? () => _confirmDeleteCategory(category)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  BudgetCategory? _findCategory(List<BudgetCategory> categories) {
    for (final category in categories) {
      if (category.id == widget.budgetCategoryId) return category;
    }
    return null;
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }

  Future<void> _openCreateCommitment(BudgetCategory category) async {
    final changed = await context.push<bool>(
      AppRouter.createFinancialCommitment(widget.weddingPlanId),
      extra: category.id,
    );
    if (changed == true && mounted) {
      await context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    }
  }

  Future<void> _openExpense(Expense expense) async {
    final changed = await context.push<bool>(
      AppRouter.editExpense(widget.weddingPlanId, expense.id),
      extra: expense,
    );
    if (changed == true && mounted) {
      await context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    }
  }

  Future<void> _openCommitment(FinancialCommitment commitment) async {
    final changed = await context.push<bool>(
      AppRouter.financialCommitmentDetails(widget.weddingPlanId, commitment.id),
    );
    if (changed == true && mounted) {
      await context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    }
  }

  Future<void> _openPayment(FinancialPaymentRecord payment) async {
    final changed = await context.push<bool>(
      AppRouter.financialPaymentRecordDetails(widget.weddingPlanId, payment.id),
    );
    if (changed == true && mounted) {
      await context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    }
  }

  void _openMovement(_CategoryMovement movement) {
    final expense = movement.expense;
    if (expense != null) {
      _openExpense(expense);
      return;
    }
    final payment = movement.payment;
    if (payment != null) _openPayment(payment);
  }

  void _openProviders(BudgetCategory category) {
    context.go(
      AppRouter.planProviders(widget.weddingPlanId),
      extra: ProviderBudgetMatchIntent(
        budgetCategoryName: category.name,
        allocatedAmount: category.targetAmount,
      ),
    );
  }

  Future<void> _showEditSheet(BudgetCategory category) async {
    final nameController = TextEditingController(text: category.name);
    final amountController = TextEditingController(
      text: category.targetAmount ?? '',
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 18),
                  const AarastSectionHeader(
                    title: 'تعديل بند الميزانية',
                    icon: LucideIcons.pencil,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'اسم البند',
                      prefixIcon: Icon(LucideIcons.folder),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المخصص',
                      suffixText: _planCurrencyLabel(
                        context,
                        widget.weddingPlanId,
                      ),
                      prefixIcon: const Icon(LucideIcons.target),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AarastButton(
                    label: 'حفظ التعديل',
                    icon: LucideIcons.check,
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final amount = amountController.text.trim();
                      if (name.isEmpty) return;
                      if (amount.isNotEmpty &&
                          (num.tryParse(amount) == null ||
                              num.parse(amount) < 0)) {
                        return;
                      }
                      final financeProvider = context.read<FinanceProvider>();
                      if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
                        sheetContext,
                        weddingPlanId: widget.weddingPlanId,
                      )) {
                        return;
                      }
                      if (!sheetContext.mounted) return;
                      final ok = await financeProvider.updateBudgetCategory(
                        weddingPlanId: widget.weddingPlanId,
                        category: category,
                        name: name,
                        targetAmount: amount.isEmpty ? null : amount,
                      );
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop(ok);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    nameController.dispose();
    amountController.dispose();

    if (saved == true && mounted) {
      AarastToast.showSuccess(context, 'تم تحديث بند الميزانية');
    } else if (saved == false && mounted) {
      final error = context.read<FinanceProvider>().errorMessage;
      if (error != null) AarastToast.showError(context, error);
    }
  }

  Future<void> _confirmDeleteCategory(BudgetCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف بند الميزانية؟'),
        content: Text(
          'سيتم حذف بند ${category.name} لأنه لا يحتوي سجلات مالية.',
        ),
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
    final ok = await context.read<FinanceProvider>().deleteBudgetCategory(
      weddingPlanId: widget.weddingPlanId,
      category: category,
    );
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'تم حذف بند الميزانية');
      _goBack();
    } else {
      final error = context.read<FinanceProvider>().errorMessage;
      if (error != null) AarastToast.showError(context, error);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(LucideIcons.arrowRight),
          tooltip: 'رجوع',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.burgundyDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({
    required this.category,
    required this.summary,
    required this.currencyLabel,
  });

  final BudgetCategory category;
  final MoneyCategorySummary summary;
  final String currencyLabel;

  @override
  Widget build(BuildContext context) {
    final allocated = _moneyValue(summary.allocated);
    final spent = _moneyValue(summary.spent);
    final remaining = _moneyValue(summary.remaining);
    final progress = allocated <= 0 ? 0.0 : (spent / allocated).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  _categoryIcon(category.name),
                  color: AppTheme.gold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AarastStatusPill(
                label: '${(progress * 100).round()}%',
                color: Colors.white,
                backgroundColor: AppTheme.burgundy.withAlpha(110),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(
                label: 'المخصص',
                value: allocated,
                currencyLabel: currencyLabel,
              ),
              _HeroMetric(
                label: 'المدفوع',
                value: spent,
                currencyLabel: currencyLabel,
              ),
              _HeroMetric(
                label: 'المتبقي',
                value: remaining,
                currencyLabel: currencyLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.currencyLabel,
  });

  final String label;
  final num value;
  final String currencyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withAlpha(190),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatMoney(value)} $currencyLabel',
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryActionsCard extends StatelessWidget {
  const _CategoryActionsCard({
    required this.onEdit,
    required this.onProviders,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onProviders;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'إدارة البند',
            icon: LucideIcons.settings,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'تعديل',
                  icon: LucideIcons.pencil,
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'موردين',
                  icon: LucideIcons.store,
                  onTap: onProviders,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'حذف',
                  icon: LucideIcons.trash2,
                  onTap: onDelete,
                  muted: onDelete == null,
                  danger: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.muted = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool muted;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? AppTheme.muted
        : danger
        ? AppTheme.danger
        : AppTheme.burgundy;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(foregroundColor: color),
    );
  }
}

class _FinanceRecordTile extends StatelessWidget {
  const _FinanceRecordTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currencyLabel,
    required this.amountLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;
  final String currencyLabel;
  final String amountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: AarastCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    amountLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '${_formatMoney(_moneyValue(amount))} $currencyLabel',
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietEmpty extends StatelessWidget {
  const _QuietEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      border: Border.all(color: AppTheme.border),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _planCurrencyLabel(BuildContext context, String weddingPlanId) {
  final provider = context.watch<WeddingPlansProvider?>();
  for (final plan in provider?.plans ?? const []) {
    if (plan.id == weddingPlanId) return currencyLabelAr(plan.currency);
  }
  return currencyLabelAr(
    provider?.selectedPlan?.currency ?? provider?.activePlan?.currency,
  );
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

MoneyCategorySummary _categorySummary(
  MoneySummary moneySummary,
  BudgetCategory category,
  List<Expense> expenses,
) {
  for (final row in moneySummary.categorySummaries) {
    if (row.categoryId == category.id) return row;
  }
  final allocated = _moneyValue(category.targetAmount);
  final spent = expenses
      .where((expense) => expense.status == 'PAID')
      .fold<num>(0, (sum, expense) => sum + _moneyValue(expense.amount));
  return MoneyCategorySummary(
    categoryId: category.id,
    name: category.name,
    allocated: allocated.toString(),
    spent: spent.toString(),
    remaining: (allocated - spent).toString(),
    expensesCount: expenses.length,
    overBudget: allocated > 0 && spent > allocated,
  );
}

class _CategoryMovement {
  const _CategoryMovement._({this.expense, this.payment});

  factory _CategoryMovement.expense(Expense expense) {
    return _CategoryMovement._(expense: expense);
  }

  factory _CategoryMovement.payment(FinancialPaymentRecord payment) {
    return _CategoryMovement._(payment: payment);
  }

  final Expense? expense;
  final FinancialPaymentRecord? payment;

  DateTime get occurredAt =>
      expense?.expenseDate ?? expense?.createdAt ?? payment!.paidAt;
  String get title {
    if (expense != null) return expense!.title;
    final paymentTitle = payment!.title.trim();
    return paymentTitle.isEmpty ? 'دفعة مالية' : paymentTitle;
  }

  String get amount => expense?.amount ?? payment!.signedAmount;
  String get amountLabel =>
      expense == null ? (payment!.isReversal ? 'قيد عكس' : 'دفعة') : 'مصروف';
  IconData get icon => expense == null
      ? (payment!.isReversal ? LucideIcons.undo2 : LucideIcons.wallet)
      : LucideIcons.receipt;
  Color get color => expense == null
      ? (payment!.isReversal ? AppTheme.danger : AppTheme.success)
      : _expenseStatusColor(expense!.status);
  String get subtitle {
    if (expense != null) {
      final date = expense!.expenseDate;
      final status = _expenseStatusLabel(expense!.status);
      return date == null
          ? status
          : '$status · ${formatArabicCompactDate(date)}';
    }
    return formatArabicCompactDate(payment!.paidAt);
  }
}

List<_CategoryMovement> _categoryMovements(
  List<Expense> expenses,
  List<FinancialPaymentRecord> payments,
) {
  final movements = <_CategoryMovement>[
    ...expenses.map(_CategoryMovement.expense),
    ...payments.map(_CategoryMovement.payment),
  ];
  movements.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  return movements;
}

int _compareCommitmentDueDate(
  FinancialCommitment left,
  FinancialCommitment right,
) {
  final leftDate = left.dueDate;
  final rightDate = right.dueDate;
  if (leftDate == null && rightDate == null) return 0;
  if (leftDate == null) return 1;
  if (rightDate == null) return -1;
  return leftDate.compareTo(rightDate);
}

Color _commitmentColor(FinancialCommitment commitment) {
  if (_moneyValue(commitment.remainingAmount) <= 0) return AppTheme.success;
  if (commitment.dueDate != null &&
      commitment.dueDate!.isBefore(DateTime.now())) {
    return AppTheme.danger;
  }
  return AppTheme.gold;
}

String _commitmentSubtitle(FinancialCommitment commitment) {
  final source = commitment.isProviderLinked
      ? 'تكلفة مورد أو خدمة'
      : commitment.isManualDebt
      ? 'مستحق عليك'
      : 'مستحق مالي';
  final dueDate = commitment.dueDate;
  return dueDate == null
      ? source
      : '$source · ${formatArabicCompactDate(dueDate)}';
}

IconData _categoryIcon(String name) {
  if (name.contains('قاعة') || name.contains('صالة')) {
    return LucideIcons.building2;
  }
  if (name.contains('تصوير')) return LucideIcons.camera;
  if (name.contains('ضيافة') ||
      name.contains('غداء') ||
      name.contains('عشاء') ||
      name.contains('ماء')) {
    return LucideIcons.bell;
  }
  if (name.contains('لبس') ||
      name.contains('ملابس') ||
      name.contains('أزياء')) {
    return LucideIcons.shirt;
  }
  return LucideIcons.shapes;
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
