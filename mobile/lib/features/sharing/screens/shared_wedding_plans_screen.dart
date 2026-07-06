import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../providers/sharing_provider.dart';
import '../widgets/shared_plan_card.dart';

class SharedWeddingPlansScreen extends StatefulWidget {
  const SharedWeddingPlansScreen({super.key});

  @override
  State<SharedWeddingPlansScreen> createState() =>
      _SharedWeddingPlansScreenState();
}

class _SharedWeddingPlansScreenState extends State<SharedWeddingPlansScreen> {
  bool _isCheckingAccount = true;
  bool _showLoginGate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshAccountAndLoad();
    });
  }

  Future<void> _refreshAccountAndLoad() async {
    setState(() {
      _isCheckingAccount = true;
      _showLoginGate = false;
    });

    final shouldGate = await AuthActionGuard.shouldGateAccountOnly(context);
    if (!mounted) return;

    setState(() {
      _isCheckingAccount = false;
      _showLoginGate = shouldGate;
    });

    if (!shouldGate) {
      await context.read<SharingProvider>().loadSharedPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();

    return AarastPageScaffold(
      title: 'الخطط المشتركة معي',
      subtitle: 'الخطط التي منحك أصحابها صلاحية الوصول إليها',
      showBack: true,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () {
          if (_showLoginGate ||
              provider.authGateKind == SharingAuthGateKind.sessionExpired) {
            return Future<void>.value();
          }
          return provider.loadSharedPlans();
        },
        child: _SharedPlansContent(
          provider: provider,
          isCheckingAccount: _isCheckingAccount,
          showLoginGate: _showLoginGate,
        ),
      ),
    );
  }
}

class _SharedPlansContent extends StatelessWidget {
  const _SharedPlansContent({
    required this.provider,
    required this.isCheckingAccount,
    required this.showLoginGate,
  });

  final SharingProvider provider;
  final bool isCheckingAccount;
  final bool showLoginGate;

  @override
  Widget build(BuildContext context) {
    if (isCheckingAccount) {
      return const Center(child: CircularProgressIndicator());
    }

    if (showLoginGate) {
      return const AuthGatePanel(
        title: AuthActionGuard.sharingLoginGateTitle,
        body: AuthActionGuard.sharingLoginGateBody,
        icon: LucideIcons.users,
      );
    }

    if (provider.authGateKind == SharingAuthGateKind.sessionExpired) {
      return const AuthGatePanel(
        title: AuthActionGuard.sessionExpiredTitle,
        body: AuthActionGuard.sharingSessionExpiredBody,
        icon: LucideIcons.fileClock,
      );
    }

    if (provider.isLoading && provider.sharedPlans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.sharedPlans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          AarastButton(
            label: 'إعادة المحاولة',
            icon: LucideIcons.refreshCw,
            onPressed: provider.loadSharedPlans,
          ),
        ],
      );
    }

    if (provider.sharedPlans.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 70),
          AarastEmptyState(
            icon: LucideIcons.users,
            title: 'لا توجد خطط مشتركة',
            message: 'ستظهر هنا الخطط التي يشاركها أصحابها معك.',
          ),
        ],
      );
    }

    return ListView(
      children: [
        AarastCard(
          color: AppTheme.ivory,
          child: Row(
            children: [
              const Icon(LucideIcons.users, color: AppTheme.burgundy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${provider.sharedPlans.length} خطة مشتركة معك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.deepBurgundy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'هذه الخطط ظهرت لك بصلاحيات محددة من مالك الخطة.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumGray),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        for (final plan in provider.sharedPlans)
          SharedPlanCard(
            plan: plan,
            onTap: () => context.go(
              AppRouter.weddingPlanDashboard(plan.id),
              extra: plan.sharedMember,
            ),
          ),
      ],
    );
  }
}
