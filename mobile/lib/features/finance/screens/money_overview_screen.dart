import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../sharing/models/shared_member.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart';

class MoneyOverviewScreen extends StatefulWidget {
  const MoneyOverviewScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;
  final bool embedded;

  @override
  State<MoneyOverviewScreen> createState() => _MoneyOverviewScreenState();
}

class _MoneyOverviewScreenState extends State<MoneyOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MoneyOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final bottomClearance = widget.embedded && provider.canManageMoney
        ? 204.0
        : 132.0;
    final content = RefreshIndicator(
      color: AppTheme.burgundy,
      onRefresh: _load,
      child: ListView(
        key: const PageStorageKey('money-overview-list'),
        padding: EdgeInsets.fromLTRB(20, 18, 20, bottomClearance),
        children: [
          if (provider.isLoading && !provider.hasLoadedMoney)
            const AarastScreenLoading(label: 'نرتب صورة المال')
          else if (provider.errorMessage != null && !provider.hasLoadedMoney)
            AarastErrorState(
              title: 'تعذر تحميل المال',
              message: provider.errorMessage!,
              onRetry: _load,
            )
          else ...[
            _OverviewHeader(
              summary: provider.summary,
              showBudgetAction:
                  provider.canManageMoney && provider.summary.hasBudget,
              onBudget: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
            ),
            const SizedBox(height: 14),
            if (provider.errorMessage != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            if (!provider.summary.hasAnyData &&
                provider.costs.isEmpty &&
                provider.payments.isEmpty &&
                provider.dueSchedules.isEmpty)
              _MoneyFirstUseCard(
                canManage: provider.canManageMoney,
                onStart: () =>
                    context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
              )
            else ...[
              _MoneyHero(
                summary: provider.summary,
                canManage: provider.canManageMoney,
                onBudget: () =>
                    context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
              ),
              if (provider.dueSchedules.isNotEmpty) ...[
                const SizedBox(height: 14),
                _NextScheduleStrip(
                  summary: provider.summary,
                  schedules: provider.dueSchedules,
                  currency: provider.summary.currency,
                  onOpen: () => context.push(
                    AppRouter.moneySchedules(widget.weddingPlanId),
                  ),
                ),
              ],
              if (provider.categories.isNotEmpty) ...[
                const SizedBox(height: 22),
                _CategoriesPreview(
                  categories: provider.categories,
                  currency: provider.summary.currency,
                  canManage: provider.canManageMoney,
                  onManage: () =>
                      context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
                  onOpen: (category) => context.push(
                    AppRouter.moneyCategoryDetails(
                      widget.weddingPlanId,
                      category.id,
                    ),
                  ),
                ),
              ],
              if (provider.costs.isNotEmpty) ...[
                const SizedBox(height: 22),
                _CostsPreview(
                  costs: provider.costs,
                  categories: provider.categories,
                  currency: provider.summary.currency,
                  onOpenAll: () =>
                      context.push(AppRouter.moneyCosts(widget.weddingPlanId)),
                  onOpen: (cost) => context.push(
                    AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
                  ),
                ),
              ],
              if (provider.payments.isNotEmpty) ...[
                const SizedBox(height: 22),
                _PaymentsPreview(
                  payments: provider.payments,
                  costs: provider.costs,
                  currency: provider.summary.currency,
                  onOpen: (payment) => context.push(
                    AppRouter.moneyPaymentDetails(
                      widget.weddingPlanId,
                      payment.id,
                    ),
                  ),
                ),
              ],
              if (provider.summary.hasBudget &&
                  provider.categories.isEmpty) ...[
                const SizedBox(height: 20),
                _MoneyNextStepCard(
                  icon: LucideIcons.tags,
                  title: 'أضف أول تصنيف',
                  message:
                      'قسّم الميزانية إلى أقسام واضحة مثل القاعة والتصوير.',
                  actionLabel: 'إضافة تصنيف',
                  canManage: provider.canManageMoney,
                  onAction: () => context.push(
                    AppRouter.moneyCategoryCreate(widget.weddingPlanId),
                  ),
                ),
              ] else if (provider.categories.isNotEmpty &&
                  provider.costs.isEmpty) ...[
                const SizedBox(height: 20),
                _MoneyNextStepCard(
                  icon: LucideIcons.receipt,
                  title: 'سجّل أول تكلفة',
                  message: 'اختر تصنيفًا ثم أضف التكلفة المتفق عليها.',
                  actionLabel: 'إضافة تكلفة',
                  canManage: provider.canManageMoney,
                  onAction: () => context.push(
                    AppRouter.moneyCostCreate(widget.weddingPlanId),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(
        key: const ValueKey('money-overview-surface'),
        color: AppTheme.ivory,
        child: Directionality(textDirection: TextDirection.rtl, child: content),
      );
    }
    return AarastScreenFrame(maxWidth: 560, child: content);
  }

  Future<void> _load() {
    final member = widget.sharedMember;
    return context.read<FinanceProvider>().loadMoney(
      widget.weddingPlanId,
      canViewMoney: member?.canViewMoney ?? true,
      canManageMoney: member?.canManageMoney ?? true,
    );
  }
}

class _MoneyFirstUseCard extends StatelessWidget {
  const _MoneyFirstUseCard({required this.canManage, required this.onStart});

  final bool canManage;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      icon: LucideIcons.walletCards,
      title: canManage ? 'ابدأ تنظيم مال الزفاف' : 'لا توجد بيانات مالية بعد',
      message: canManage
          ? 'حدد الميزانية وأضف التصنيفات، ثم سجّل كل تكلفة ودفعاتها من مكانها.'
          : 'لم تُضف ميزانية أو تكاليف لهذه الخطة حتى الآن.',
      action: canManage
          ? FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(LucideIcons.arrowLeft),
              label: const Text('ابدأ بإعداد الميزانية'),
            )
          : null,
    );
  }
}

class _MoneyNextStepCard extends StatelessWidget {
  const _MoneyNextStepCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.canManage,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final bool canManage;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      icon: icon,
      title: title,
      message: message,
      action: canManage
          ? FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(LucideIcons.arrowLeft),
              label: Text(actionLabel),
            )
          : null,
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.summary,
    required this.showBudgetAction,
    required this.onBudget,
  });

  final MoneySummary summary;
  final bool showBudgetAction;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    // ترويسة مضغوطة: عنوان + شارة استخدام حية بدل سطر تسويقي.
    final usedPercent = (summary.confirmedRatio * 100).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'المال',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: AppTheme.displayFontFamily,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (summary.hasBudget) ...[
          const SizedBox(width: 10),
          AarastStatusPill(
            label: '$usedPercent% مستخدم',
            color: AppTheme.goldDeep,
            backgroundColor: AppTheme.goldSoft,
            icon: LucideIcons.wallet,
          ),
        ],
        if (showBudgetAction)
          IconButton(
            onPressed: onBudget,
            icon: const Icon(LucideIcons.settings2),
            tooltip: 'إدارة الميزانية',
          ),
      ],
    );
  }
}

class _MoneyHero extends StatelessWidget {
  const _MoneyHero({
    required this.summary,
    required this.canManage,
    required this.onBudget,
  });

  final MoneySummary summary;
  final bool canManage;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasBudget) {
      return AarastCard(
        color: AppTheme.goldLight,
        border: Border.all(color: AppTheme.gold.withValues(alpha: .45)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              LucideIcons.walletCards,
              color: AppTheme.goldDeep,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'ابدأ بميزانية واضحة',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'حدد السقف المالي ثم وزّعه على التصنيفات. لن تتحول المخصصات إلى ميزانية من تلقاء نفسها.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
            if (canManage) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onBudget,
                icon: const Icon(LucideIcons.plus),
                label: const Text('إعداد الميزانية'),
              ),
            ],
          ],
        ),
      );
    }

    final remaining = moneyValue(summary.budget.remaining);
    final remainingColor = remaining < 0
        ? AppTheme.danger
        : summary.confirmedRatio >= .85
        ? AppTheme.warning
        : AppTheme.success;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'المتبقي من الميزانية',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .76),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          MoneyAmountText(
            amount: summary.budget.remaining,
            currency: summary.currency,
            style: Theme.of(context).textTheme.headlineMedium,
            color: remaining < 0 ? AppTheme.goldSoft : Colors.white,
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: summary.confirmedRatio.clamp(0.0, 1.0),
              color: remainingColor,
              backgroundColor: Colors.white.withValues(alpha: .18),
            ),
          ),
          const SizedBox(height: 16),
          _HeroMetricsRow(summary: summary),
        ],
      ),
    );
  }
}

/// صف مؤشرات واحد مقسوم بفواصل رفيعة بدل شبكة الصناديق 2×2.
class _HeroMetricsRow extends StatelessWidget {
  const _HeroMetricsRow({required this.summary});

  final MoneySummary summary;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: .16),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _HeroMetric(
          label: 'الميزانية',
          amount: summary.budget.total,
          currency: summary.currency,
        ),
        divider,
        _HeroMetric(
          label: 'المدفوع',
          amount: summary.costs.paid,
          currency: summary.currency,
        ),
        divider,
        _HeroMetric(
          label: 'الباقي عليك',
          amount: summary.costs.outstanding,
          currency: summary.currency,
          valueColor: AppTheme.goldLight,
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.amount,
    required this.currency,
    this.valueColor = Colors.white,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: MoneyAmountText(
                amount: amount,
                currency: currency,
                style: Theme.of(context).textTheme.labelLarge,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط واحد للموعد الأقرب — يفتح شاشة مواعيد الدفع الكاملة.
/// يتحول للون الخطر تلقائيًا عند وجود مواعيد متأخرة.
class _NextScheduleStrip extends StatelessWidget {
  const _NextScheduleStrip({
    required this.summary,
    required this.schedules,
    required this.currency,
    required this.onOpen,
  });

  final MoneySummary summary;
  final List<PaymentSchedule> schedules;
  final String currency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final nearest = schedules.first;
    final overdueCount = summary.paymentSchedules.overdueCount;
    final isOverdue = overdueCount > 0;
    final color = isOverdue ? AppTheme.danger : AppTheme.goldDeep;
    final title = isOverdue
        ? 'لديك $overdueCount موعد دفع متأخر يحتاج متابعة'
        : 'الموعد القادم: ${nearest.costTitle ?? 'موعد دفع'}';

    return AarastCard(
      key: const ValueKey('money-next-schedule-strip'),
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      color: isOverdue ? AppTheme.dangerSoft : AppTheme.goldSoft,
      radius: AppTheme.radiusMd,
      border: Border.all(color: color.withValues(alpha: .35)),
      child: Row(
        children: [
          Icon(LucideIcons.calendarClock, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        formatArabicCompactDate(nearest.dueDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Text(
                      ' · ',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: color),
                    ),
                    Flexible(
                      child: MoneyAmountText(
                        amount: nearest.amount,
                        currency: currency,
                        style: Theme.of(context).textTheme.labelSmall,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronLeft, size: 17, color: color),
        ],
      ),
    );
  }
}

class _CategoriesPreview extends StatelessWidget {
  const _CategoriesPreview({
    required this.categories,
    required this.currency,
    required this.canManage,
    required this.onManage,
    required this.onOpen,
  });

  final List<BudgetCategory> categories;
  final String currency;
  final bool canManage;
  final VoidCallback onManage;
  final ValueChanged<BudgetCategory> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'التصنيفات',
          icon: LucideIcons.tags,
          actionLabel: canManage ? 'إدارة' : null,
          onAction: canManage ? onManage : null,
        ),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          const AarastEmptyState(
            icon: LucideIcons.tags,
            title: 'لا توجد تصنيفات',
            message: 'التصنيف يجعل كل تكلفة في مكانها الصحيح.',
          )
        else
          Builder(
            builder: (context) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final visible = categories.take(4).toList();
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: textScale > 1.15 ? 108 : 92,
                ),
                itemBuilder: (context, index) => _CategoryTile(
                  category: visible[index],
                  currency: currency,
                  onTap: () => onOpen(visible[index]),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// بلاطة تصنيف مضغوطة — أربعة تصنيفات في مساحة بطاقة واحدة قديمة.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.currency,
    required this.onTap,
  });

  final BudgetCategory category;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final allocation = moneyValue(category.allocatedAmount);
    final confirmed = moneyValue(category.confirmedCost);
    final hasAllocation = category.allocatedAmount != null && allocation > 0;
    final over = hasAllocation && confirmed > allocation;
    final ratio = !hasAllocation
        ? 0.0
        : (confirmed / allocation).clamp(0.0, 1.0).toDouble();
    final nameColor = over ? AppTheme.danger : AppTheme.ink;
    final amountColor = over ? AppTheme.danger : AppTheme.muted;

    return AarastCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      radius: AppTheme.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: nameColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${category.costsCount} تكلفة',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                MoneyAmountText(
                  amount: category.confirmedCost,
                  currency: currency,
                  style: Theme.of(context).textTheme.labelSmall,
                  color: amountColor,
                ),
                if (hasAllocation) ...[
                  Text(
                    ' / ',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                  ),
                  MoneyAmountText(
                    amount: category.allocatedAmount,
                    currency: currency,
                    style: Theme.of(context).textTheme.labelSmall,
                    color: AppTheme.muted,
                  ),
                ] else
                  Text(
                    ' · بلا مخصص',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                  ),
              ],
            ),
          ),
          if (hasAllocation) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: over ? 1 : ratio,
                color: over ? AppTheme.danger : AppTheme.burgundy,
                backgroundColor: AppTheme.empty,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CostsPreview extends StatelessWidget {
  const _CostsPreview({
    required this.costs,
    required this.categories,
    required this.currency,
    required this.onOpenAll,
    required this.onOpen,
  });

  final List<WeddingCost> costs;
  final List<BudgetCategory> categories;
  final String currency;
  final VoidCallback onOpenAll;
  final ValueChanged<WeddingCost> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'أحدث التكاليف',
          icon: LucideIcons.receipt,
          actionLabel: 'عرض الكل',
          onAction: onOpenAll,
        ),
        const SizedBox(height: 10),
        if (costs.isEmpty)
          const AarastEmptyState(
            icon: LucideIcons.receipt,
            title: 'لا توجد تكاليف بعد',
            message: 'أضف أول تكلفة من زر الإضافة.',
          )
        else
          for (final cost in costs.take(3)) ...[
            CostCard(
              cost: cost,
              currency: currency,
              categoryName: _categoryName(categories, cost.budgetCategoryId),
              onTap: () => onOpen(cost),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PaymentsPreview extends StatelessWidget {
  const _PaymentsPreview({
    required this.payments,
    required this.costs,
    required this.currency,
    required this.onOpen,
  });

  final List<CostPayment> payments;
  final List<WeddingCost> costs;
  final String currency;
  final ValueChanged<CostPayment> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AarastSectionHeader(
          title: 'آخر الدفعات',
          icon: LucideIcons.banknote,
        ),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          const AarastEmptyState(
            icon: LucideIcons.banknote,
            title: 'لا توجد دفعات',
            message: 'تظهر هنا الدفعات المسجلة على التكاليف.',
          )
        else
          for (final payment in payments.take(2)) ...[
            PaymentCard(
              payment: payment,
              currency: currency,
              costTitle: _costTitle(costs, payment.costId),
              onTap: () => onOpen(payment),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

String? _categoryName(List<BudgetCategory> categories, String id) {
  for (final category in categories) {
    if (category.id == id) return category.name;
  }
  return null;
}

String? _costTitle(List<WeddingCost> costs, String id) {
  for (final cost in costs) {
    if (cost.id == id) return cost.title;
  }
  return null;
}
