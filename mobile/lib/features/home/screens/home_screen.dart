import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../../wedding_plans/models/wedding_plan.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../../wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import '../../wedding_plans/widgets/aarast_dashboard_widgets.dart';

/// The home landing is the command-center dashboard for the user's primary
/// wedding plan. If no plan exists yet, an on-brand empty state is shown.
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
      context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  WeddingPlan? _primaryPlan(WeddingPlansProvider plans, AuthController auth) {
    if (plans.plans.isEmpty) return null;
    final userId = auth.user?.id;
    for (final plan in plans.plans) {
      if (plan.ownerUserId == userId) return plan;
    }
    return plans.plans.first;
  }

  void _logout() async {
    await context.read<AuthController>().logout();
    if (mounted) context.go(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final plansProvider = context.watch<WeddingPlansProvider>();
    final auth = context.watch<AuthController>();

    final primary = _primaryPlan(plansProvider, auth);
    if (primary != null) {
      // Render the full dashboard for the primary plan, in place, at /home.
      return WeddingPlanDashboardScreen(
        key: ValueKey('home-${primary.id}'),
        weddingPlanId: primary.id,
      );
    }

    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.dBg,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppTheme.dMaroon,
              onRefresh: () => plansProvider.loadMyWeddingPlans(),
              child: _fallback(plansProvider, auth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(WeddingPlansProvider plans, AuthController auth) {
    if (plans.isLoading && plans.plans.isEmpty) {
      return const DashboardSkeleton();
    }

    if (plans.errorMessage != null && plans.plans.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 140),
          Text(
            plans.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.dMaroon),
              onPressed: () => plans.loadMyWeddingPlans(),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    // No plan yet — welcoming empty state with a create CTA.
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        DashboardTopBar(
          userName: auth.user?.name ?? 'ضيف',
          onProfile: () => showAccountSheet(
            context,
            name: auth.user?.name ?? 'مستخدم اعرست',
            phone: auth.user?.phone,
            onLogout: _logout,
          ),
          hasNotificationDot: false,
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
            decoration: BoxDecoration(
              color: AppTheme.dCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withValues(alpha: 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppTheme.dPinkBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.dMaroon,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'لا توجد خطة زفاف بعد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ابدأ بخطة واحدة تجمع التاريخ والمدينة والميزانية التقديرية، '
                  'ثم تابع كل تجهيزات زفافك من هنا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: AppTheme.dInkSoft,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => context.go(AppRouter.createWeddingPlan),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إنشاء خطة زفاف'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go(AppRouter.sharedWeddingPlans),
                  child: const Text(
                    'الخطط المشتركة معي',
                    style: TextStyle(
                      color: AppTheme.dMaroon,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
