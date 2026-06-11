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
    final provider = context.watch<HomeDashboardProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: AppTheme.dMaroon,
                    onRefresh: () => provider.loadDashboard(),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                HomeTopHeader(
                                  userName: auth.user?.name,
                                  onLogout: () async {
                                    await context
                                        .read<AuthController>()
                                        .logout();
                                    if (context.mounted) {
                                      context.go(AppRouter.login);
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child:
                                      provider.isLoading &&
                                          provider.primaryPlan == null
                                      ? const HomeLoadingSkeleton()
                                      : _HomeDashboardBody(
                                          provider: provider,
                                          onNeedPlan: () =>
                                              _showNeedPlanSnackBar(context),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: HomeBottomNavigation(
                      provider: provider,
                      onNeedPlan: () => _showNeedPlanSnackBar(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNeedPlanSnackBar(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('أنشئي خطة أولاً')));
  }
}

class _HomeDashboardBody extends StatelessWidget {
  const _HomeDashboardBody({required this.provider, required this.onNeedPlan});

  final HomeDashboardProvider provider;
  final VoidCallback onNeedPlan;

  @override
  Widget build(BuildContext context) {
    final hasPlan = provider.primaryPlan != null;

    return Column(
      key: ValueKey(hasPlan ? provider.primaryPlan!.id : 'no-plan'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.errorMessage != null && !hasPlan) ...[
          HomeErrorCard(
            message: provider.errorMessage!,
            onRetry: provider.loadDashboard,
          ),
          const SizedBox(height: 16),
        ],
        HomeCommandHero(provider: provider),
        const SizedBox(height: 18),
        if (hasPlan) ...[
          HomeMetricsBudgetSection(provider: provider),
          const SizedBox(height: 18),
        ],
        HomeQuickActions(provider: provider, onNeedPlan: onNeedPlan),
        const SizedBox(height: 18),
        if (hasPlan) ...[
          HomeImportantNotesList(provider: provider),
          const SizedBox(height: 18),
        ],
        if (!hasPlan) ...[HomeSharedPlansCard(provider: provider)],
      ],
    );
  }
}
