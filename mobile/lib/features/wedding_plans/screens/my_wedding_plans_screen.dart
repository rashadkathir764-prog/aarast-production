import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../auth/providers/auth_controller.dart';
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';
import '../widgets/new_dashboard_widgets.dart';

class MyWeddingPlansScreen extends StatefulWidget {
  const MyWeddingPlansScreen({this.onSelectPlan, super.key});
  final void Function(String planId)? onSelectPlan;

  @override
  State<MyWeddingPlansScreen> createState() => _MyWeddingPlansScreenState();
}

class _MyWeddingPlansScreenState extends State<MyWeddingPlansScreen> {
  int _selectedTab = 0; // 0 = Shared (المشتركة), 1 = Private (خططي)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  void _openAccountSheet(AuthController auth) {
    showAccountSheet(
      context,
      name: auth.user?.name ?? 'مستخدم اعرست',
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

    return Scaffold(
      backgroundColor: DashboardUiColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: DashboardUiColors.primaryMaroon,
          onRefresh: provider.loadMyWeddingPlans,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              NewDashboardTopHeader(
                userName: auth.user?.name ?? 'ضيف',
                onProfile: () => _openAccountSheet(auth),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('خططي', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: DashboardUiColors.primaryMaroon)),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: DashboardUiColors.heroGold, size: 16),
                        const SizedBox(width: 6),
                        Text('خطط زفافك وشاركها مع من تحب', style: TextStyle(color: DashboardUiColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSegmentedControl(),
                    const SizedBox(height: 24),
                    _buildPlansList(provider),
                    const SizedBox(height: 16),
                    _buildCreateNewPlanButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DashboardUiColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? DashboardUiColors.primaryMaroon : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_outlined, color: _selectedTab == 0 ? Colors.white : DashboardUiColors.textGray, size: 18),
                      const SizedBox(width: 8),
                      Text('المشتركة', style: TextStyle(color: _selectedTab == 0 ? Colors.white : DashboardUiColors.textGray, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? DashboardUiColors.primaryMaroon : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, color: _selectedTab == 1 ? Colors.white : DashboardUiColors.textGray, size: 18),
                      const SizedBox(width: 8),
                      Text('خططي', style: TextStyle(color: _selectedTab == 1 ? Colors.white : DashboardUiColors.textGray, fontWeight: FontWeight.w700)),
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

  Widget _buildPlansList(WeddingPlansProvider provider) {
    if (provider.isLoading && provider.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: DashboardUiColors.primaryMaroon));
    }
    if (provider.errorMessage != null && provider.plans.isEmpty) {
      return Center(child: Text(provider.errorMessage!, style: const TextStyle(color: DashboardUiColors.iconRed)));
    }
    
    if (provider.plans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('لا توجد خطط زفاف بعد', style: TextStyle(color: DashboardUiColors.textGray))),
      );
    }

    return Column(
      children: List.generate(provider.plans.length, (index) {
        final plan = provider.plans[index];
        final isFeatured = index == 0 && _selectedTab == 0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _PlanCard(
            plan: plan,
            isFeatured: isFeatured,
            onTap: () {
              if (widget.onSelectPlan != null) {
                widget.onSelectPlan!(plan.id);
              } else {
                context.go(AppRouter.weddingPlanDashboard(plan.id));
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildCreateNewPlanButton() {
    return GestureDetector(
      onTap: () => context.push(AppRouter.createWeddingPlan),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DashboardUiColors.primaryMaroon.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DashboardUiColors.primaryMaroon.withAlpha(50), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إنشاء خطة جديدة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DashboardUiColors.primaryMaroon)),
                  const SizedBox(height: 4),
                  Text('ابدأ خطة زفاف جديدة وشاركها مع من تحب', style: TextStyle(fontSize: 12, color: DashboardUiColors.textGray.withAlpha(200))),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: DashboardUiColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: DashboardUiColors.primaryMaroon, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.isFeatured, required this.onTap});

  final WeddingPlan plan;
  final bool isFeatured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isFeatured ? DashboardUiColors.primaryMaroon : Colors.white;
    final titleColor = isFeatured ? Colors.white : DashboardUiColors.primaryMaroon;
    final subtitleColor = isFeatured ? Colors.white70 : DashboardUiColors.textGray;
    final iconColor = isFeatured ? DashboardUiColors.heroGoldLight : DashboardUiColors.heroGold;
    final progressBgColor = isFeatured ? DashboardUiColors.heroMaroonDark : DashboardUiColors.background;
    final progressFillColor = isFeatured ? DashboardUiColors.heroGoldLight : DashboardUiColors.primaryMaroon;
    final dividerColor = isFeatured ? Colors.white12 : DashboardUiColors.borderLight;
    
    // Mock values
    final percent = isFeatured ? 62 : 28;
    final daysLeft = isFeatured ? 104 : 210;
    final guests = isFeatured ? 12 : 8;
    final doneTasks = isFeatured ? 16 : 7;
    final totalTasks = isFeatured ? 26 : 25;
    final budgetTotal = isFeatured ? '10,000,000 ر.ع' : '4,250,000 ر.ع';
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          gradient: isFeatured ? const LinearGradient(
            colors: [DashboardUiColors.primaryMaroon, DashboardUiColors.heroMaroonDark],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ) : null,
          boxShadow: [
            BoxShadow(color: isFeatured ? DashboardUiColors.primaryMaroon.withAlpha(40) : Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Tags and Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Right Side: Title
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isFeatured) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: DashboardUiColors.primaryMaroon.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.favorite_border, color: DashboardUiColors.primaryMaroon, size: 20),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(plan.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: titleColor)),
                                  if (isFeatured) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.diamond_outlined, color: iconColor, size: 18),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(isFeatured ? Icons.people_alt_outlined : Icons.person_outline, color: subtitleColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(isFeatured ? 'خطة مشتركة' : 'خطة شخصية', style: TextStyle(color: subtitleColor, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Left Side: Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFeatured ? DashboardUiColors.heroGoldLight.withAlpha(30) : DashboardUiColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(isFeatured ? 'الخطة المميزة' : 'قيد التنفيذ', style: TextStyle(color: isFeatured ? DashboardUiColors.heroGoldLight : DashboardUiColors.textDark, fontSize: 10, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            Icon(isFeatured ? Icons.star : Icons.circle, color: isFeatured ? DashboardUiColors.heroGoldLight : DashboardUiColors.heroGold, size: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Last Update & Avatars (RTL swap: Last Update Right, Avatars Left)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Last Update (Right)
                      Row(
                        children: [
                          Icon(Icons.access_time, color: subtitleColor, size: 12),
                          const SizedBox(width: 4),
                          Text('آخر تحديث: ${isFeatured ? 'اليوم، 9:20 م' : 'أمس، 11:45 ص'}', style: TextStyle(color: subtitleColor, fontSize: 11)),
                        ],
                      ),
                      // Avatars (Left)
                      Row(
                        children: [
                          if (isFeatured) ...[
                            _buildAvatarOverlap(0, 'https://i.pravatar.cc/100?img=1', bgColor),
                            _buildAvatarOverlap(1, 'https://i.pravatar.cc/100?img=2', bgColor),
                            _buildAvatarOverlap(2, 'https://i.pravatar.cc/100?img=3', bgColor),
                            Container(
                              width: 28, height: 28,
                              transform: Matrix4.translationValues(3 * 10.0, 0, 0),
                              decoration: BoxDecoration(color: DashboardUiColors.primaryMaroon.withAlpha(20), shape: BoxShape.circle, border: Border.all(color: bgColor, width: 2)),
                              child: const Center(child: Text('+4', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                            ),
                          ] else ...[
                            _buildAvatarOverlap(0, 'https://i.pravatar.cc/100?img=4', bgColor),
                            _buildAvatarOverlap(1, 'https://i.pravatar.cc/100?img=5', bgColor),
                            Container(
                              width: 28, height: 28,
                              transform: Matrix4.translationValues(2 * 10.0, 0, 0),
                              decoration: BoxDecoration(color: DashboardUiColors.background, shape: BoxShape.circle, border: Border.all(color: bgColor, width: 2)),
                              child: const Center(child: Icon(Icons.add, color: DashboardUiColors.textGray, size: 14)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress Bar (RTL swap: Days Right, Bar Middle, Percentage Left)
                  Row(
                    children: [
                      // Days (Right)
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: iconColor, size: 14),
                          const SizedBox(width: 4),
                          Text('$daysLeft يوم متبقية', style: TextStyle(color: subtitleColor, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Bar (Middle)
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(color: progressBgColor, borderRadius: BorderRadius.circular(3)),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerRight,
                            widthFactor: percent / 100.0,
                            child: Container(
                              decoration: BoxDecoration(color: progressFillColor, borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Percentage (Left)
                      Row(
                        children: [
                          Text('مكتمل', style: TextStyle(color: titleColor, fontSize: 12)),
                          const SizedBox(width: 4),
                          Text('$percent%', style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w800), textDirection: TextDirection.ltr),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom Grid (3 items)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: dividerColor),
                  bottom: BorderSide(color: dividerColor),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: iconColor, size: 16),
                            const SizedBox(width: 4),
                            Text(budgetTotal, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w800), textDirection: TextDirection.rtl),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('الميزانية المتوقعة', style: TextStyle(color: subtitleColor, fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: dividerColor),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.checklist_rtl_rounded, color: iconColor, size: 16),
                            const SizedBox(width: 4),
                            Text('$doneTasks/$totalTasks', style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w800), textDirection: TextDirection.ltr),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('المهام', style: TextStyle(color: subtitleColor, fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: dividerColor),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, color: iconColor, size: 16),
                            const SizedBox(width: 4),
                            Text('$guests', style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('ضيوف مدعوون', style: TextStyle(color: subtitleColor, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  Text('عرض تفاصيل الخطة', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w700)),
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.chevron_left, color: subtitleColor, size: 16))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarOverlap(int index, String url, Color bgColor) {
    return Container(
      width: 28,
      height: 28,
      transform: Matrix4.translationValues(index * 10.0, 0, 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: bgColor, width: 2),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
    );
  }
}
