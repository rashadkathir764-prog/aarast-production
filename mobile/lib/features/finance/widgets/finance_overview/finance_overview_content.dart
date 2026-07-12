import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/aarast_toast.dart';
import '../../../../core/widgets/aarast_ui.dart';
import '../../../sharing/models/shared_member.dart';
import '../../models/budget_category.dart';
import '../../models/expense.dart';
import '../../models/financial_commitment.dart';
import '../../models/money_summary.dart';
import '../../providers/finance_provider.dart';
import '../premium/budget_pulse_hero.dart';
import 'budget_categories_section.dart';
import 'expense_delete_confirmation_sheet.dart';
import 'finance_overview_components.dart';
import 'finance_overview_mapper.dart';
import 'financial_payables_section.dart';
import 'recent_money_activity_section.dart';

class FinanceOverviewContent extends StatelessWidget {
  const FinanceOverviewContent({
    required this.provider,
    required this.weddingPlanId,
    required this.canManageFinancialRecords,
    required this.sharedMember,
    required this.onChanged,
    this.suppressErrors = false,
    super.key,
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
      return const FinanceOverviewLoadingState();
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
            icon: LucideIcons.alertCircle,
            action: ElevatedButton.icon(
              onPressed: () => provider.loadFinance(weddingPlanId),
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final categoryRows = moneySummary.categorySummaries.isNotEmpty
        ? moneySummary.categorySummaries
        : buildFallbackMoneyCategorySummaries(
            categories: budgetCategories,
            expenses: expenses,
          );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 124),
      children: [
        if (!suppressErrors && provider.errorMessage != null) ...[
          FinanceOverviewInlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        BudgetPulseHero(
          summary: moneySummary,
          onSetupBudget: canManageFinancialRecords
              ? () => context.push(AppRouter.budgetSetup(weddingPlanId))
              : null,
        ),
        const SizedBox(height: 14),
        FinancialPayablesSection(
          summary: moneySummary,
          currencyCode: moneySummary.currency,
          commitments: commitments,
          installments: dueFinancialInstallments,
          onOpenPayables: () => _openPayables(context),
          onOpenCommitment: (commitmentId) =>
              _openCommitmentDetails(context, commitmentId),
        ),
        const SizedBox(height: 22),
        if (moneySummary.financialWarnings.isNotEmpty) ...[
          FinancialWarningsCard(warnings: moneySummary.financialWarnings),
          const SizedBox(height: 18),
        ],
        BudgetCategoriesSection(
          weddingPlanId: weddingPlanId,
          categoryRows: categoryRows,
          canManageFinancialRecords: canManageFinancialRecords,
          currencyCode: moneySummary.currency,
        ),
        const SizedBox(height: 18),
        RecentMoneyActivitySection(
          expenses: expenses,
          payments: payments,
          budgetCategories: budgetCategories,
          isBusy: provider.isSubmitting,
          canManageFinancialRecords: canManageFinancialRecords,
          currencyCode: moneySummary.currency,
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

    final confirmed = await showExpenseDeleteConfirmation(
      context: context,
      expense: expense,
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
