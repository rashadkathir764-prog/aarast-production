import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../sharing/models/shared_member.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_overview/finance_overview_components.dart';
import '../widgets/finance_overview/finance_overview_content.dart';

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
    final canManageFinancialRecords =
        provider.loadedWeddingPlanId == widget.weddingPlanId &&
        provider.canManageFinancialRecords;
    final hasAnyFinanceAccess =
        provider.loadedWeddingPlanId != widget.weddingPlanId ||
        provider.isLoading ||
        provider.access.hasAnyFinanceAccess;

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
                  child: FinanceOverviewHeader(
                    statusColor: statusColor,
                    statusLabel: statusLabel,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.burgundy,
                    onRefresh: _loadFinance,
                    child: hasAnyFinanceAccess
                        ? FinanceOverviewContent(
                            provider: provider,
                            weddingPlanId: widget.weddingPlanId,
                            canManageFinancialRecords:
                                canManageFinancialRecords,
                            sharedMember: widget.sharedMember,
                            onChanged: _markExpenseChanged,
                            suppressErrors: false,
                          )
                        : const FinanceOverviewAccessDeniedState(),
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

  Future<void> _loadFinance() {
    return context.read<FinanceProvider>().loadFinance(
      widget.weddingPlanId,
      canReadBudget: _canReadBudget,
      canReadExpenses: _canReadExpenses,
      canReadFinancialRecords:
          widget.sharedMember == null ||
          widget.sharedMember!.canReadFinancialRecords,
      canManageFinancialRecords: _canManageFinancialRecords,
    );
  }

  Color _financeStatusColor(String status) {
    if (status == 'OVER_BUDGET' || status == 'DANGER') {
      return AppTheme.danger;
    }
    if (status == 'WARNING') return AppTheme.warning;
    if (status == 'NO_BUDGET') return AppTheme.muted;
    return AppTheme.success;
  }

  String _financeStatusLabel(String status) {
    if (status == 'OVER_BUDGET' || status == 'DANGER') {
      return 'تجاوز الميزانية';
    }
    if (status == 'WARNING') return 'قريب من الحد';
    if (status == 'NO_BUDGET') return 'الميزانية غير محددة';
    return 'ضمن الميزانية';
  }
}
