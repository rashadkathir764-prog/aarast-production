import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';
import '../../sharing/models/shared_member.dart';
import '../providers/dashboard_summary_provider.dart';
import '../widgets/aarast_dashboard_widgets.dart';
import '../widgets/new_dashboard_widgets.dart';

class WeddingPlanDashboardScreen extends StatefulWidget {
  const WeddingPlanDashboardScreen({
    required this.weddingPlanId,
    this.sharedMember,
    this.embedded = false,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

  /// When hosted inside the [MainShell] tab stack, the shell owns the bottom
  /// navigation, so the screen hides its own and lets detail pages push over
  /// the persistent shell.
  final bool embedded;

  @override
  State<WeddingPlanDashboardScreen> createState() =>
      _WeddingPlanDashboardScreenState();
}

class _WeddingPlanDashboardScreenState
    extends State<WeddingPlanDashboardScreen> {
  /// Fixed design width of the reference dashboard handoff. The whole canvas is
  /// laid out at this width and uniformly scaled to the viewport via [FittedBox],
  /// so every size matches the maquette on any screen. Height is intrinsic (no
  /// fixed height) so the content can never RenderFlex-overflow.
  static const double _dashboardDesignWidth = 680;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardSummaryProvider>().loadDashboard(
        widget.weddingPlanId,
      );
    });
  }

  @override
  void didUpdateWidget(covariant WeddingPlanDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DashboardSummaryProvider>().loadDashboard(
          widget.weddingPlanId,
        );
      });
    }
  }

  void _comingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardSummaryProvider>();
    final auth = context.watch<AuthController>();

    // Apply the design's Tajawal type scale over the dashboard subtree, and
    // guarantee RTL regardless of the host locale.
    final theme = Theme.of(context);
    final dashboardTheme = theme.copyWith(
      textTheme: GoogleFonts.tajawalTextTheme(theme.textTheme),
    );

    return Theme(
      data: dashboardTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.dBg,
          bottomNavigationBar: widget.embedded
              ? null
              : _buildBottomNav(provider),
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppTheme.dMaroon,
              onRefresh: () => provider.loadDashboard(widget.weddingPlanId),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildContent(context, provider, auth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DashboardBottomNav _buildBottomNav(DashboardSummaryProvider provider) {
    final planId = provider.plan?.id ?? widget.weddingPlanId;
    return DashboardBottomNav(
      onMore: () => _comingSoon('قسم "المزيد" قيد الإعداد'),
      onTasks: () => context.go(AppRouter.tasks(planId)),
      onAdd: () => _showQuickAdd(provider),
      onPlans: () => context.go(AppRouter.weddingPlans),
      onHome: () => context.go(AppRouter.home),
    );
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

  Widget _buildContent(
    BuildContext context,
    DashboardSummaryProvider provider,
    AuthController auth,
  ) {
    if (provider.isLoading && provider.plan == null) {
      return const DashboardSkeleton(key: ValueKey('skeleton'));
    }

    if (provider.errorMessage != null && provider.plan == null) {
      return ListView(
        key: const ValueKey('error'),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.dMaroon),
              onPressed: () => provider.loadDashboard(widget.weddingPlanId),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final plan = provider.plan;
    if (plan == null) {
      return ListView(
        key: const ValueKey('empty'),
        children: const [
          SizedBox(height: 120),
          Text('لم يتم العثور على خطة الزفاف.', textAlign: TextAlign.center),
        ],
      );
    }

    return _scaledDashboardCanvas(
      key: const ValueKey('content'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardTopBar(
            userName: auth.user?.name ?? 'ضيف',
            onProfile: () => _openAccountSheet(auth),
            onNotifications: () => _comingSoon('مركز التنبيهات قيد الإعداد'),
          ),
          _padded(NewDashboardHeroCard(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardMetricsBudgetSection(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardQuickActions(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardAlertsMembersGrid(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardSharedPlansCard(provider: provider)),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _scaledDashboardCanvas({required Key key, required Widget child}) {
    // Lay the whole dashboard out at the fixed design width and let height be
    // intrinsic, then uniformly down-scale to the viewport. BoxFit.contain on a
    // width-bounded / height-unbounded box scales by viewportWidth / designWidth,
    // so the maquette renders identically (just smaller) on every size and the
    // inner Column can never overflow.
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _dashboardDesignWidth,
              ),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: _dashboardDesignWidth,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );


  void _showQuickAdd(DashboardSummaryProvider provider) {
    final plan = provider.plan;
    if (plan == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.dCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Widget tile(
          IconData icon,
          Color color,
          Color bg,
          String label,
          String route,
        ) {
          return ListTile(
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(route);
            },
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.dInk,
              ),
            ),
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'إضافة سريعة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dInk,
                        ),
                      ),
                    ),
                  ),
                  tile(
                    Icons.account_balance_wallet_outlined,
                    AppTheme.dMaroon,
                    AppTheme.dPinkBg,
                    'إضافة مصروف',
                    AppRouter.finance(plan.id),
                  ),
                  tile(
                    Icons.credit_card_rounded,
                    AppTheme.dMaroon,
                    AppTheme.dPinkBg,
                    'إضافة دين',
                    AppRouter.debts(plan.id),
                  ),
                  tile(
                    Icons.check_circle_outline_rounded,
                    AppTheme.dGreen,
                    AppTheme.dGreenBg,
                    'إضافة مهمة',
                    AppRouter.tasks(plan.id),
                  ),
                  tile(
                    Icons.post_add_rounded,
                    AppTheme.dGoldDeep,
                    AppTheme.dCreamBg,
                    'خطة جديدة',
                    AppRouter.createWeddingPlan,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}
