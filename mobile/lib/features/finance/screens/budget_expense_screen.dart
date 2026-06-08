import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../widgets/budget_category_card.dart';
import '../widgets/expense_item_card.dart';
import '../widgets/expense_summary_card.dart';

class BudgetExpenseScreen extends StatefulWidget {
  const BudgetExpenseScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<BudgetExpenseScreen> createState() => _BudgetExpenseScreenState();
}

class _BudgetExpenseScreenState extends State<BudgetExpenseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  void didUpdateWidget(covariant BudgetExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('الميزانية والمصاريف')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadFinance(widget.weddingPlanId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _FinanceContent(
              provider: provider,
              weddingPlanId: widget.weddingPlanId,
            ),
          ),
        ),
      ),
    );
  }
}

class _FinanceContent extends StatelessWidget {
  const _FinanceContent({required this.provider, required this.weddingPlanId});

  final FinanceProvider provider;
  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading &&
        provider.budgetCategories.isEmpty &&
        provider.expenses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null &&
        provider.budgetCategories.isEmpty &&
        provider.expenses.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadFinance(weddingPlanId),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    return ListView(
      children: [
        ExpenseSummaryCard(summary: provider.summary),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRouter.createBudgetCategory(weddingPlanId)),
                icon: const Icon(Icons.add),
                label: const Text('تصنيف جديد'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push(AppRouter.createExpense(weddingPlanId)),
                icon: const Icon(Icons.add),
                label: const Text('مصروف جديد'),
              ),
            ),
          ],
        ),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            provider.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.right,
          ),
        ],
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'تصنيفات الميزانية',
          emptyMessage: provider.budgetCategories.isEmpty
              ? 'لا توجد تصنيفات بعد.'
              : null,
        ),
        for (final category in provider.budgetCategories)
          BudgetCategoryCard(category: category),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'المصاريف',
          emptyMessage: provider.expenses.isEmpty
              ? 'لا توجد مصاريف بعد.'
              : null,
        ),
        for (final expense in provider.expenses)
          ExpenseItemCard(
            expense: expense,
            budgetCategories: provider.budgetCategories,
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.emptyMessage});

  final String title;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepBurgundy,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          if (emptyMessage != null) ...[
            const SizedBox(height: 8),
            Text(emptyMessage!, textAlign: TextAlign.right),
          ],
        ],
      ),
    );
  }
}
