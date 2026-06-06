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
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.warmGold.withAlpha(50),
                        child: const Icon(Icons.person, color: AppTheme.deepBurgundy),
                      ),
                      const SizedBox(width: 12),
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
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.black54),
                        onPressed: () async {
                          await context.read<AuthController>().logout();
                          if (context.mounted) context.go(AppRouter.login);
                        },
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
                      HomeAlertsCard(provider: provider),
                      const SizedBox(height: 24),
                      HomeMembersCard(provider: provider),
                      const SizedBox(height: 24),
                    ] else ...[
                      HomeQuickActions(provider: provider),
                      const SizedBox(height: 24),
                    ],
                    HomeSharedPlansCard(provider: provider),
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'الخطط'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, color: AppTheme.deepBurgundy, size: 36), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'المهام'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'المزيد'),
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
