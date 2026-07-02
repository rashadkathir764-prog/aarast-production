import 'dart:math' as math;
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
import '../../marketplace/models/provider_budget_match_intent.dart';
import '../../sharing/models/shared_member.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/money_summary.dart';
import '../providers/finance_provider.dart';
import '../widgets/yemeni_money_text.dart';

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
    return AarastCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'الميزانية والمصاريف',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AarastStatusPill(
                label: statusLabel,
                color: statusColor,
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'خصوصية المال محفوظة حسب صلاحيات الخطة. راقب الميزانية والمصاريف بدون أرقام وهمية.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
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
    final moneySummary = suppressErrors
        ? MoneySummary.empty(weddingPlanId)
        : provider.moneySummary;

    if (!suppressErrors &&
        provider.isLoading &&
        budgetCategories.isEmpty &&
        expenses.isEmpty &&
        !moneySummary.hasAnyData) {
      return const _FinanceLoadingState();
    }

    if (!suppressErrors &&
        provider.errorMessage != null &&
        budgetCategories.isEmpty &&
        expenses.isEmpty) {
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
        _FinanceDonutHero(summary: moneySummary),
        const SizedBox(height: 16),
        _FinanceActionStrip(
          canManageFinancialRecords: canManageFinancialRecords,
          onAddExpense: canManageFinancialRecords
              ? () => context.push(AppRouter.createExpense(weddingPlanId))
              : null,
          onAddCategory: canManageFinancialRecords
              ? () => context.push(
                  AppRouter.createBudgetCategory(weddingPlanId),
                  extra: sharedMember,
                )
              : null,
          onViewDebts: () =>
              context.push(AppRouter.debts(weddingPlanId), extra: sharedMember),
        ),
        const SizedBox(height: 16),
        _TopFinancialObligationsCard(
          summary: moneySummary,
          onViewDebts: () => _openDebts(context),
        ),
        const SizedBox(height: 24),
        if (moneySummary.financialWarnings.isNotEmpty) ...[
          _FinancialWarningsCard(warnings: moneySummary.financialWarnings),
          const SizedBox(height: 18),
        ],
        AarastSectionHeader(
          title: 'بنود الزفاف والميزانية',
          icon: Icons.pie_chart_outline_rounded,
        ),
        const SizedBox(height: 12),
        if (categoryRows.isEmpty)
          _BudgetStarterCard(
            canManageFinancialRecords: canManageFinancialRecords,
            onSetupBudget: () =>
                context.push(AppRouter.budgetSetup(weddingPlanId)),
            onCreateCategory: (name) => context.push(
              AppRouter.createBudgetCategory(weddingPlanId),
              extra: name,
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < categoryRows.length; index++) ...[
                _MoneyCategoryProgressRow(
                  row: categoryRows[index],
                  onOpenDetails: () => context.push(
                    AppRouter.budgetCategoryDetails(
                      weddingPlanId,
                      categoryRows[index].categoryId,
                    ),
                  ),
                  onViewProviders: () =>
                      _openProvidersForCategory(context, categoryRows[index]),
                ),
                if (index != categoryRows.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        const SizedBox(height: 18),
        AarastSectionHeader(
          title: 'المدفوعات والمصاريف الأخيرة',
          icon: Icons.schedule_rounded,
          actionLabel: expenses.isNotEmpty ? 'عرض الكل' : null,
          onAction: expenses.isNotEmpty
              ? () => context.push(AppRouter.expenses(weddingPlanId))
              : null,
        ),
        const SizedBox(height: 12),
        if (expenses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'لا توجد مصاريف بعد. أضف مصروفًا عند وجود تكلفة فعلية.',
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
              itemCount: expenses.take(8).length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.ink.withValues(alpha: 0.05),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return _ExpenseRow(
                  expense: expense,
                  categoryName: _categoryName(
                    budgetCategories,
                    expense.budgetCategoryId,
                  ),
                  isBusy: provider.isSubmitting,
                  onEdit: () => _openEditExpense(context, expense),
                  onDelete: () =>
                      _confirmDeleteExpense(context, provider, expense),
                );
              },
            ),
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

  void _openProvidersForCategory(
    BuildContext context,
    MoneyCategorySummary row,
  ) {
    context.go(
      AppRouter.planProviders(weddingPlanId),
      extra: ProviderBudgetMatchIntent(
        budgetCategoryName: row.name,
        allocatedAmount: row.allocated,
      ),
    );
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

class _FinanceDonutHero extends StatelessWidget {
  const _FinanceDonutHero({required this.summary});

  final MoneySummary summary;

  double _parseValue(String? value) {
    if (value == null) return 0;
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final totalBudget = _parseValue(summary.totalBudget);
    final totalSpent = _parseValue(summary.totalSpent);
    final spentPercent = totalBudget > 0
        ? ((totalSpent / totalBudget) * 100).round()
        : 0;

    double spentRatio = totalBudget > 0 ? (totalSpent / totalBudget) : 0;
    if (spentRatio > 1) spentRatio = 1;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.burgundyDark.withValues(alpha: 0.1),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(100, 100),
                  painter: _FinanceDonutPainter(
                    spentRatio: spentRatio,
                    budgetColor: AppTheme.pearl,
                    spentColor: AppTheme.gold,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$spentPercent%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تم صرفه',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DonutStatHorizontal(
                  label: 'الميزانية',
                  value: summary.totalBudget,
                  color: AppTheme.pearl,
                ),
                Divider(
                  height: 24,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                _DonutStatHorizontal(
                  label: 'المصروف',
                  value: summary.totalSpent,
                  color: AppTheme.gold,
                ),
                Divider(
                  height: 24,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                _DonutStatHorizontal(
                  label: 'المتبقي',
                  value: summary.remainingBudget,
                  color: AppTheme.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutStatHorizontal extends StatelessWidget {
  const _DonutStatHorizontal({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        _AnimatedMoneyText(
          value: value ?? '0',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FinanceDonutPainter extends CustomPainter {
  _FinanceDonutPainter({
    required this.spentRatio,
    required this.budgetColor,
    required this.spentColor,
  });

  final double spentRatio;
  final Color budgetColor;
  final Color spentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 6;

    final trackPaint = Paint()
      ..color = budgetColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (spentRatio > 0) {
      final spentPaint = Paint()
        ..color = spentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      final shadowPaint = Paint()
        ..color = spentColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * spentRatio;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        shadowPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        spentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceDonutPainter oldDelegate) {
    return oldDelegate.spentRatio != spentRatio;
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

class _MoneyCategoryProgressRow extends StatelessWidget {
  const _MoneyCategoryProgressRow({
    required this.row,
    required this.onOpenDetails,
    required this.onViewProviders,
  });

  final MoneyCategorySummary row;
  final VoidCallback onOpenDetails;
  final VoidCallback onViewProviders;

  @override
  Widget build(BuildContext context) {
    final progress = row.percentUsed;
    final progressColor = progress >= 1
        ? AppTheme.danger
        : progress >= .75
        ? AppTheme.warning
        : AppTheme.gold;
    final spent = _moneyValueOrZero(row.spent);
    final allocated = _moneyValueOrZero(row.allocated);
    final remaining = _moneyValueOrZero(row.remaining);
    final percent = allocated > 0 ? (spent / allocated * 100).round() : 0;
    final hasBudget = allocated > 0;
    final hasSpent = spent > 0;
    final stateLabel = row.overBudget == true
        ? 'تجاوز الميزانية'
        : !hasBudget
        ? 'حدد الميزانية'
        : !hasSpent
        ? 'لم يسجل مصروف'
        : remaining <= 0
        ? 'لا يوجد متبقي'
        : 'متبقي ${_formatMoney(remaining)} ر.ي';
    final stateColor = row.overBudget == true
        ? AppTheme.danger
        : !hasBudget
        ? AppTheme.muted
        : remaining <= 0
        ? AppTheme.success
        : AppTheme.burgundy;

    return AarastCard(
      onTap: onOpenDetails,
      padding: const EdgeInsets.all(14),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.goldSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _categoryIcon(row.name),
                  color: AppTheme.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasBudget
                          ? '${_formatMoney(spent)} ر.ي من ${_formatMoney(allocated)} ر.ي'
                          : hasSpent
                          ? '${_formatMoney(spent)} ر.ي مصروف بدون ميزانية محددة'
                          : 'لم تحدد ميزانية أو مصروفاً بعد',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasBudget ? '$percent%' : '--',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasBudget ? 'تم صرفه' : 'غير محدد',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 7,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.ink.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: progressColor.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AarastStatusPill(
                  label: stateLabel,
                  color: stateColor,
                  icon: row.overBudget == true
                      ? Icons.warning_amber_rounded
                      : Icons.account_balance_wallet_outlined,
                ),
              ),
              if (row.expensesCount != null) ...[
                const SizedBox(width: 8),
                AarastStatusPill(
                  label: '${row.expensesCount} سجل',
                  color: AppTheme.muted,
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onViewProviders,
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: Text(hasBudget ? 'موردين حسب الميزانية' : 'عرض موردين'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopFinancialObligationsCard extends StatelessWidget {
  const _TopFinancialObligationsCard({
    required this.summary,
    required this.onViewDebts,
  });

  final MoneySummary summary;
  final VoidCallback onViewDebts;

  @override
  Widget build(BuildContext context) {
    final installment = summary.nextInstallment;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onViewDebts,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
              bottom: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.danger,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الديون والالتزامات',
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.debtsCount ?? 0} ديون مسجلة',
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'المتبقي',
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${summary.debtRemaining ?? '0'} ر.ي',
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.ink.withValues(alpha: 0.05),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.event_note_outlined,
                  color: AppTheme.burgundy,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'القسط القادم',
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (installment == null)
                        Text(
                          'لا توجد أقساط قادمة حالياً.',
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              installment.debtTitle ?? 'قسط مرتبط بدين',
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (installment.creditorName != null)
                                  installment.creditorName!,
                                if (installment.dueAt != null)
                                  _shortDate(installment.dueAt!),
                                _installmentStateLabel(installment),
                              ].join(' · '),
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (installment != null)
                  YemeniMoneyText(
                    _moneyValue(installment.amount),
                    style: const TextStyle(
                      color: AppTheme.burgundyDeep,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.ink.withValues(alpha: 0.05),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppTheme.gold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'آخر الأقساط المسجلة',
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (summary.paidInstallmentsCount ?? 0) == 0
                            ? 'لا توجد أقساط مدفوعة مسجلة بعد.'
                            : 'الأقساط المدفوعة المسجلة: ${summary.paidInstallmentsCount}',
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceActionStrip extends StatelessWidget {
  const _FinanceActionStrip({
    required this.canManageFinancialRecords,
    required this.onAddExpense,
    required this.onAddCategory,
    required this.onViewDebts,
  });

  final bool canManageFinancialRecords;
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddCategory;
  final VoidCallback onViewDebts;

  @override
  Widget build(BuildContext context) {
    final helper = canManageFinancialRecords
        ? 'سجّل المصروفات والبنود والالتزامات من مكان واحد.'
        : 'يمكنك مراجعة الالتزامات المتاحة حسب صلاحياتك.';

    return AarastCard(
      padding: const EdgeInsets.all(12),
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            helper,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FinanceShortcutCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'مصروف',
                  onTap: onAddExpense,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FinanceShortcutCard(
                  icon: Icons.category_outlined,
                  label: 'بند',
                  onTap: onAddCategory,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FinanceShortcutCard(
                  icon: Icons.credit_card_outlined,
                  label: 'ديون',
                  onTap: onViewDebts,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceShortcutCard extends StatelessWidget {
  const _FinanceShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusMd),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.burgundy, size: 24),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
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
    final statusColor = _expenseStatusColor(expense.status);
    final isPaid = expense.status == 'PAID';

    return Container(
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

num _moneyValueOrZero(String? value) => value == null ? 0 : _moneyValue(value);

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
    'INSTALLMENT_OVERDUE' => 'قسط متأخر يحتاج متابعة',
    'INSTALLMENT_DUE_SOON' => 'قسط قريب يحتاج متابعة',
    'EXPENSE_WITHOUT_CATEGORY' => 'مصروف بدون تصنيف يحتاج ترتيب',
    _ =>
      warning.message.trim().isEmpty
          ? 'تنبيه مالي يحتاج متابعة'
          : warning.message,
  };
}

String _installmentStateLabel(MoneyNextInstallment installment) {
  if (installment.status == 'PAID') return 'مدفوع';
  final dueAt = installment.dueAt;
  if (dueAt == null) return 'قيد المتابعة';
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
  if (dueDay.isBefore(startOfToday)) return 'متأخر';
  if (dueDay.difference(startOfToday).inDays <= 7) return 'قريب';
  return 'قادم';
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
