import 'package:flutter/material.dart';

import '../../finance/models/money_flow_readiness.dart';

class UserRebuildMoneyTab extends StatelessWidget {
  const UserRebuildMoneyTab({
    super.key,
    this.readiness = const MoneyFlowReadiness.empty(),
    this.currentPlanId,
    this.canAccessFinance = true,
  });

  final MoneyFlowReadiness readiness;
  final String? currentPlanId;
  final bool canAccessFinance;

  static const noPlanMessage =
      'تبويب المال الداخلي — يحتاج خطة حالية قبل عرض الميزانية والمصروفات';

  static const noPermissionMessage =
      'صلاحية المال غير مفعلة في هذا العرض الداخلي';

  @override
  Widget build(BuildContext context) {
    final effectiveReadiness = _effectiveReadiness;
    final statusMetrics = _statusMetrics(effectiveReadiness);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'المال',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هدف تبويب المال هو جمع الميزانية والمصروفات والديون والأقساط في مكان واحد لاحقاً.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _MoneyCapabilityGrid(),
                const SizedBox(height: 20),
                _MoneyStateNotice(message: _messageFor(effectiveReadiness)),
                if (statusMetrics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: statusMetrics
                        .map((metric) => _MoneyCapabilityChip(metric))
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  MoneyFlowReadiness get _effectiveReadiness {
    final planId = currentPlanId?.trim();
    if (planId != null && planId.isNotEmpty) {
      return MoneyFlowReadiness(
        currentPlanId: planId,
        canReadBudget: canAccessFinance,
        canReadExpenses: canAccessFinance,
        canReadDebts: canAccessFinance,
        canManageFinancialRecords: canAccessFinance,
      );
    }
    return readiness;
  }

  String _messageFor(MoneyFlowReadiness readiness) {
    return switch (readiness.state) {
      MoneyFlowReadinessState.missingCurrentPlan => noPlanMessage,
      MoneyFlowReadinessState.missingPermission => noPermissionMessage,
      MoneyFlowReadinessState.waitingForSources =>
        'تبويب المال الداخلي ينتظر مصادر الميزانية والمصروفات والديون',
      MoneyFlowReadinessState.ready =>
        'تبويب المال الداخلي جاهز بمصادر مالية حقيقية',
      MoneyFlowReadinessState.offlinePendingSync =>
        'تبويب المال الداخلي جاهز مع تغييرات بانتظار المزامنة',
      MoneyFlowReadinessState.loading => 'تبويب المال الداخلي قيد التحميل',
      MoneyFlowReadinessState.blockedByError =>
        readiness.errorMessage?.trim().isNotEmpty == true
            ? readiness.errorMessage!.trim()
            : 'تعذر تجهيز تبويب المال الداخلي',
    };
  }

  List<String> _statusMetrics(MoneyFlowReadiness readiness) {
    final metrics = <String>[];
    if (readiness.estimatedBudgetLabel != null) {
      metrics.add(readiness.estimatedBudgetLabel!);
    }
    if (readiness.totalPaidLabel != null) {
      metrics.add('مدفوع: ${readiness.totalPaidLabel}');
    }
    if (readiness.remainingDebtLabel != null) {
      metrics.add('ديون متبقية: ${readiness.remainingDebtLabel}');
    }
    if (readiness.dueInstallmentCount != null) {
      metrics.add('${readiness.dueInstallmentCount} أقساط مستحقة');
    }
    if (readiness.pendingSyncCount != null) {
      metrics.add('${readiness.pendingSyncCount} عمليات بانتظار المزامنة');
    }
    return metrics;
  }
}

class _MoneyCapabilityGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['الميزانية', 'المصروفات', 'الديون', 'الأقساط'];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: labels.map((label) => _MoneyCapabilityChip(label)).toList(),
    );
  }
}

class _MoneyCapabilityChip extends StatelessWidget {
  const _MoneyCapabilityChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MoneyStateNotice extends StatelessWidget {
  const _MoneyStateNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
