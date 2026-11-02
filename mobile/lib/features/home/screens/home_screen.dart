import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../../notifications/notifications_api.dart' show NotificationsProvider;
import '../providers/home_dashboard_provider.dart';
import '../widgets/home_widgets.dart';
import '../../../core/experience_v3/aarast_v3_foundations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeDashboardProvider>().loadDashboard();
      _maybeReadNotifications(context)?.loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final provider = context.watch<HomeDashboardProvider>();
    final notifications = _maybeWatchNotifications(context);

    return AarastScreenFrame(
      maxWidth: 480,
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: () => provider.loadDashboard(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AarastV3Space.x4,
            AarastV3Space.x4,
            AarastV3Space.x4,
            widget.embedded ? AarastV3Space.x6 : AarastV3Space.x8,
          ),
          children: [
            HomeTopHeader(
              userName: auth.user?.name,
              avatarUrl: auth.user?.avatarUrl,
              notificationCount: notifications?.unreadCount ?? 0,
              onNotifications: () {
                context.push(AppRouter.notifications);
              },
              onProfile: () => context.push(AppRouter.more),
            ),
            const SizedBox(height: AarastV3Space.x4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _buildContent(provider),
            ),
            const SizedBox(height: AarastV3Space.x4),
            if (!widget.embedded) const HomeSharedPlansCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(HomeDashboardProvider provider) {
    if (provider.errorMessage != null) {
      return KeyedSubtree(
        key: const ValueKey('home-error'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeErrorCard(
              message: provider.errorMessage!,
              onRetry: provider.loadDashboard,
            ),
            const SizedBox(height: AarastV3Space.x4),
            const HomeNoPlanWelcome(),
          ],
        ),
      );
    }
    if (provider.isLoading && provider.primaryPlan == null) {
      return const KeyedSubtree(
        key: ValueKey('home-skeleton'),
        child: HomeLoadingSkeleton(),
      );
    }
    return const KeyedSubtree(
      key: ValueKey('home-welcome'),
      child: HomeNoPlanWelcome(),
    );
  }
}

NotificationsProvider? _maybeReadNotifications(BuildContext context) {
  try {
    return context.read<NotificationsProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}

NotificationsProvider? _maybeWatchNotifications(BuildContext context) {
  try {
    return context.watch<NotificationsProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}
