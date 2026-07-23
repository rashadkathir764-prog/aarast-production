import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../sharing/models/shared_member.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart';

/// نقطة الدخول الوحيدة للمال.
///
/// تعرض ملخص MoneySummary ثم قائمة WeddingCost. تبقى حركات الدفع داخل تفاصيل
/// التكلفة، بينما تُفتح الميزانية ومواعيد الدفع في شاشاتهما المتخصصة.
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomClearance),
        children: [
          if (provider.isLoading && !provider.hasLoadedMoney)
            const AarastScreenLoading(label: 'نرتب صورتك المالية')
          else if (provider.errorMessage != null && !provider.hasLoadedMoney)
            AarastErrorState(
              title: 'تعذر تحميل المال',
              message: provider.errorMessage!,
              onRetry: _load,
            )
          else ...[
            _MoneyHeader(
              onBudget: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
              onSchedules: () =>
                  context.push(AppRouter.moneySchedules(widget.weddingPlanId)),
            ),
            const SizedBox(height: 18),
            if (provider.errorMessage != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 14),
            ],
            _MoneySnapshot(
              summary: provider.summary,
              canManage: provider.canManageMoney,
              onBudget: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
            ),
            if (_nextSchedule(provider) case final schedule?) ...[
              const SizedBox(height: 14),
              _NextPaymentCard(
                schedule: schedule,
                currency: provider.summary.currency,
                onTap: () => context.push(
                  AppRouter.moneyScheduleDetails(
                    widget.weddingPlanId,
                    schedule.costId,
                    schedule.id,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _MoneyCostsSection(
              costs: provider.costs,
              currency: provider.summary.currency,
              canManage: provider.canManageMoney,
              hasBudget: provider.summary.hasBudget,
              hasMore: provider.hasMoreCosts,
              categoryName: (cost) =>
                  provider.categoryById(cost.budgetCategoryId)?.name ??
                  cost.categoryName,
              onAdd: () =>
                  context.push(AppRouter.moneyCostCreate(widget.weddingPlanId)),
              onBudget: () =>
                  context.push(AppRouter.moneyBudget(widget.weddingPlanId)),
              onAll: () =>
                  context.push(AppRouter.moneyCosts(widget.weddingPlanId)),
              onOpen: (cost) => context.push(
                AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
              ),
            ),
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

  PaymentSchedule? _nextSchedule(FinanceProvider provider) {
    return provider.summary.paymentSchedules.next ??
        (provider.dueSchedules.isEmpty ? null : provider.dueSchedules.first);
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

enum _MoneySettingsAction { budget, schedules }

class _MoneyHeader extends StatelessWidget {
  const _MoneyHeader({required this.onBudget, required this.onSchedules});

  final VoidCallback onBudget;
  final VoidCallback onSchedules;

  @override
  Widget build(BuildContext context) {
    return AarastFeatureHeader(
      title: 'المال',
      subtitle: 'ميزانيتك، مدفوعاتك، وما عليك في مكان واضح',
      actions: [
        Material(
          type: MaterialType.transparency,
          child: PopupMenuButton<_MoneySettingsAction>(
            key: const ValueKey('money-settings-menu'),
            tooltip: 'إعدادات المال',
            color: AppTheme.surface,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: const BorderSide(color: AppTheme.border),
            ),
            onSelected: (action) {
              switch (action) {
                case _MoneySettingsAction.budget:
                  onBudget();
                case _MoneySettingsAction.schedules:
                  onSchedules();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                key: ValueKey('money-settings-budget'),
                value: _MoneySettingsAction.budget,
                child: _MoneySettingsItem(
                  icon: LucideIcons.walletCards,
                  label: 'الميزانية والتصنيفات',
                ),
              ),
              PopupMenuItem(
                key: ValueKey('money-settings-schedules'),
                value: _MoneySettingsAction.schedules,
                child: _MoneySettingsItem(
                  icon: LucideIcons.calendarClock,
                  label: 'مواعيد الدفع',
                ),
              ),
            ],
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.settings2,
                size: 19,
                color: AppTheme.burgundy,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoneySettingsItem extends StatelessWidget {
  const _MoneySettingsItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.burgundy),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _MoneyCostsSection extends StatelessWidget {
  const _MoneyCostsSection({
    required this.costs,
    required this.currency,
    required this.canManage,
    required this.hasBudget,
    required this.hasMore,
    required this.categoryName,
    required this.onAdd,
    required this.onBudget,
    required this.onAll,
    required this.onOpen,
  });

  final List<WeddingCost> costs;
  final String currency;
  final bool canManage;
  final bool hasBudget;
  final bool hasMore;
  final String? Function(WeddingCost cost) categoryName;
  final VoidCallback onAdd;
  final VoidCallback onBudget;
  final VoidCallback onAll;
  final ValueChanged<WeddingCost> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'التكاليف',
          subtitle: costs.isEmpty
              ? 'سجّل كل خدمة ومبلغها في بطاقة واحدة.'
              : '${_costCountLabel(costs.length)} مسجلة في الخطة.',
          icon: LucideIcons.receipt,
        ),
        const SizedBox(height: 10),
        if (costs.isEmpty)
          AarastEmptyState(
            icon: LucideIcons.receipt,
            title: 'لا توجد تكاليف بعد',
            message: canManage
                ? 'يمكنك إضافة تكلفة الآن حتى لو لم تحدد الميزانية.'
                : 'لم تُسجل تكاليف في هذه الخطة حتى الآن.',
            action: canManage
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('money-empty-add-cost'),
                        onPressed: onAdd,
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('إضافة تكلفة'),
                      ),
                      if (!hasBudget)
                        TextButton(
                          onPressed: onBudget,
                          child: const Text('تحديد الميزانية'),
                        ),
                    ],
                  )
                : null,
          )
        else ...[
          for (var index = 0; index < costs.length; index++) ...[
            CostCard(
              key: ValueKey('money-overview-cost-${costs[index].id}'),
              cost: costs[index],
              currency: currency,
              categoryName: categoryName(costs[index]),
              onTap: () => onOpen(costs[index]),
            ),
            if (index != costs.length - 1) const SizedBox(height: 10),
          ],
          if (hasMore) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAll,
              icon: const Icon(LucideIcons.list),
              label: const Text('عرض كل التكاليف'),
            ),
          ],
        ],
        if (costs.isNotEmpty && canManage) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('money-add-cost-primary'),
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
            label: const Text('إضافة تكلفة'),
          ),
        ],
      ],
    );
  }
}

class _MoneySnapshot extends StatelessWidget {
  const _MoneySnapshot({
    required this.summary,
    required this.canManage,
    required this.onBudget,
  });

  final MoneySummary summary;
  final bool canManage;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    final remaining = moneyValue(summary.budget.remaining);
    final progress = summary.confirmedRatio.clamp(0.0, 1.0).toDouble();
    final progressColor = remaining < 0
        ? AppTheme.danger
        : summary.confirmedRatio >= .85
        ? AppTheme.gold
        : AppTheme.success;

    return Container(
      key: const ValueKey('money-dashboard-hero'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: .025),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.burgundySoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  LucideIcons.walletCards,
                  size: 17,
                  color: AppTheme.burgundy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.hasBudget
                          ? 'الميزانية الكلية'
                          : 'الميزانية غير محددة',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (summary.hasBudget)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: MoneyAmountText(
                          amount: summary.budget.total,
                          currency: summary.currency,
                          color: AppTheme.burgundyDark,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontFamily: AppTheme.displayFontFamily,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!summary.hasBudget && canManage)
                TextButton(
                  key: const ValueKey('money-budget-setup'),
                  onPressed: onBudget,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('تحديدها'),
                ),
            ],
          ),
          if (summary.hasBudget) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'نسبة استخدام الميزانية',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${(summary.confirmedRatio * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                color: progressColor,
                backgroundColor: AppTheme.border,
              ),
            ),
          ] else ...[
            const SizedBox(height: 7),
            Text(
              'حدد ميزانيتك ليظهر لك المتاح منها بوضوح.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _InlineSnapshotMetric(
                  label: 'المدفوع',
                  amount: summary.costs.paid,
                  currency: summary.currency,
                  color: AppTheme.success,
                ),
              ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppTheme.border,
              ),
              Expanded(
                child: _InlineSnapshotMetric(
                  label: summary.hasBudget
                      ? 'المتاح من الميزانية'
                      : 'إجمالي التكاليف',
                  amount: summary.hasBudget
                      ? summary.budget.remaining
                      : summary.costs.total,
                  currency: summary.currency,
                  color: summary.hasBudget && remaining < 0
                      ? AppTheme.danger
                      : AppTheme.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineSnapshotMetric extends StatelessWidget {
  const _InlineSnapshotMetric({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          maxLines: 2,
          softWrap: true,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyAmountText(
              amount: amount,
              currency: currency,
              color: color,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _NextPaymentCard extends StatelessWidget {
  const _NextPaymentCard({
    required this.schedule,
    required this.currency,
    required this.onTap,
  });

  final PaymentSchedule schedule;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOverdue = schedule.isOverdueAt(DateTime.now());
    final heading = isOverdue ? 'دفعة متأخرة' : 'موعد الدفع التالي';
    final color = isOverdue ? AppTheme.danger : AppTheme.burgundy;
    return Semantics(
      button: true,
      label: '$heading، ${schedule.costTitle ?? 'تكلفة'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('money-next-schedule-strip'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: isOverdue
                    ? AppTheme.danger.withValues(alpha: .3)
                    : AppTheme.border,
              ),
              boxShadow: AppTheme.softShadow(opacity: .035),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? AppTheme.dangerSoft
                        : AppTheme.burgundySoft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(
                    isOverdue
                        ? LucideIcons.alertTriangle
                        : LucideIcons.calendarClock,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        schedule.costTitle ?? 'تكلفة مسجلة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatArabicCompactDate(schedule.dueDate),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: MoneyAmountText(
                    amount: schedule.amount,
                    currency: currency,
                    color: color,
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.end,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  LucideIcons.chevronLeft,
                  color: AppTheme.muted,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _costCountLabel(int count) {
  return switch (count) {
    1 => 'تكلفة واحدة',
    2 => 'تكلفتان',
    >= 3 && <= 10 => '$count تكاليف',
    _ => '$count تكلفة',
  };
}
