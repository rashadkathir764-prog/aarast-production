import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/plan_status_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/account_sheet.dart';

class MyWeddingPlansScreen extends StatefulWidget {
  const MyWeddingPlansScreen({this.onSelectPlan, super.key});
  final void Function(String planId)? onSelectPlan;

  @override
  State<MyWeddingPlansScreen> createState() => _MyWeddingPlansScreenState();
}

class _MyWeddingPlansScreenState extends State<MyWeddingPlansScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = Private (خططي), 1 = Shared (المشتركة)
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openAccountSheet(AuthController auth) {
    showAccountSheet(
      context,
      name: auth.user?.name ?? 'مستخدم أعرسِت',
      phone: auth.user?.phone,
      onLogout: () async {
        await context.read<AuthController>().logout();
        if (mounted) context.go(AppRouter.login);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();
    final auth = context.watch<AuthController>();
    final textTheme = Theme.of(context).textTheme;

    return AarastScreenFrame(
      maxWidth: 560,
      safeAreaBottom: false,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: provider.loadMyWeddingPlans,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'أعرسِت',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: AppTheme.burgundyDeep,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Amiri', // Classic touch
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.favorite,
                                color: AppTheme.burgundySoft,
                                size: 14,
                              ),
                            ],
                          ),
                          Text(
                            'مساء الخير، ${auth.user?.name.split(' ').first ?? 'ضيف'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AarastPressable(
                      semanticLabel: 'فتح الحساب',
                      onTap: () => _openAccountSheet(auth),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.gold, width: 1.5),
                          color: AppTheme.surface,
                        ),
                        child: const Icon(
                          LucideIcons.user,
                          color: AppTheme.burgundy,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خططي',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppTheme.burgundyDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          color: AppTheme.gold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'خطط زفافك وشاركها مع من تحب',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSegmentedControl(textTheme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (provider.isLoading && provider.plans.isEmpty)
              SliverToBoxAdapter(
                child: AarastSkeleton.list(
                  rows: 3,
                  rowHeight: 150,
                  withHeader: false,
                  inline: true,
                ),
              )
            else if (provider.errorMessage != null && provider.plans.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: AarastErrorState(
                    title: 'تعذر تحميل خططك',
                    message: provider.errorMessage!,
                    onRetry: () => context
                        .read<WeddingPlansProvider>()
                        .loadMyWeddingPlans(),
                  ),
                ),
              )
            else if (provider.plans.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'لا توجد خطط زفاف بعد',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final plan = provider.plans[index];
                    final isFeatured =
                        index == 0 &&
                        _selectedTab == 0; // Highlight the first personal plan

                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final delay = index * 0.1;
                        final value = (_animationController.value - delay)
                            .clamp(0.0, 1.0);
                        final curve = Curves.easeOutCubic.transform(value);
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - curve)),
                          child: Opacity(
                            opacity: curve,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PlanCard(
                                plan: plan,
                                isFeatured: isFeatured,
                                onTap: () async {
                                  final active = await context
                                      .read<WeddingPlansProvider>()
                                      .setActiveWeddingPlan(plan.id);
                                  if (!context.mounted) return;
                                  if (active == null) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context
                                                    .read<
                                                      WeddingPlansProvider
                                                    >()
                                                    .errorMessage ??
                                                'تعذر فتح الخطة المختارة.',
                                          ),
                                        ),
                                      );
                                    return;
                                  }
                                  if (widget.onSelectPlan != null) {
                                    widget.onSelectPlan!(plan.id);
                                  } else {
                                    context.go(
                                      AppRouter.weddingPlanDashboard(plan.id),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }, childCount: provider.plans.length),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  120,
                ), // Padding for bottom nav
                child: _buildCreateNewPlanButton(textTheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(TextTheme textTheme) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow(opacity: 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: AarastPressable(
              clip: false,
              haptic: false,
              semanticLabel: 'عرض خططي',
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? AppTheme.burgundy
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.user,
                        color: _selectedTab == 0
                            ? Colors.white
                            : AppTheme.muted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'خططي',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: _selectedTab == 0
                                ? Colors.white
                                : AppTheme.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AarastPressable(
              clip: false,
              haptic: false,
              semanticLabel: 'عرض الخطط المشتركة',
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? AppTheme.burgundy
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.users,
                        color: _selectedTab == 1
                            ? Colors.white
                            : AppTheme.muted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'المشتركة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: _selectedTab == 1
                                ? Colors.white
                                : AppTheme.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateNewPlanButton(TextTheme textTheme) {
    return AarastCard(
      onTap: () => context.push(AppRouter.createWeddingPlan),
      padding: const EdgeInsets.all(20),
      color: AppTheme.burgundySoft.withAlpha(150),
      border: Border.all(color: AppTheme.burgundy.withAlpha(30)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنشاء خطة جديدة',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.burgundyDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ابدأ خطة زفاف جديدة وشاركها مع من تحب',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow(),
            ),
            child: const Icon(
              LucideIcons.plus,
              color: AppTheme.burgundy,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
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

    final bgColor = isFeatured ? AppTheme.burgundy : AppTheme.surface;
    final titleColor = isFeatured ? Colors.white : AppTheme.burgundyDeep;
    final subtitleColor = isFeatured ? Colors.white70 : AppTheme.muted;
    final iconColor = isFeatured ? AppTheme.gold2 : AppTheme.gold;
    final progressBgColor = isFeatured ? AppTheme.burgundyDeep : AppTheme.ivory;
    final progressFillColor = isFeatured ? AppTheme.gold : AppTheme.burgundy;
    final dividerColor = isFeatured ? Colors.white12 : AppTheme.border;
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
      padding: EdgeInsets.zero,
      color: bgColor,
      radius: AppTheme.radiusXl,
      border: isFeatured ? null : Border.all(color: AppTheme.border),
      child: Container(
        decoration: BoxDecoration(
          gradient: isFeatured ? AppTheme.heroGradient : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        ),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                child: Stack(
                  children: [
                    // Decorative background shape
                    if (isFeatured)
                      Positioned(
                        right: -40,
                        top: -40,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppTheme.burgundySoft.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isFeatured)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.burgundySoft.withAlpha(100),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.heart,
                                    color: AppTheme.burgundy,
                                    size: 20,
                                  ),
                                ),
                              if (!isFeatured) const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan.title,
                                      style: textTheme.titleLarge?.copyWith(
                                        color: titleColor,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          isFeatured
                                              ? LucideIcons.gem
                                              : LucideIcons.mapPin,
                                          color: iconColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          plan.city ?? 'غير محدد',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: subtitleColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isFeatured
                                      ? Colors.white24
                                      : AppTheme.ivory,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      planStatusLabelAr(plan.status),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: isFeatured
                                            ? Colors.white
                                            : AppTheme.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OfflinePendingBadge(
                                entityType: 'wedding_plan',
                                entityId: plan.id,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Progress Bar
                          Row(
                            children: [
                              Icon(
                                LucideIcons.calendarDays,
                                color: iconColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  daysLeft == null
                                      ? 'تاريخ الزفاف غير محدد'
                                      : daysLeft <= 0
                                      ? 'اليوم المنتظر وصل'
                                      : '$daysLeft يوم متبقية',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: subtitleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: progressBgColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(
                                              begin: 0,
                                              end: percent / 100.0,
                                            ),
                                            duration: const Duration(
                                              milliseconds: 1000,
                                            ),
                                            curve: Curves.easeOutQuart,
                                            builder: (context, value, child) {
                                              return Container(
                                                width:
                                                    constraints.maxWidth *
                                                    value,
                                                decoration: BoxDecoration(
                                                  color: progressFillColor,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$percent%',
                                style: textTheme.titleSmall?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: dividerColor),
                              ),
                              color: Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'إدارة الخطة',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_back_rounded,
                                  color: titleColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
