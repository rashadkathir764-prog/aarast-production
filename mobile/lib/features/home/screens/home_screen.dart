import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../providers/home_dashboard_provider.dart';
import '../widgets/home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeDashboardProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final provider = context.watch<HomeDashboardProvider>();

    return Scaffold(
      backgroundColor: AppTheme.ivory,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadDashboard(),
          color: AppTheme.deepBurgundy,
          child: CustomScrollView(
            slivers: [
              // Top App Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'أهلاً ${user?.name ?? ''}',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: AppTheme.deepBurgundy,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                const Text('👋', style: TextStyle(fontSize: 18)),
                              ],
                            ),
                            const Text(
                              'هذه لمحة سريعة عن تجهيزات زفافك',
                              style: TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          const Text('أعرست', style: TextStyle(color: AppTheme.deepBurgundy, fontWeight: FontWeight.bold, fontSize: 16)),
                          const Icon(Icons.diamond_outlined, color: AppTheme.warmGold, size: 24),
                        ],
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none, color: AppTheme.deepBurgundy),
                              onPressed: () {},
                            ),
                            InkWell(
                              onTap: () async {
                                await context.read<AuthController>().logout();
                                if (context.mounted) context.go(AppRouter.login);
                              },
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.warmGold.withAlpha(50),
                                child: const Icon(Icons.person, color: AppTheme.deepBurgundy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Loading State or Dashboard Content
              if (provider.isLoading && provider.primaryPlan == null)
                const SliverFillRemaining(
                  child: HomeLoadingSkeleton(),
                )
              else if (provider.errorMessage != null && provider.primaryPlan == null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(provider.errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.loadDashboard(),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    HomeCommandHero(provider: provider),
                    const SizedBox(height: 24),
                    if (provider.primaryPlan != null) ...[
                      HomeMetricGrid(provider: provider),
                      const SizedBox(height: 24),
                      HomeQuickActions(provider: provider),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Right column (Members & Shared) - flex 1. In RTL, index 0 is Right.
                            Expanded(
                              child: Column(
                                children: [
                                  HomeMembersCard(provider: provider),
                                  const SizedBox(height: 24),
                                  HomeSharedPlansCard(provider: provider),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Left column (Alerts) - flex 1
                            Expanded(
                              child: HomeAlertsCard(provider: provider),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      HomeQuickActions(provider: provider),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: HomeSharedPlansCard(provider: provider),
                      ),
                    ],
                    const SizedBox(height: 40), // Bottom padding
                  ]),
                ),
            ],
          ),
        ),
      ),
      // Bottom Navigation placeholder to match visual reference if needed
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppTheme.deepBurgundy,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'الخطط'),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.deepBurgundy,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'المهام'),
          const BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'المزيد'),
        ],
        onTap: (index) {
          if (index == 1) context.go(AppRouter.weddingPlans);
          if (index == 3 && provider.primaryPlan != null) {
            context.go(AppRouter.weddingPlanDashboard(provider.primaryPlan!.id));
          }
        },
      ),
    );
  }
}
