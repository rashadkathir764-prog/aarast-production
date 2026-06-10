import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/debt.dart';
import '../providers/debt_installment_provider.dart';
import '../widgets/debt_card.dart';
import '../widgets/installment_card.dart';

class DebtDetailsScreen extends StatefulWidget {
  const DebtDetailsScreen({required this.debtId, super.key});

  final String debtId;

  @override
  State<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends State<DebtDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtInstallmentProvider>().loadDebtDetails(widget.debtId);
    });
  }

  @override
  void didUpdateWidget(covariant DebtDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debtId != widget.debtId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DebtInstallmentProvider>().loadDebtDetails(widget.debtId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();
    final debt = provider.selectedDebt;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الدين')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadDebtDetails(widget.debtId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _DebtDetailsContent(
              provider: provider,
              debtId: widget.debtId,
              debt: debt,
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtDetailsContent extends StatelessWidget {
  const _DebtDetailsContent({
    required this.provider,
    required this.debtId,
    required this.debt,
  });

  final DebtInstallmentProvider provider;
  final String debtId;
  final Debt? debt;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.installments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        if (debt != null)
          DebtCard(debt: debt!, onTap: () {})
        else
          const _MissingDebtContextCard(),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => context.push(AppRouter.createInstallment(debtId)),
          icon: const Icon(Icons.add),
          label: const Text('إضافة قسط'),
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
        Text(
          'الأقساط',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.deepBurgundy,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 8),
        if (provider.installments.isEmpty)
          const Text(
            'لا توجد أقساط لهذا الدين بعد.',
            textAlign: TextAlign.right,
          )
        else
          for (final installment in provider.installments)
            InstallmentCard(installment: installment),
      ],
    );
  }
}

class _MissingDebtContextCard extends StatelessWidget {
  const _MissingDebtContextCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'تم فتح تفاصيل الدين مباشرة. يمكن عرض الأقساط، ولرؤية بيانات الدين كاملة افتح الدين من قائمة الديون.',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
