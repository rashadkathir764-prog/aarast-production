import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../sharing/models/shared_member.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../models/budget_category.dart';
import '../models/expense.dart';
import '../models/expense_summary.dart';
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
  bool _hasExpenseChanges = false;

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

    return AarastScreenFrame(
      maxWidth: 520,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                if (!widget.embedded) ...[
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الميزانية والمصاريف',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.dMaroonDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'إدارة ميزانيتك ومتابعة المدفوعات',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: canManageFinancialRecords
                      ? () => context.push(
                          AppRouter.createBudgetCategory(widget.weddingPlanId),
                          extra: widget.sharedMember,
                        )
                      : null,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: 'إضافة تصنيف',
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.dMaroon,
              onRefresh: _loadFinance,
              child: _hasAnyFinanceAccess
                  ? _FinanceContent(
                      provider: provider,
                      weddingPlanId: widget.weddingPlanId,
                      canManageFinancialRecords: canManageFinancialRecords,
                      sharedMember: widget.sharedMember,
                      onChanged: _markExpenseChanged,
                      suppressErrors: false,
                    )
                  : const _FinancialAccessDeniedState(),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop(_hasExpenseChanges);
      return;
    }
    context.go(AppRouter.home);
  }

  void _markExpenseChanged() {
    _hasExpenseChanges = true;
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
        _SuperMoneyHero(summary: moneySummary),
        const SizedBox(height: 14),
        _BudgetStatusCard(summary: moneySummary),
        const SizedBox(height: 14),
        _QuickMoneyActions(
          canManageFinancialRecords: canManageFinancialRecords,
          onAddExpense: () => _openCreateExpense(context),
          onAddDebt: () => _openCreateDebt(context),
          onRecordInstallment: () => _openDebts(context),
          onAddCategory: () => _openCreateCategory(context),
        ),
        const SizedBox(height: 20),
        if (moneySummary.financialWarnings.isNotEmpty) ...[
          _FinancialWarningsCard(warnings: moneySummary.financialWarnings),
          const SizedBox(height: 18),
        ],
        if (moneySummary.categoriesCount == -1) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FinanceShortcutCard(
                  icon: Icons.category_outlined,
                  label: 'التصنيفات',
                  onTap: canManageFinancialRecords
                      ? () => context.push(
                          AppRouter.createBudgetCategory(weddingPlanId),
                          extra: sharedMember,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FinanceShortcutCard(
                  icon: Icons.credit_card_outlined,
                  label: 'الديون والأقساط',
                  onTap: () => context.push(
                    AppRouter.debts(weddingPlanId),
                    extra: sharedMember,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        AarastSectionHeader(
          title: 'تفاصيل المصروفات حسب الفئة',
          icon: Icons.pie_chart_outline_rounded,
          actionLabel: 'تصنيف',
          onAction: canManageFinancialRecords
              ? () => context.push(
                  AppRouter.createBudgetCategory(weddingPlanId),
                  extra: sharedMember,
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (categoryRows.isEmpty)
          AarastEmptyState(
            title: 'لا توجد تصنيفات بعد',
            message: 'أضف تصنيفات مثل القاعة أو الضيافة لتظهر المتابعة هنا.',
            icon: Icons.category_outlined,
            action: OutlinedButton.icon(
              onPressed: canManageFinancialRecords
                  ? () => context.push(
                      AppRouter.createBudgetCategory(weddingPlanId),
                      extra: sharedMember,
                    )
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة تصنيف'),
            ),
          )
        else
          for (final row in categoryRows) ...[
            _MoneyCategoryProgressRow(row: row),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        AarastSectionHeader(
          title: 'المدفوعات والمصاريف الأخيرة',
          icon: Icons.schedule_rounded,
          actionLabel: 'إضافة',
          onAction: canManageFinancialRecords
              ? () => _openCreateExpense(context)
              : null,
        ),
        const SizedBox(height: 12),
        if (expenses.isEmpty)
          AarastEmptyState(
            title: 'لا توجد مصاريف بعد',
            message: 'عند تسجيل أول مصروف تبدأ لوحة الميزانية في قراءة الواقع.',
            icon: Icons.receipt_long_outlined,
            action: ElevatedButton.icon(
              onPressed: canManageFinancialRecords
                  ? () => _openCreateExpense(context)
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مصروف'),
            ),
          )
        else
          for (final expense in expenses.take(8)) ...[
            _ExpenseRow(
              expense: expense,
              categoryName: _categoryName(
                budgetCategories,
                expense.budgetCategoryId,
              ),
              isBusy: provider.isSubmitting,
              onEdit: () => _openEditExpense(context, expense),
              onDelete: () => _confirmDeleteExpense(context, provider, expense),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        _DebtCommitmentSection(
          summary: moneySummary,
          canManageFinancialRecords: canManageFinancialRecords,
          onAddDebt: () => _openCreateDebt(context),
          onViewDebts: () => _openDebts(context),
          onRecordInstallment: () => _openDebts(context),
        ),
        const SizedBox(height: 18),
        _UpcomingInstallmentsSection(summary: moneySummary),
        const SizedBox(height: 18),
        _InstallmentActivitySection(summary: moneySummary),
      ],
    );
  }

  void _openCreateCategory(BuildContext context) {
    context.push(
      AppRouter.createBudgetCategory(weddingPlanId),
      extra: sharedMember,
    );
  }

  Future<void> _openCreateExpense(BuildContext context) async {
    final changed = await context.push<bool>(
      AppRouter.createExpense(weddingPlanId),
      extra: sharedMember,
    );
    if (changed == true && context.mounted) {
      onChanged();
      await provider.loadFinance(weddingPlanId);
    }
  }

  Future<void> _openCreateDebt(BuildContext context) async {
    await context.push(
      AppRouter.createDebt(weddingPlanId),
      extra: sharedMember,
    );
    if (!context.mounted) return;
    onChanged();
    await provider.loadFinance(weddingPlanId);
  }

  Future<void> _openDebts(BuildContext context) async {
    await context.push(AppRouter.debts(weddingPlanId), extra: sharedMember);
    if (!context.mounted) return;
    onChanged();
    await provider.loadFinance(weddingPlanId);
  }

  Future<void> _openEditExpense(BuildContext context, Expense expense) async {
    if (expense.id.startsWith('local-')) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'هذا المصروف محفوظ على هذا الجهاز وقيد المزامنة. انتظر اكتمال المزامنة قبل تعديله.',
            ),
          ),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'هذا المصروف محفوظ على هذا الجهاز وقيد المزامنة. انتظر اكتمال المزامنة قبل حذفه.',
            ),
          ),
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
                      color: AppTheme.danger.withAlpha(22),
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
                          color: AppTheme.dInk,
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
                          color: AppTheme.dInkSoft,
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
    if (deleted) onChanged();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SuperMoneyHero extends StatelessWidget {
  const _SuperMoneyHero({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final spendingRatio = summary.spendingRatio.clamp(0.0, 1.0);
    final percent = (summary.spendingRatio * 100).round();
    final hasUsableBudget = summary.hasUsableBudget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chart = _SpendingDonut(
            ratio: hasUsableBudget ? spendingRatio : 0,
            label: hasUsableBudget ? '$percent%' : 'بدون',
            caption: hasUsableBudget ? 'نسبة الصرف' : 'بدون ميزانية',
          );
          final stats = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'المال / الميزانية',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'إدارة ميزانيتك ومتابعة مصروفاتك',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MoneyStatTile(
                    label: 'معك',
                    value: summary.totalBudget,
                    color: AppTheme.dGold,
                  ),
                  _MoneyStatTile(
                    label: 'صرفت',
                    value: summary.totalSpent,
                    color: AppTheme.dPinkBg,
                  ),
                  _MoneyStatTile(
                    label: 'باقي',
                    value: summary.remainingBudget,
                    color: AppTheme.dGreen,
                  ),
                  _MoneyStatTile(
                    label: 'ديون',
                    value: summary.debtRemaining ?? summary.totalDebts,
                    color: AppTheme.danger,
                  ),
                ],
              ),
            ],
          );

          if (constraints.maxWidth < 355) {
            return Column(children: [chart, const SizedBox(height: 18), stats]);
          }
          return Row(
            children: [
              Expanded(child: stats),
              const SizedBox(width: 16),
              chart,
            ],
          );
        },
      ),
    );
  }
}

class _SpendingDonut extends StatelessWidget {
  const _SpendingDonut({
    required this.ratio,
    required this.label,
    required this.caption,
  });

  final double ratio;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 126,
      child: CustomPaint(
        painter: _BudgetDonutPainter(paidRatio: ratio),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textDirection: label.contains('%')
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                caption,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withAlpha(205),
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

class _MoneyStatTile extends StatelessWidget {
  const _MoneyStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withAlpha(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          YemeniMoneyText(
            _moneyValue(value ?? '0'),
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

class _BudgetStatusCard extends StatelessWidget {
  const _BudgetStatusCard({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final status = summary.budgetStatus;
    final color = switch (status) {
      'OVER_BUDGET' || 'DANGER' => AppTheme.danger,
      'WARNING' => AppTheme.dGoldDeep,
      _ => AppTheme.dGreen,
    };
    final label = switch (status) {
      'OVER_BUDGET' => 'تجاوزت الميزانية',
      'DANGER' => 'خطر',
      'WARNING' => 'انتبه',
      _ => 'آمن',
    };
    final message = switch (status) {
      'OVER_BUDGET' => 'المصروفات أعلى من الميزانية الحالية.',
      'DANGER' => 'توجد التزامات مالية تحتاج متابعة قريبة.',
      'WARNING' => 'اقتربت من حدود الميزانية أو لديك تنبيه مالي.',
      _ => 'المصروفات ضمن الحدود المتاحة حتى الآن.',
    };

    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(Icons.shield_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AarastStatusPill(label: label, color: color),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
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

class _QuickMoneyActions extends StatelessWidget {
  const _QuickMoneyActions({
    required this.canManageFinancialRecords,
    required this.onAddExpense,
    required this.onAddDebt,
    required this.onRecordInstallment,
    required this.onAddCategory,
  });

  final bool canManageFinancialRecords;
  final VoidCallback onAddExpense;
  final VoidCallback onAddDebt;
  final VoidCallback onRecordInstallment;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MoneyActionChip(
          icon: Icons.add_card_rounded,
          label: 'إضافة مصروف',
          onTap: canManageFinancialRecords ? onAddExpense : null,
        ),
        _MoneyActionChip(
          icon: Icons.account_balance_wallet_outlined,
          label: 'إضافة دين',
          onTap: canManageFinancialRecords ? onAddDebt : null,
        ),
        _MoneyActionChip(
          icon: Icons.event_available_outlined,
          label: 'تسجيل قسط',
          onTap: canManageFinancialRecords ? onRecordInstallment : null,
        ),
        _MoneyActionChip(
          icon: Icons.category_outlined,
          label: 'إضافة تصنيف',
          onTap: canManageFinancialRecords ? onAddCategory : null,
        ),
      ],
    );
  }
}

class _MoneyActionChip extends StatelessWidget {
  const _MoneyActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 17, color: AppTheme.dMaroon),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: onTap == null ? AppTheme.dMuted : AppTheme.dInk,
          fontWeight: FontWeight.w800,
        ),
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      backgroundColor: onTap == null ? AppTheme.dCard2 : AppTheme.dCreamBg,
      side: BorderSide(
        color: onTap == null ? AppTheme.dLine : AppTheme.dGold.withAlpha(55),
      ),
      onPressed: onTap,
    );
  }
}

class _FinancialWarningsCard extends StatelessWidget {
  const _FinancialWarningsCard({required this.warnings});

  final List<MoneyFinancialWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.danger.withAlpha(12),
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
                      : AppTheme.dGoldDeep,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _warningCopy(warning),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInk,
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

class _MoneyCategoryProgressRow extends StatelessWidget {
  const _MoneyCategoryProgressRow({required this.row});

  final MoneyCategorySummary row;

  @override
  Widget build(BuildContext context) {
    final progress = row.percentUsed;
    final color = progress >= 1
        ? AppTheme.danger
        : progress >= .75
        ? AppTheme.dGoldDeep
        : AppTheme.dMaroon;

    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(_categoryIcon(row.name), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppTheme.dLine,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MoneyStatusPill(
                label: 'المخصص',
                value: _moneyValue(row.allocated ?? '0'),
                color: AppTheme.dGoldDeep,
              ),
              _MoneyStatusPill(
                label: 'المصروف',
                value: _moneyValue(row.spent ?? '0'),
                color: AppTheme.dMaroon,
              ),
              _MoneyStatusPill(
                label: 'الباقي',
                value: _moneyValue(row.remaining ?? '0'),
                color: row.overBudget == true
                    ? AppTheme.danger
                    : AppTheme.dGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyStatusPill extends StatelessWidget {
  const _MoneyStatusPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w800,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          const SizedBox(width: 5),
          YemeniMoneyText(value, style: style),
        ],
      ),
    );
  }
}

class _DebtCommitmentSection extends StatelessWidget {
  const _DebtCommitmentSection({
    required this.summary,
    required this.canManageFinancialRecords,
    required this.onAddDebt,
    required this.onViewDebts,
    required this.onRecordInstallment,
  });

  final MoneySummary summary;
  final bool canManageFinancialRecords;
  final VoidCallback onAddDebt;
  final VoidCallback onViewDebts;
  final VoidCallback onRecordInstallment;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AarastSectionHeader(
            title: 'الديون والالتزامات',
            icon: Icons.account_balance_outlined,
            actionLabel: 'عرض الديون',
            onAction: onViewDebts,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CompactMetric(
                label: 'إجمالي الديون',
                moneyValue: _moneyValue(summary.totalDebts ?? '0'),
              ),
              _CompactMetric(
                label: 'المتبقي',
                moneyValue: _moneyValue(summary.debtRemaining ?? '0'),
              ),
              _CompactMetric(
                label: 'عدد الديون',
                value: '${summary.debtsCount ?? 0}',
              ),
              _CompactMetric(
                label: 'القسط القادم',
                value: summary.nextInstallment == null ? 'لا يوجد' : null,
                moneyValue: summary.nextInstallment == null
                    ? null
                    : _moneyValue(summary.nextInstallment!.amount),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canManageFinancialRecords ? onAddDebt : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة دين'),
              ),
              OutlinedButton.icon(
                onPressed: onViewDebts,
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('عرض الديون'),
              ),
              OutlinedButton.icon(
                onPressed: canManageFinancialRecords
                    ? onRecordInstallment
                    : null,
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('تسجيل قسط'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingInstallmentsSection extends StatelessWidget {
  const _UpcomingInstallmentsSection({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final installment = summary.nextInstallment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AarastSectionHeader(
          title: 'الأقساط القادمة',
          icon: Icons.event_note_outlined,
        ),
        const SizedBox(height: 12),
        if (installment == null)
          const AarastEmptyState(
            title: 'لا توجد أقساط قادمة',
            message: 'أي قسط مرتبط بدين سيظهر هنا عند توفر تاريخ استحقاق.',
            icon: Icons.event_available_outlined,
          )
        else
          AarastCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppTheme.dMaroon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        installment.debtTitle ?? 'قسط مرتبط بدين',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (installment.creditorName != null)
                            installment.creditorName!,
                          if (installment.dueAt != null)
                            _shortDate(installment.dueAt!),
                          _installmentStateLabel(installment),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                YemeniMoneyText(
                  _moneyValue(installment.amount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dMaroonDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InstallmentActivitySection extends StatelessWidget {
  const _InstallmentActivitySection({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final paid = summary.paidInstallmentsCount ?? 0;
    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppTheme.dGoldDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آخر الأقساط المسجلة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paid == 0
                      ? 'لا توجد أقساط مدفوعة مسجلة بعد، ولا توجد قائمة مدفوعات وهمية.'
                      : 'الأقساط المدفوعة المسجلة: $paid',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
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

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, this.value, this.moneyValue});

  final String label;
  final String? value;
  final num? moneyValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCreamBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (moneyValue == null)
            Text(
              value ?? '',
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            YemeniMoneyText(
              moneyValue!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
              ),
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
              Icon(icon, color: AppTheme.dMaroon, size: 24),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.dInk,
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

// ignore: unused_element
class _BudgetHero extends StatelessWidget {
  const _BudgetHero({required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final paid = _moneyValue(summary.totalPaid);
    final planned = _moneyValue(summary.totalPlanned);
    final cancelled = _moneyValue(summary.totalCancelled);
    final activeTotal = paid + planned;
    final grandTotal = activeTotal + cancelled;
    final paidRatio = activeTotal <= 0 ? 0.0 : paid / activeTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 355;
          final chart = _BudgetDonut(
            paidRatio: paidRatio,
            label: '${(paidRatio * 100).round()}%',
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إجمالي المصروفات',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _MoneyText(
                grandTotal,
                color: Colors.white,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroFinanceTile(
                    label: 'المدفوع',
                    value: paid,
                    color: AppTheme.dPinkBg,
                  ),
                  _HeroFinanceTile(
                    label: 'المخطط',
                    value: planned,
                    color: AppTheme.dGold,
                  ),
                ],
              ),
              if (cancelled > 0) ...[
                const SizedBox(height: 10),
                AarastStatusPill(
                  label: 'ملغي: ${_formatMoney(cancelled)} ر.ي',
                  color: Colors.white,
                  backgroundColor: Colors.white.withAlpha(24),
                  icon: Icons.block_rounded,
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              children: [chart, const SizedBox(height: 18), content],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
              chart,
            ],
          );
        },
      ),
    );
  }
}

class _BudgetDonut extends StatelessWidget {
  const _BudgetDonut({required this.paidRatio, required this.label});

  final double paidRatio;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 126,
      child: CustomPaint(
        painter: _BudgetDonutPainter(paidRatio: paidRatio),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'مدفوع',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withAlpha(205),
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

class _BudgetDonutPainter extends CustomPainter {
  const _BudgetDonutPainter({required this.paidRatio});

  final double paidRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..color = Colors.white.withAlpha(54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final paidPaint = Paint()
      ..shader = AppTheme.goldGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final plannedPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * paidRatio.clamp(0.0, 1.0),
      false,
      paidPaint,
    );
    if (paidRatio < 1) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + (math.pi * 2 * paidRatio.clamp(0.0, 1.0)),
        math.pi * 2 * (1 - paidRatio.clamp(0.0, 1.0)),
        false,
        plannedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BudgetDonutPainter oldDelegate) {
    return oldDelegate.paidRatio != paidRatio;
  }
}

class _HeroFinanceTile extends StatelessWidget {
  const _HeroFinanceTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withAlpha(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withAlpha(210),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MoneyText(
            value,
            color: Colors.white,
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

// ignore: unused_element
class _BudgetCategoryProgressRow extends StatelessWidget {
  const _BudgetCategoryProgressRow({required this.row});

  final _CategorySpendRow row;

  @override
  Widget build(BuildContext context) {
    final color = row.progress >= .9
        ? AppTheme.danger
        : row.progress >= .65
        ? AppTheme.dGoldDeep
        : AppTheme.dMaroon;

    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(_categoryIcon(row.name), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(row.progress * 100).round()}%',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: row.progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppTheme.dLine,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.target > 0
                            ? 'من ${_formatMoney(row.target)} ر.ي'
                            : 'بدون مبلغ مستهدف',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _MoneyText(
                      row.spent,
                      color: AppTheme.dInk,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.dInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(
              isPaid
                  ? Icons.receipt_long_rounded
                  : Icons.pending_actions_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    AarastStatusPill(
                      label: _expenseStatusLabel(expense.status),
                      color: statusColor,
                    ),
                    AarastStatusPill(
                      label: categoryName,
                      color: AppTheme.dGoldDeep,
                      icon: Icons.folder_outlined,
                    ),
                    if (expense.expenseDate != null)
                      AarastStatusPill(
                        label: _shortDate(expense.expenseDate!),
                        color: AppTheme.dMuted,
                        icon: Icons.calendar_month_rounded,
                      ),
                    OfflinePendingBadge(
                      entityType: 'expense',
                      entityId: expense.id,
                    ),
                  ],
                ),
                if (expense.hasNote) ...[
                  const SizedBox(height: 7),
                  Text(
                    expense.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MoneyText(
            _moneyValue(expense.amount),
            color: AppTheme.dMaroonDeep,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.dMaroonDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<_ExpenseAction>(
            enabled: !isBusy,
            tooltip: 'خيارات المصروف',
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.dMuted),
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
    this.color = AppTheme.dInk,
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
          color: AppTheme.dLine,
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
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
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
        color: AppTheme.danger.withAlpha(18),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withAlpha(45)),
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

class _MoneyText extends StatelessWidget {
  const _MoneyText(this.value, {required this.color, this.style});

  final num value;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_formatMoney(value)} ر.ي',
      textDirection: TextDirection.ltr,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          style ??
          Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
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
  });

  final String id;
  final String name;
  final num spent;
  final num target;
  final double progress;
}

List<_CategorySpendRow> _buildCategoryRows(
  List<BudgetCategory> categories,
  List<Expense> expenses,
) {
  final activeExpenses = expenses.where(
    (expense) => expense.status != 'CANCELLED',
  );
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
    return _CategorySpendRow(
      id: category.id,
      name: category.name,
      spent: spent,
      target: target,
      progress: progress.toDouble(),
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
    'PAID' => AppTheme.dGreen,
    'CANCELLED' => AppTheme.dMuted,
    _ => AppTheme.dGoldDeep,
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
