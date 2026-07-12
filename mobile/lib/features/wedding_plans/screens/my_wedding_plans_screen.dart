import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/plan_status_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';

class MyWeddingPlansScreen extends StatefulWidget {
  const MyWeddingPlansScreen({this.onSelectPlan, super.key});
  final void Function(String planId)? onSelectPlan;

  @override
  State<MyWeddingPlansScreen> createState() => _MyWeddingPlansScreenState();
}

class _MyWeddingPlansScreenState extends State<MyWeddingPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPlans();
    });
  }

  Future<void> _loadPlans() async {
    final provider = context.read<WeddingPlansProvider>();
    await provider.loadActiveWeddingPlan();
    if (!mounted) return;
    await provider.loadMyWeddingPlans();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();

    return AarastPageScaffold(
      title: 'خططي',
      subtitle: 'كل خطط زفافك في مكان واحد',
      showBack: true,
      safeAreaBottom: false,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: _loadPlans,
        child: _PlansContent(
          provider: provider,
          activePlanId: provider.activePlan?.id,
          onOpenPlan: _openPlan,
        ),
      ),
    );
  }

  Future<void> _openPlan(WeddingPlan plan) async {
    final active = await context
        .read<WeddingPlansProvider>()
        .setActiveWeddingPlan(plan.id);
    if (!mounted) return;
    if (active == null) {
      AarastToast.showError(
        context,
        context.read<WeddingPlansProvider>().errorMessage ??
            'تعذر فتح الخطة المختارة.',
      );
      return;
    }
    if (widget.onSelectPlan != null) {
      widget.onSelectPlan!(plan.id);
    } else {
      context.go(AppRouter.weddingPlanDashboard(plan.id));
    }
  }
}

class _PlansContent extends StatelessWidget {
  const _PlansContent({
    required this.provider,
    required this.activePlanId,
    required this.onOpenPlan,
  });

  final WeddingPlansProvider provider;
  final String? activePlanId;
  final ValueChanged<WeddingPlan> onOpenPlan;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.plans.isEmpty) {
      return AarastSkeleton.list(rows: 3, rowHeight: 120, withHeader: false);
    }

    if (provider.errorMessage != null && provider.plans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          AarastErrorState(
            title: 'تعذر تحميل خططك',
            message: provider.errorMessage!,
            onRetry: provider.loadMyWeddingPlans,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: AarastStagger.children(context, [
        if (provider.plans.isEmpty)
          const AarastEmptyState(
            title: 'لا توجد خطط زفاف بعد',
            message: 'أنشئ خطتك الأولى وابدأ الترتيب بهدوء.',
            icon: LucideIcons.calendarHeart,
          )
        else
          for (var i = 0; i < provider.plans.length; i++)
            _PlanCard(
              key: Key('wedding-plan-card-${provider.plans[i].id}'),
              plan: provider.plans[i],
              isFeatured: provider.plans[i].id == activePlanId,
              onTap: () => onOpenPlan(provider.plans[i]),
            ),
        const SizedBox(height: 10),
        AarastButton(
          label: 'إنشاء خطة جديدة',
          icon: LucideIcons.plus,
          onPressed: () => context.push(AppRouter.createWeddingPlan),
        ),
        const SizedBox(height: 10),
        _SharedPlansLink(
          onTap: () => context.push(AppRouter.sharedWeddingPlans),
        ),
      ]),
    );
  }
}

/// بديل صادق لتبويب «المشتركة» القديم الذي لم يكن يعمل أصلًا —
/// رابط هادئ يفتح شاشة الخطط المشتركة الحقيقية.
class _SharedPlansLink extends StatelessWidget {
  const _SharedPlansLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      onTap: onTap,
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.burgundySoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              LucideIcons.users,
              color: AppTheme.burgundy,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'الخطط المشتركة معي',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronLeft, color: AppTheme.muted, size: 18),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.plan,
    required this.isFeatured,
    required this.onTap,
  });

  final WeddingPlan plan;
  final bool isFeatured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final titleColor = isFeatured ? Colors.white : AppTheme.burgundyDeep;
    final subtitleColor = isFeatured ? Colors.white70 : AppTheme.muted;
    final iconColor = isFeatured ? AppTheme.gold2 : AppTheme.gold;
    final progressBgColor = isFeatured ? AppTheme.burgundyDeep : AppTheme.ivory;
    final progressFillColor = isFeatured ? AppTheme.gold : AppTheme.burgundy;
    final daysLeft = plan.daysRemaining;
    final totalPlanningDays = plan.weddingDate
        ?.difference(plan.createdAt)
        .inDays;
    final percent =
        daysLeft == null || totalPlanningDays == null || totalPlanningDays <= 0
        ? 0
        : (((totalPlanningDays - daysLeft).clamp(0, totalPlanningDays) /
                      totalPlanningDays) *
                  100)
              .round();

    return AarastCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      color: isFeatured ? AppTheme.burgundy : AppTheme.surface,
      radius: AppTheme.radiusLg,
      border: isFeatured ? null : Border.all(color: AppTheme.border),
      child: Container(
        decoration: BoxDecoration(
          gradient: isFeatured ? AppTheme.heroGradient : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(LucideIcons.mapPin, color: iconColor, size: 13),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              plan.city ?? 'بدون مدينة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: subtitleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isFeatured ? Colors.white24 : AppTheme.ivory,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isFeatured
                        ? 'الخطة الحالية'
                        : planStatusLabelAr(plan.status),
                    maxLines: 1,
                    style: textTheme.labelSmall?.copyWith(
                      color: isFeatured ? Colors.white : AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                OfflinePendingBadge(
                  entityType: 'wedding_plan',
                  entityId: plan.id,
                ),
                const SizedBox(width: 2),
                Icon(LucideIcons.chevronLeft, color: subtitleColor, size: 16),
              ],
            ),
            if (daysLeft != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LucideIcons.calendarDays, color: iconColor, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    daysLeft <= 0 ? 'اليوم المنتظر وصل' : '$daysLeft يوم متبقي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: percent / 100.0),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: progressBgColor,
                          valueColor: AlwaysStoppedAnimation(progressFillColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    style: textTheme.labelSmall?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
