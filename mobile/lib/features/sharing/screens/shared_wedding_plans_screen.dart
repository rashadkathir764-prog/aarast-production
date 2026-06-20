import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/sharing_provider.dart';
import '../widgets/shared_plan_card.dart';

class SharedWeddingPlansScreen extends StatefulWidget {
  const SharedWeddingPlansScreen({super.key});

  @override
  State<SharedWeddingPlansScreen> createState() =>
      _SharedWeddingPlansScreenState();
}

class _SharedWeddingPlansScreenState extends State<SharedWeddingPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SharingProvider>().loadSharedPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();

    return AarastPageScaffold(
      title: 'الخطط المشتركة معي',
      subtitle: 'الخطط التي منحك أصحابها صلاحية الوصول إليها',
      showBack: true,
      child: RefreshIndicator(
        color: AppTheme.dMaroon,
        onRefresh: provider.loadSharedPlans,
        child: _SharedPlansContent(provider: provider),
      ),
    );
  }
}

class _SharedPlansContent extends StatelessWidget {
  const _SharedPlansContent({required this.provider});

  final SharingProvider provider;

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: provider.loadSharedPlans,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    if (provider.sharedPlans.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 70),
          AarastEmptyState(
            icon: Icons.diversity_3_outlined,
            title: 'لا توجد خطط مشتركة',
            message: 'ستظهر هنا الخطط التي يشاركها أصحابها معك.',
          ),
        ],
      );
    }

    return ListView(
      children: [
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
            onTap: () => context.push(
              AppRouter.weddingPlanDashboard(plan.id),
              extra: plan.sharedMember,
            ),
          ),
      ],
    );
  }
}
