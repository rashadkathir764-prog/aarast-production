import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../sharing/models/shared_member.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/financial_commitment.dart';
import '../models/money_summary.dart';
import '../providers/finance_provider.dart';
import '../widgets/premium/budget_pulse_hero.dart';
import '../widgets/premium/budget_category_card.dart';

class BudgetExpenseScreen extends StatefulWidget {
  const BudgetExpenseScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final bool embedded;

  @override
  State<BudgetExpenseScreen> createState() => _BudgetExpenseScreenState();
}

class _BudgetExpenseScreenState extends State<BudgetExpenseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadFinance();
    });
  }

  @override
  void didUpdateWidget(covariant BudgetExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadFinance();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final canManageFinancialRecords = _canManageFinancialRecords;

    final status = provider.moneySummary.budgetStatus;
    final statusColor = _financeStatusColor(status);
    final statusLabel = _financeStatusLabel(status);

    return AarastScreenFrame(
      maxWidth: 520,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppTheme.ivory),
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: _FinanceHeader(
                    statusColor: statusColor,
                    statusLabel: statusLabel,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.burgundy,
                    onRefresh: _loadFinance,
                    child: _hasAnyFinanceAccess
                        ? _FinanceContent(
                            provider: provider,
                            weddingPlanId: widget.weddingPlanId,
                            canManageFinancialRecords:
                                canManageFinancialRecords,
                            sharedMember: widget.sharedMember,
                            onChanged: _markExpenseChanged,
                            suppressErrors: false,
                          )
                        : const _FinancialAccessDeniedState(),
                  ),
                ),
              ],
            ),

            // Smart FAB handles addition now
          ],
        ),
      ),
    );
  }

  void _markExpenseChanged() {
    unawaited(_refreshDashboardSummary());
  }

  Future<void> _refreshDashboardSummary() async {
    try {
      await context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
      );
    } on ProviderNotFoundException {
      return;
    }
  }

  bool get _canReadBudget =>
      widget.sharedMember == null || widget.sharedMember!.canReadBudget;

  bool get _canReadExpenses =>
      widget.sharedMember == null || widget.sharedMember!.canReadExpenses;

  bool get _canManageFinancialRecords =>
      widget.sharedMember == null ||
      widget.sharedMember!.canManageFinancialRecords;

  bool get _hasAnyFinanceAccess =>
      widget.sharedMember == null || widget.sharedMember!.hasFinancialAccess;

  Future<void> _loadFinance() {
    if (!_hasAnyFinanceAccess) {
      return Future<void>.value();
    }

    return context.read<FinanceProvider>().loadFinance(
      widget.weddingPlanId,
      canReadBudget: _canReadBudget,
      canReadExpenses: _canReadExpenses,
    );
  }

  Color _financeStatusColor(String status) {
    if (status == 'OVER_BUDGET' || status == 'DANGER') {
      return AppTheme.danger;
    }
    if (status == 'WARNING') return AppTheme.warning;
    return AppTheme.success;
  }

  String _financeStatusLabel(String status) {
    if (status == 'OVER_BUDGET' || status == 'DANGER') {
      return 'تجاوز الميزانية';
    }
    if (status == 'WARNING') return 'قريب من الحد';
    return 'ضمن الميزانية';
  }
}

class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader({required this.statusColor, required this.statusLabel});

  final Color statusColor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    // ترويسة مضغوطة: عنوان + شارة حالة في سطر واحد. لا فقرة تطمين مكررة.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'المال',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: AppTheme.title),
          ),
        ),
        const SizedBox(width: 10),
        AarastStatusPill(
          label: statusLabel,
          color: statusColor,
          icon: Icons.verified_outlined,
        ),
      ],
    );
  }
}

class _FinanceContent extends StatelessWidget {
  const _FinanceContent({
    required this.provider,
    required this.weddingPlanId,
    required this.canManageFinancialRecords,
    required this.sharedMember,
    required this.onChanged,
    this.suppressErrors = false,
  });

  final FinanceProvider provider;
  final String weddingPlanId;
  final bool canManageFinancialRecords;
  final SharedMember? sharedMember;
  final VoidCallback onChanged;
  final bool suppressErrors;

  @override
  Widget build(BuildContext context) {
    final budgetCategories = suppressErrors
        ? const <BudgetCategory>[]
        : provider.budgetCategories;
    final expenses = suppressErrors ? const <Expense>[] : provider.expenses;
    final commitments = suppressErrors
        ? const <FinancialCommitment>[]
        : provider.financialCommitments;
    final payments = suppressErrors
        ? const <FinancialPaymentRecord>[]
        : provider.financialPaymentRecords;
    final dueFinancialInstallments = suppressErrors
        ? const <FinancialInstallment>[]
        : provider.dueFinancialInstallments;
    final moneySummary = suppressErrors
        ? MoneySummary.empty(weddingPlanId)
        : provider.moneySummary;

    if (!suppressErrors &&
        provider.isLoading &&
        budgetCategories.isEmpty &&
        expenses.isEmpty &&
        commitments.isEmpty &&
        !moneySummary.hasAnyData) {
      return const _FinanceLoadingState();
    }

    if (!suppressErrors &&
        provider.errorMessage != null &&
        budgetCategories.isEmpty &&
        expenses.isEmpty &&
        commitments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
        children: [
          AarastEmptyState(
            title: 'تعذر تحميل الميزانية',
            message: provider.errorMessage!,
            icon: Icons.error_outline_rounded,
            action: ElevatedButton.icon(
              onPressed: () => provider.loadFinance(weddingPlanId),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final categoryRows = moneySummary.categorySummaries.isNotEmpty
        ? moneySummary.categorySummaries
        : _buildCategoryRows(budgetCategories, expenses)
              .map(
                (row) => MoneyCategorySummary(
                  categoryId: row.id,
                  name: row.name,
                  allocated: row.target.toString(),
                  spent: row.spent.toString(),
                  remaining: (row.target - row.spent).toString(),
                  expensesCount: row.expensesCount,
                  overBudget: row.target > 0 && row.spent > row.target,
                ),
              )
              .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 124),
      children: [
        if (!suppressErrors && provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        BudgetPulseHero(
          summary: moneySummary,
          onSetupBudget: canManageFinancialRecords
              ? () => context.push(AppRouter.budgetSetup(weddingPlanId))
              : null,
        ),
        const SizedBox(height: 14),
        _FinancialPayablesSection(
          summary: moneySummary,
          commitments: commitments,
          installments: dueFinancialInstallments,
          onOpenDebts: () => _openDebts(context),
          onOpenPayables: () => _openPayables(context),
          onOpenCommitment: (commitmentId) =>
              _openCommitmentDetails(context, commitmentId),
        ),
        const SizedBox(height: 22),
        if (moneySummary.financialWarnings.isNotEmpty) ...[
          _FinancialWarningsCard(warnings: moneySummary.financialWarnings),
          const SizedBox(height: 18),
        ],
        _BudgetCategoriesSection(
          weddingPlanId: weddingPlanId,
          categoryRows: categoryRows,
          canManageFinancialRecords: canManageFinancialRecords,
        ),
        const SizedBox(height: 18),
        _RecentMoneyActivitySection(
          expenses: expenses,
          payments: payments,
          budgetCategories: budgetCategories,
          isBusy: provider.isSubmitting,
          onViewAllExpenses: expenses.isNotEmpty
              ? () => context.push(AppRouter.expenses(weddingPlanId))
              : null,
          onEditExpense: (expense) => _openEditExpense(context, expense),
          onOpenPayment: (payment) => _openPaymentDetails(context, payment),
          onDeleteExpense: (expense) =>
              _confirmDeleteExpense(context, provider, expense),
        ),
      ],
    );
  }

  Future<void> _openDebts(BuildContext context) async {
    await context.push(AppRouter.debts(weddingPlanId), extra: sharedMember);
    if (!context.mounted) return;
    onChanged();
    await provider.loadFinance(weddingPlanId);
  }

  Future<void> _openPayables(BuildContext context) async {
    final changed = await context.push<bool>(
      AppRouter.financialPayables(weddingPlanId),
      extra: sharedMember,
    );
    if (changed == true && context.mounted) {
      onChanged();
      await provider.loadFinance(weddingPlanId);
    }
  }

  Future<void> _openCommitmentDetails(
    BuildContext context,
    String commitmentId,
  ) async {
    final changed = await context.push<bool>(
      AppRouter.financialCommitmentDetails(weddingPlanId, commitmentId),
    );
    if (changed == true && context.mounted) {
      onChanged();
      await provider.loadFinance(weddingPlanId);
    }
  }

  Future<void> _openPaymentDetails(
    BuildContext context,
    FinancialPaymentRecord payment,
  ) async {
    final changed = await context.push<bool>(
      AppRouter.financialPaymentRecordDetails(weddingPlanId, payment.id),
    );
    if (changed == true && context.mounted) {
      onChanged();
      await provider.loadFinance(weddingPlanId);
    }
  }

  Future<void> _openEditExpense(BuildContext context, Expense expense) async {
    if (expense.id.startsWith('local-')) {
      AarastToast.showInfo(
        context,
        'هذا المصروف محفوظ على هذا الجهاز وقيد المزامنة. انتظر اكتمال المزامنة قبل تعديله.',
      );
      return;
    }

    final changed = await context.push<bool>(
      AppRouter.editExpense(weddingPlanId, expense.id),
      extra: expense,
    );
    if (changed == true && context.mounted) onChanged();
  }

  Future<void> _confirmDeleteExpense(
    BuildContext context,
    FinanceProvider provider,
    Expense expense,
  ) async {
    if (expense.id.startsWith('local-')) {
      AarastToast.showInfo(
        context,
        'هذا المصروف محفوظ على هذا الجهاز وقيد المزامنة. انتظر اكتمال المزامنة قبل حذفه.',
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حذف المصروف؟',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم حذف "${expense.title}" من المصاريف. لا يمكن التراجع عن هذا الإجراء.',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('حذف'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final deleted = await provider.deleteExpense(
      weddingPlanId: weddingPlanId,
      expense: expense,
    );
    if (!context.mounted) return;

    final message = deleted
        ? 'تم حذف المصروف بنجاح'
        : provider.errorMessage ?? 'تعذر حذف المصروف.';
    if (deleted) {
      onChanged();
      AarastToast.showSuccess(context, message);
    } else {
      AarastToast.showError(context, message);
    }
  }
}

class _FinancialWarningsCard extends StatelessWidget {
  const _FinancialWarningsCard({required this.warnings});

  final List<MoneyFinancialWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.dangerSoft,
      border: Border.all(color: AppTheme.danger.withAlpha(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AarastSectionHeader(
            title: 'تنبيهات مالية',
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 10),
          for (final warning in warnings.take(4)) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: warning.severity == 'DANGER'
                      ? AppTheme.danger
                      : AppTheme.gold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _warningCopy(warning),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _BudgetStarterCard extends StatelessWidget {
  const _BudgetStarterCard({
    required this.canManageFinancialRecords,
    required this.onSetupBudget,
    required this.onCreateCategory,
  });

  final bool canManageFinancialRecords;
  final VoidCallback onSetupBudget;
  final ValueChanged<String> onCreateCategory;

  static const _suggestions = [
    'الصالة',
    'الغداء',
    'العشاء',
    'التصوير',
    'الكوشة',
    'الأزياء',
    'الفنان',
    'الماء والضيافة',
  ];

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.playlist_add_check_rounded,
                color: AppTheme.burgundy,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ابدأ ببنود الزفاف الأساسية',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            canManageFinancialRecords
                ? 'اختر بنداً، ثم حدد المبلغ المخصص له أو اتركه فارغاً.'
                : 'لا توجد بنود ميزانية بعد.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (canManageFinancialRecords) ...[
            const SizedBox(height: 14),
            AarastButton(
              label: 'إعداد الميزانية',
              icon: Icons.tune_rounded,
              onPressed: onSetupBudget,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    avatar: Icon(_categoryIcon(suggestion), size: 17),
                    label: Text(suggestion),
                    onPressed: () => onCreateCategory(suggestion),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialPayablesSection extends StatelessWidget {
  const _FinancialPayablesSection({
    required this.summary,
    required this.commitments,
    required this.installments,
    required this.onOpenDebts,
    required this.onOpenPayables,
    required this.onOpenCommitment,
  });

  final MoneySummary summary;
  final List<FinancialCommitment> commitments;
  final List<FinancialInstallment> installments;
  final VoidCallback onOpenDebts;
  final VoidCallback onOpenPayables;
  final ValueChanged<String> onOpenCommitment;

  @override
  Widget build(BuildContext context) {
    final active = commitments
        .where((commitment) => !commitment.isCancelled)
        .toList();
    final openPayables = active
        .where((commitment) => _moneyValue(commitment.remainingAmount) > 0)
        .take(3)
        .toList();
    final dueInstallments = installments
        .where((installment) => !installment.isPaid)
        .take(3)
        .toList();
    final totalRemaining = active.fold<num>(
      0,
      (sum, commitment) => sum + _moneyValue(commitment.remainingAmount),
    );
    final commitmentTitles = {
      for (final commitment in active) commitment.id: commitment.title,
    };
    final hasContent = openPayables.isNotEmpty || dueInstallments.isNotEmpty;

    return _FinanceSectionCard(
      title: 'الدفعات والمستحقات',
      icon: Icons.account_balance_wallet_outlined,
      onTap: onOpenPayables,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PayablesSummaryRow(
            remaining: totalRemaining,
            payablesCount: openPayables.length,
            installmentsCount: dueInstallments.length,
          ),
          const SizedBox(height: 12),
          if (!hasContent)
            const _TinyEmptyText(
              message: 'لا توجد مستحقات أو أقساط قريبة الآن.',
            )
          else ...[
            if (openPayables.isNotEmpty) ...[
              const _FinanceSubhead(label: 'مستحقات عليك'),
              const SizedBox(height: 8),
              for (var index = 0; index < openPayables.length; index++) ...[
                _CommitmentTile(
                  commitment: openPayables[index],
                  onTap: () => onOpenCommitment(openPayables[index].id),
                ),
                if (index != openPayables.length - 1)
                  Divider(
                    height: 18,
                    color: AppTheme.border.withValues(alpha: .65),
                  ),
              ],
            ],
            if (openPayables.isNotEmpty && dueInstallments.isNotEmpty)
              Divider(
                height: 22,
                color: AppTheme.border.withValues(alpha: .65),
              ),
            if (dueInstallments.isNotEmpty) ...[
              const _FinanceSubhead(label: 'أقساط قريبة'),
              const SizedBox(height: 8),
              for (var index = 0; index < dueInstallments.length; index++) ...[
                _TapInlineTile(
                  onTap: () => onOpenCommitment(
                    dueInstallments[index].financialCommitmentId,
                  ),
                  child: _MoneyEventTile(
                    title:
                        commitmentTitles[dueInstallments[index]
                            .financialCommitmentId] ??
                        'قسط مالي',
                    subtitle: dueInstallments[index].dueDate == null
                        ? 'بدون تاريخ'
                        : _shortDate(dueInstallments[index].dueDate!),
                    amount: dueInstallments[index].amount,
                    icon: Icons.event_available_outlined,
                    color: AppTheme.gold,
                  ),
                ),
                if (index != dueInstallments.length - 1)
                  Divider(
                    height: 18,
                    color: AppTheme.border.withValues(alpha: .65),
                  ),
              ],
            ],
          ],
          if (summary.hasLegacyDebtData) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onOpenDebts,
                icon: const Icon(Icons.history_rounded, size: 17),
                label: const Text('عرض سجل الديون القديم'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayablesSummaryRow extends StatelessWidget {
  const _PayablesSummaryRow({
    required this.remaining,
    required this.payablesCount,
    required this.installmentsCount,
  });

  final num remaining;
  final int payablesCount;
  final int installmentsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: AppTheme.burgundy,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              payablesCount == 0 && installmentsCount == 0
                  ? 'لا يوجد شيء مستحق عليك الآن'
                  : '$payablesCount مستحق · $installmentsCount قسط قريب',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'باقي ${_formatMoney(remaining)}',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: remaining <= 0 ? AppTheme.success : AppTheme.danger,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSubhead extends StatelessWidget {
  const _FinanceSubhead({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.muted,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _BudgetCategoriesSection extends StatefulWidget {
  const _BudgetCategoriesSection({
    required this.weddingPlanId,
    required this.categoryRows,
    required this.canManageFinancialRecords,
  });

  final String weddingPlanId;
  final List<MoneyCategorySummary> categoryRows;
  final bool canManageFinancialRecords;

  @override
  State<_BudgetCategoriesSection> createState() =>
      _BudgetCategoriesSectionState();
}

class _BudgetCategoriesSectionState extends State<_BudgetCategoriesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.categoryRows;
    final hasMore = rows.length > 3;
    final visibleRows = _expanded || !hasMore ? rows : rows.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'بنود الزفاف والميزانية',
          icon: Icons.pie_chart_outline_rounded,
          actionLabel: hasMore ? (_expanded ? 'إخفاء' : 'عرض الكل') : null,
          onAction: hasMore
              ? () => setState(() => _expanded = !_expanded)
              : null,
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _BudgetStarterCard(
            canManageFinancialRecords: widget.canManageFinancialRecords,
            onSetupBudget: () =>
                context.push(AppRouter.budgetSetup(widget.weddingPlanId)),
            onCreateCategory: (name) => context.push(
              AppRouter.createBudgetCategory(widget.weddingPlanId),
              extra: name,
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < visibleRows.length; index++) ...[
                staggeredBudgetCard(
                  BudgetCategoryCard(
                    row: visibleRows[index],
                    onOpenDetails: () => context.push(
                      AppRouter.budgetCategoryDetails(
                        widget.weddingPlanId,
                        visibleRows[index].categoryId,
                      ),
                    ),
                  ),
                  index,
                  MediaQuery.of(context).disableAnimations,
                ),
                if (index != visibleRows.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}

class _RecentMoneyActivitySection extends StatelessWidget {
  const _RecentMoneyActivitySection({
    required this.expenses,
    required this.payments,
    required this.budgetCategories,
    required this.isBusy,
    required this.onEditExpense,
    required this.onOpenPayment,
    required this.onDeleteExpense,
    this.onViewAllExpenses,
  });

  final List<Expense> expenses;
  final List<FinancialPaymentRecord> payments;
  final List<BudgetCategory> budgetCategories;
  final bool isBusy;
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
          icon: Icons.schedule_rounded,
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
                    categoryName: _categoryName(
                      budgetCategories,
                      expense.budgetCategoryId,
                    ),
                    isBusy: isBusy,
                    onTap: () => onEditExpense(expense),
                    onEdit: () => onEditExpense(expense),
                    onDelete: () => onDeleteExpense(expense),
                  );
                }
                return _TapInlineTile(
                  onTap: () {
                    final payment = event.payment;
                    if (payment != null) onOpenPayment(payment);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _MoneyEventTile(
                      title: event.title,
                      subtitle: event.subtitle,
                      amount: event.amount,
                      icon: event.icon,
                      color: event.color,
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
  String get amount => expense?.amount ?? payment!.amount;
  IconData get icon =>
      expense == null ? Icons.payments_outlined : Icons.receipt_long_outlined;
  Color get color =>
      expense == null ? AppTheme.success : _expenseStatusColor(expense!.status);
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

class _FinanceSectionCard extends StatelessWidget {
  const _FinanceSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AarastCard(
      padding: EdgeInsets.zero,
      border: Border.all(color: AppTheme.border),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.burgundy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: content,
      ),
    );
  }
}

class _TapInlineTile extends StatelessWidget {
  const _TapInlineTile({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({required this.commitment, required this.onTap});

  final FinancialCommitment commitment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = _moneyValue(commitment.remainingAmount);
    final statusColor = switch (commitment.status) {
      'PAID' => AppTheme.success,
      'CANCELLED' => AppTheme.muted,
      _ => AppTheme.gold,
    };
    final sourceLabel = commitment.isProviderLinked
        ? 'مورد / خدمة'
        : commitment.isManualDebt
        ? 'مستحق عليك'
        : 'مستحق مالي';
    final party = commitment.partyName?.trim();

    return _TapInlineTile(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(Icons.account_balance_outlined, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commitment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AarastStatusPill(label: sourceLabel, color: statusColor),
                    if (party != null && party.isNotEmpty)
                      AarastStatusPill(
                        label: party,
                        color: AppTheme.muted,
                        icon: Icons.person_outline_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMoney(_moneyValue(commitment.totalAmount)),
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'باقي ${_formatMoney(remaining)}',
                style: TextStyle(
                  color: remaining <= 0 ? AppTheme.success : AppTheme.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyEventTile extends StatelessWidget {
  const _MoneyEventTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _formatMoney(_moneyValue(amount)),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _TinyEmptyText extends StatelessWidget {
  const _TinyEmptyText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppTheme.muted,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.categoryName,
    required this.isBusy,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final String categoryName;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = _expenseStatusColor(expense.status);
    final isPaid = expense.status == 'PAID';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                isPaid
                    ? Icons.receipt_long_rounded
                    : Icons.pending_actions_rounded,
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
                        icon: Icons.folder_outlined,
                      ),
                      if (expense.expenseDate != null)
                        AarastStatusPill(
                          label: _shortDate(expense.expenseDate!),
                          color: AppTheme.muted,
                          icon: Icons.calendar_month_rounded,
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
              style: const TextStyle(
                color: AppTheme.burgundy,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 2),
            PopupMenuButton<_ExpenseAction>(
              enabled: !isBusy,
              tooltip: 'خيارات المصروف',
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.muted),
              onSelected: (action) {
                if (action == _ExpenseAction.edit) {
                  onEdit();
                } else {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _ExpenseAction.edit,
                  child: _ExpenseMenuItem(
                    icon: Icons.edit_outlined,
                    label: 'تعديل',
                  ),
                ),
                const PopupMenuItem(
                  value: _ExpenseAction.delete,
                  child: _ExpenseMenuItem(
                    icon: Icons.delete_outline_rounded,
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

class _FinanceLoadingState extends StatelessWidget {
  const _FinanceLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: const [
        _SkeletonBox(height: 226),
        SizedBox(height: 20),
        _SkeletonBox(height: 78),
        SizedBox(height: 10),
        _SkeletonBox(height: 78),
        SizedBox(height: 22),
        _SkeletonBox(height: 88),
        SizedBox(height: 10),
        _SkeletonBox(height: 88),
      ],
    );
  }
}

class _FinancialAccessDeniedState extends StatelessWidget {
  const _FinancialAccessDeniedState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
      children: const [
        AarastEmptyState(
          title: 'الميزانية خاصة',
          message: 'ليست لديك صلاحية عرض التفاصيل المالية.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySpendRow {
  const _CategorySpendRow({
    required this.id,
    required this.name,
    required this.spent,
    required this.target,
    required this.progress,
    required this.expensesCount,
  });

  final String id;
  final String name;
  final num spent;
  final num target;
  final double progress;
  final int expensesCount;
}

List<_CategorySpendRow> _buildCategoryRows(
  List<BudgetCategory> categories,
  List<Expense> expenses,
) {
  final activeExpenses = expenses.where((expense) => expense.status == 'PAID');
  final totalSpent = activeExpenses.fold<num>(
    0,
    (sum, expense) => sum + _moneyValue(expense.amount),
  );

  return categories.map((category) {
    final spent = activeExpenses
        .where((expense) => expense.budgetCategoryId == category.id)
        .fold<num>(0, (sum, expense) => sum + _moneyValue(expense.amount));
    final target = _moneyValue(category.targetAmount ?? '0');
    final denominator = target > 0 ? target : totalSpent;
    final progress = denominator <= 0 ? 0.0 : spent / denominator;
    final categoryExpenses = expenses.where(
      (expense) => expense.budgetCategoryId == category.id,
    );
    return _CategorySpendRow(
      id: category.id,
      name: category.name,
      spent: spent,
      target: target,
      progress: progress.toDouble(),
      expensesCount: categoryExpenses.length,
    );
  }).toList();
}

String _categoryName(List<BudgetCategory> categories, String? id) {
  if (id == null || id.trim().isEmpty) return 'غير مصنف';
  for (final category in categories) {
    if (category.id == id) return category.name;
  }
  return 'غير مصنف';
}

IconData _categoryIcon(String name) {
  if (name.contains('قاعة')) return Icons.apartment_rounded;
  if (name.contains('تصوير')) return Icons.photo_camera_outlined;
  if (name.contains('ضيافة') || name.contains('طعام')) {
    return Icons.room_service_outlined;
  }
  if (name.contains('لبس') ||
      name.contains('ملابس') ||
      name.contains('أزياء')) {
    return Icons.checkroom_outlined;
  }
  return Icons.category_outlined;
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

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;

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

String _warningCopy(MoneyFinancialWarning warning) {
  return switch (warning.type) {
    'BUDGET_EXCEEDED' => 'ميزانيتك تجاوزت الحد',
    'CATEGORY_EXCEEDED' => 'تصنيف في الميزانية تجاوز المخصص',
    'INSTALLMENT_OVERDUE' => 'دفعة متأخرة تحتاج متابعة',
    'INSTALLMENT_DUE_SOON' => 'دفعة قادمة تحتاج متابعة',
    'EXPENSE_WITHOUT_CATEGORY' => 'مصروف بدون تصنيف يحتاج ترتيب',
    _ =>
      warning.message.trim().isEmpty
          ? 'تنبيه مالي يحتاج متابعة'
          : warning.message,
  };
}

String _shortDate(DateTime date) {
  return formatArabicCompactDate(date);
}

class _AnimatedMoneyText extends StatelessWidget {
  const _AnimatedMoneyText({required this.value, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cleaned = value.replaceAll(',', '').replaceAll(' ر.ي', '').trim();
    final targetValue = double.tryParse(cleaned) ?? 0.0;
    if (targetValue.isNaN || targetValue.isInfinite || targetValue == 0.0) {
      return Text(value, style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        final formatted = _formatMoney(val);
        return Text(formatted, style: style);
      },
    );
  }
}
