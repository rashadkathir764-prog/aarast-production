import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/expense_summary.dart';
import '../models/expense.dart';
import '../models/budget_category.dart';
import '../providers/finance_provider.dart';

class BudgetExpenseScreen extends StatefulWidget {
  const BudgetExpenseScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<BudgetExpenseScreen> createState() => _BudgetExpenseScreenState();
}

class _BudgetExpenseScreenState extends State<BudgetExpenseScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRouter.home);
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.dCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.dLine),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppTheme.dMaroon),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'الميزانية والمصاريف',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.dMaroonDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push(AppRouter.createBudgetCategory(widget.weddingPlanId)),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.dCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.dLine),
                          ),
                          child: const Icon(LucideIcons.folderPlus, color: AppTheme.dInk),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.push(AppRouter.createExpense(widget.weddingPlanId)),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.heroGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.dMaroonDeep.withAlpha(50),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(LucideIcons.plus, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.dMaroon,
                onRefresh: () => provider.loadFinance(widget.weddingPlanId),
                child: _FinanceContent(
                  provider: provider,
                  weddingPlanId: widget.weddingPlanId,
                  animationController: _animationController,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceContent extends StatelessWidget {
  const _FinanceContent({
    required this.provider,
    required this.weddingPlanId,
    required this.animationController,
  });

  final FinanceProvider provider;
  final String weddingPlanId;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading &&
        provider.budgetCategories.isEmpty &&
        provider.expenses.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.dMaroon));
    }

    if (provider.errorMessage != null &&
        provider.budgetCategories.isEmpty &&
        provider.expenses.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(LucideIcons.alertTriangle, size: 48, color: AppTheme.danger.withAlpha(150)),
          const SizedBox(height: 16),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dMaroon),
              onPressed: () => provider.loadFinance(weddingPlanId),
              child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (provider.errorMessage != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withAlpha(20),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.danger.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppTheme.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        _buildAnimated(0, _LuxuryPieChartSummary(summary: provider.summary, animation: animationController)),
        const SizedBox(height: 32),

        _buildAnimated(1, Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionTitle(
            title: 'المصاريف',
            emptyMessage: 'لا توجد مصاريف بعد.',
            isEmpty: provider.expenses.isEmpty,
          ),
        )),

        ...provider.expenses.asMap().entries.map((entry) {
          final index = entry.key;
          final expense = entry.value;
          return _buildAnimated(
            2 + index,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _ExpenseItemCard(
                expense: expense,
                budgetCategories: provider.budgetCategories,
              ),
            ),
          );
        }),

        const SizedBox(height: 32),

        _buildAnimated(provider.expenses.length + 3, Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionTitle(
            title: 'تصنيفات الميزانية',
            emptyMessage: 'لا توجد تصنيفات بعد.',
            isEmpty: provider.budgetCategories.isEmpty,
          ),
        )),

        ...provider.budgetCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          return _buildAnimated(
            provider.expenses.length + 4 + index,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _BudgetCategoryCard(category: category),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAnimated(int index, Widget child) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, childWidget) {
        final delay = (index * 0.1).clamp(0.0, 0.5);
        final value = (animationController.value - delay).clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(value);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - curve)),
          child: Opacity(
            opacity: curve,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}

class _LuxuryPieChartSummary extends StatelessWidget {
  const _LuxuryPieChartSummary({
    required this.summary,
    required this.animation,
  });

  final ExpenseSummary summary;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final paid = double.tryParse(summary.totalPaid) ?? 0.0;
    final planned = double.tryParse(summary.totalPlanned) ?? 0.0;
    final total = paid + planned;
    
    // Fallback if zero to avoid div by zero
    final paidRatio = total > 0 ? paid / total : 0.0;
    final plannedRatio = total > 0 ? planned / total : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.dLine),
        boxShadow: AppTheme.softShadow(opacity: 0.05),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إجمالي المصاريف',
                    style: TextStyle(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${total.toStringAsFixed(0)} YER',
                    style: const TextStyle(
                      color: AppTheme.dMaroonDeep,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.dGold.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.pieChart, color: AppTheme.dGold2, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'الملخص',
                      style: const TextStyle(
                        color: AppTheme.dGoldDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final curve = Curves.easeOutCirc.transform(animation.value);
                      return CustomPaint(
                        painter: _PieChartPainter(
                          paidRatio: paidRatio,
                          plannedRatio: plannedRatio,
                          progress: curve,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(paidRatio * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.dInk,
                                ),
                              ),
                              const Text(
                                'المدفوع',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.dMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        color: AppTheme.dMaroon,
                        label: 'مدفوع',
                        amount: '${paid.toStringAsFixed(0)} YER',
                        count: '${summary.countPaid} عمليات',
                      ),
                      const SizedBox(height: 20),
                      _buildLegendItem(
                        color: AppTheme.dGold,
                        label: 'مخطط',
                        amount: '${planned.toStringAsFixed(0)} YER',
                        count: '${summary.countPlanned} عمليات',
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

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String amount,
    required String count,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dInkSoft,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.dInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({
    required this.paidRatio,
    required this.plannedRatio,
    required this.progress,
  });

  final double paidRatio;
  final double plannedRatio;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.3;

    final paintBg = Paint()
      ..color = AppTheme.dLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Draw background
    canvas.drawArc(rect, 0, 2 * pi, false, paintBg);

    if (progress == 0) return;

    final paidPaint = Paint()
      ..color = AppTheme.dMaroon
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final plannedPaint = Paint()
      ..color = AppTheme.dGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -pi / 2;
    final totalSweep = 2 * pi * progress;

    final paidSweep = totalSweep * paidRatio;
    final plannedSweep = totalSweep * plannedRatio;

    // Draw Planned (first, from startAngle)
    if (plannedSweep > 0) {
      canvas.drawArc(rect, startAngle, plannedSweep, false, plannedPaint);
    }

    // Draw Paid (next, from startAngle + plannedSweep)
    // Actually, draw Paid first, then planned, or vice versa
    // Let's draw Paid first
    if (paidSweep > 0) {
      canvas.drawArc(rect, startAngle, paidSweep, false, paidPaint);
    }
    
    if (plannedSweep > 0) {
      canvas.drawArc(rect, startAngle + paidSweep, plannedSweep, false, plannedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.paidRatio != paidRatio ||
           oldDelegate.plannedRatio != plannedRatio ||
           oldDelegate.progress != progress;
  }
}

class _ExpenseItemCard extends StatelessWidget {
  const _ExpenseItemCard({
    required this.expense,
    required this.budgetCategories,
  });

  final Expense expense;
  final List<BudgetCategory> budgetCategories;

  @override
  Widget build(BuildContext context) {
    final isPaid = expense.status == 'PAID';
    final categoryName = _getCategoryName(expense.budgetCategoryId);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
        boxShadow: AppTheme.softShadow(opacity: 0.03),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: isPaid ? AppTheme.dMaroon : AppTheme.dGold,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isPaid ? AppTheme.dMaroon.withAlpha(20) : AppTheme.dGold.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isPaid ? LucideIcons.checkCheck : LucideIcons.clock,
                      color: isPaid ? AppTheme.dMaroon : AppTheme.dGoldDeep,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                expense.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.dInk,
                                ),
                              ),
                            ),
                            Text(
                              '${expense.amount} YER',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.dMaroonDeep,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(LucideIcons.folder, size: 14, color: AppTheme.dMuted),
                            const SizedBox(width: 4),
                            Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dMuted,
                              ),
                            ),
                            const Spacer(),
                            if (expense.expenseDate != null) ...[
                              Icon(LucideIcons.calendar, size: 14, color: AppTheme.dMuted),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(expense.expenseDate!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.dMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (expense.hasNote) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.dBg,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(LucideIcons.info, size: 14, color: AppTheme.dMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    expense.note!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.dInkSoft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null || categoryId.trim().isEmpty) return 'غير مصنف';
    try {
      final category = budgetCategories.firstWhere((c) => c.id == categoryId);
      return category.name;
    } catch (_) {
      return 'غير مصنف';
    }
  }
}

class _BudgetCategoryCard extends StatelessWidget {
  const _BudgetCategoryCard({required this.category});

  final BudgetCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.layoutGrid, color: AppTheme.dInkSoft),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dInk,
                    ),
                  ),
                  if (category.hasTargetAmount) ...[
                    const SizedBox(height: 4),
                    Text(
                      'المستهدف: ${category.targetAmount} YER',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.chevronLeft, color: AppTheme.dLine),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.emptyMessage,
    required this.isEmpty,
  });

  final String title;
  final String emptyMessage;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.dMaroonDeep,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.right,
          ),
          if (isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.dCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.dLine, style: BorderStyle.solid),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.inbox, color: AppTheme.dMuted),
                  const SizedBox(width: 12),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppTheme.dMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
