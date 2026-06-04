import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/debt.dart';
import '../providers/debt_installment_provider.dart';
import '../widgets/debt_card.dart';
import '../widgets/debt_summary_card.dart';
import '../widgets/due_installments_card.dart';

class DebtInstallmentScreen extends StatefulWidget {
  const DebtInstallmentScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<DebtInstallmentScreen> createState() => _DebtInstallmentScreenState();
}

class _DebtInstallmentScreenState extends State<DebtInstallmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtInstallmentProvider>().loadDebts(widget.weddingPlanId);
    });
  }

  @override
  void didUpdateWidget(covariant DebtInstallmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DebtInstallmentProvider>().loadDebts(widget.weddingPlanId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('الديون والأقساط')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadDebts(widget.weddingPlanId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _DebtInstallmentContent(
              provider: provider,
              weddingPlanId: widget.weddingPlanId,
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtInstallmentContent extends StatelessWidget {
  const _DebtInstallmentContent({
    required this.provider,
    required this.weddingPlanId,
  });

  final DebtInstallmentProvider provider;
  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.debts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.debts.isEmpty) {
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
            onPressed: () => provider.loadDebts(weddingPlanId),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    return ListView(
      children: [
        DebtSummaryCard(summary: provider.summary),
        const SizedBox(height: 12),
        DueInstallmentsCard(installments: provider.dueInstallments),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => context.go(AppRouter.createDebt(weddingPlanId)),
          icon: const Icon(Icons.add),
          label: const Text('إضافة دين'),
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
        _DebtSectionTitle(isEmpty: provider.debts.isEmpty),
        for (final debt in provider.debts)
          DebtCard(
            debt: debt,
            onTap: () => _openDebtDetails(context, provider, debt),
          ),
      ],
    );
  }

  void _openDebtDetails(
    BuildContext context,
    DebtInstallmentProvider provider,
    Debt debt,
  ) {
    provider.selectDebt(debt);
    context.go(AppRouter.debtDetails(debt.id));
  }
}

class _DebtSectionTitle extends StatelessWidget {
  const _DebtSectionTitle({required this.isEmpty});

  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'قائمة الديون',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepBurgundy,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          if (isEmpty) ...[
            const SizedBox(height: 8),
            const Text('لا توجد ديون بعد.', textAlign: TextAlign.right),
          ],
        ],
      ),
    );
  }
}
