import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/providers/auth_controller.dart';
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';

import '../../../core/theme/app_theme.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.dMaroon,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'أعرسِت',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.dMaroonDeep,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Amiri', // Classic touch
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.favorite,
                                color: AppTheme.dPinkBg,
                                size: 14,
                              ),
                            ],
                          ),
                          Text(
                            'مساء الخير، ${auth.user?.name.split(' ').first ?? 'ضيف'}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.dInkSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _openAccountSheet(auth),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.dGold,
                              width: 1.5,
                            ),
                            color: AppTheme.dCard,
                          ),
                          child: const Icon(
                            LucideIcons.user,
                            color: AppTheme.dMaroon,
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
                          color: AppTheme.dMaroonDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.sparkles,
                            color: AppTheme.dGold,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'خطط زفافك وشاركها مع من تحب',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.dInkSoft,
                              fontWeight: FontWeight.w600,
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
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.dMaroon),
                  ),
                )
              else if (provider.errorMessage != null && provider.plans.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  ),
                )
              else if (provider.plans.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'لا توجد خطط زفاف بعد',
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppTheme.dMuted,
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
                          _selectedTab ==
                              0; // Highlight the first personal plan

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
                                  onTap: () {
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
      ),
    );
  }

  Widget _buildSegmentedControl(TextTheme textTheme) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.dLine),
        boxShadow: AppTheme.softShadow(opacity: 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? AppTheme.dMaroon
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
                            : AppTheme.dMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'خططي',
                        style: textTheme.labelLarge?.copyWith(
                          color: _selectedTab == 0
                              ? Colors.white
                              : AppTheme.dMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? AppTheme.dMaroon
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
                            : AppTheme.dMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'المشتركة',
                        style: textTheme.labelLarge?.copyWith(
                          color: _selectedTab == 1
                              ? Colors.white
                              : AppTheme.dMuted,
                          fontWeight: FontWeight.w800,
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
    return GestureDetector(
      onTap: () => context.push(AppRouter.createWeddingPlan),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.premiumCardDecoration().copyWith(
          color: AppTheme.dPinkBg.withAlpha(150),
          border: Border.all(color: AppTheme.dMaroon.withAlpha(30)),
        ),
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
                      color: AppTheme.dMaroonDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ابدأ خطة زفاف جديدة وشاركها مع من تحب',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.plus,
                color: AppTheme.dMaroon,
                size: 28,
              ),
            ),
          ],
        ),
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

    final bgColor = isFeatured ? AppTheme.dMaroon : AppTheme.dCard;
    final titleColor = isFeatured ? Colors.white : AppTheme.dMaroonDeep;
    final subtitleColor = isFeatured ? Colors.white70 : AppTheme.dInkSoft;
    final iconColor = isFeatured ? AppTheme.dGold2 : AppTheme.dGold;
    final progressBgColor = isFeatured ? AppTheme.dMaroonDeep : AppTheme.dBg;
    final progressFillColor = isFeatured ? AppTheme.dGold : AppTheme.dMaroon;
    final dividerColor = isFeatured ? Colors.white12 : AppTheme.dLine;

    // Mock progress data for visual effect
    final percent = isFeatured ? 62 : 28;
    final daysLeft = isFeatured ? 104 : 210;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          gradient: isFeatured ? AppTheme.heroGradient : null,
          boxShadow: isFeatured
              ? [
                  BoxShadow(
                    color: AppTheme.dMaroonDeep.withAlpha(60),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : AppTheme.cardShadow(),
          border: isFeatured ? null : Border.all(color: AppTheme.dLine),
        ),
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
                      color: AppTheme.dPinkBg.withAlpha(20),
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
                              color: AppTheme.dPinkBg.withAlpha(100),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.heart,
                              color: AppTheme.dMaroon,
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
                            color: isFeatured ? Colors.white24 : AppTheme.dBg,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                plan.status,
                                style: textTheme.labelSmall?.copyWith(
                                  color: isFeatured
                                      ? Colors.white
                                      : AppTheme.dInk,
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
                        Text(
                          '$daysLeft يوم متبقية',
                          style: textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w700,
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
                                          width: constraints.maxWidth * value,
                                          decoration: BoxDecoration(
                                            color: progressFillColor,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
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
                        border: Border(top: BorderSide(color: dividerColor)),
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
    );
  }
}
