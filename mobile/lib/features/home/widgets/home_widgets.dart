import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_header_actions.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/home_dashboard_provider.dart';
import '../../../core/experience_v3/aarast_v3_foundations.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _homeRowArtHeight = 50.0;

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _skeletonBox(height: 220),
        const SizedBox(height: AarastV3Space.x4),
        _skeletonBox(height: 132),
        const SizedBox(height: AarastV3Space.x4),
        _skeletonBox(height: 110),
      ],
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised.withAlpha(180),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
    );
  }
}

class HomeErrorCard extends StatelessWidget {
  const HomeErrorCard({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dangerSoft,
      border: Border.all(color: AppTheme.dangerSoft),
      child: Column(
        children: [
          const Icon(LucideIcons.alertCircle, color: AppTheme.danger),
          const SizedBox(height: AarastV3Space.x2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class HomeTopHeader extends StatelessWidget {
  const HomeTopHeader({
    required this.userName,
    this.avatarUrl,
    required this.notificationCount,
    required this.onNotifications,
    required this.onProfile,
    super.key,
  });

  final String? userName;
  final String? avatarUrl;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final name = (userName?.trim().isNotEmpty ?? false)
        ? userName!.trim().split(RegExp(r'\s+')).first
        : 'صاحب الخطة';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.heart,
                    color: AppTheme.brand,
                    size: 18,
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  Flexible(
                    child: Text(
                      'أهلاً $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.textPrimary,
                            fontFamily: AppTheme.displayFontFamily,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x1),
              Text(
                'لننظم خطة زفافك معاً بهدوء وذكاء.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AarastV3Space.x3),
        AarastHeaderIconAction(
          key: const ValueKey('home-notifications-action'),
          icon: LucideIcons.bell,
          label: 'التنبيهات',
          onTap: onNotifications,
          badgeCount: notificationCount,
        ),
        const SizedBox(width: AarastV3Space.x1),
        AarastHeaderAvatarAction(
          key: const ValueKey('home-profile-action'),
          userName: userName,
          avatarUrl: avatarUrl,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class HomeNoPlanWelcome extends StatelessWidget {
  const HomeNoPlanWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final features = const [
      _WelcomeFeature(
        icon: LucideIcons.wallet,
        title: 'ميزانية واضحة',
        subtitle: 'تابع تكاليفك ومواعيد دفعاتك بهدوء.',
      ),
      _WelcomeFeature(
        icon: LucideIcons.listChecks,
        title: 'مهام منظّمة',
        subtitle: 'قائمة مهام ذكية تتبع خطة الزفاف.',
      ),
      _WelcomeFeature(
        icon: LucideIcons.users,
        title: 'مشاركة العائلة',
        subtitle: 'أشرك أفراد عائلتك بصلاحيات دقيقة.',
      ),
      _WelcomeFeature(
        icon: LucideIcons.store,
        title: 'عروض مزوّدي الخدمات',
        subtitle: 'قارن الأسعار واختر بثقة.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x4,
        AarastV3Space.x5,
        AarastV3Space.x4,
        AarastV3Space.x4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppTheme.brandMuted.withAlpha(200),
          width: 1.2,
        ),
        boxShadow: AppTheme.softShadow(opacity: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Icon(
                  LucideIcons.flower2,
                  size: 160,
                  color: AppTheme.focus.withAlpha(25),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.canvas,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.focus.withAlpha(80)),
                      boxShadow: AppTheme.softShadow(opacity: 0.05),
                    ),
                    child: const Icon(
                      LucideIcons.heart,
                      color: AppTheme.focus,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Text(
                      'حلم زفافك يبدأ هنا',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
          Text(
            'أنشئ خطة زفافك الأولى وسنرتب لك الميزانية والمهام والضيوف ومزوّدي الخدمات في مكان واحد.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AarastV3Space.x4),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.canvas,
                      borderRadius: BorderRadius.circular(
                        AarastV3Radius.control,
                      ),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(feature.icon, color: AppTheme.brand, size: 16),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AarastV3Space.half),
                        Text(
                          feature.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x4),
          SizedBox(
            height: _homeRowArtHeight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                elevation: 0,
              ),
              onPressed: () => context.push(AppRouter.createWeddingPlan),
              icon: const Icon(LucideIcons.plus, size: 22),
              label: Text(
                'إنشاء خطة زفاف',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          TextButton(
            onPressed: () => context.push(AppRouter.weddingPlans),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.brand,
              minimumSize: const Size.fromHeight(40),
            ),
            child: Text(
              'عرض كل الخطط',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeFeature {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class HomeSharedPlansCard extends StatelessWidget {
  const HomeSharedPlansCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeDashboardProvider>();
    final hasSharedPlans = provider.sharedPlans.isNotEmpty;
    final firstPlan = hasSharedPlans ? provider.sharedPlans.first : null;

    return AarastCard(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x4,
        AarastV3Space.x4,
        AarastV3Space.x4,
        AarastV3Space.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastSectionHeader(
            title: 'الخطط المشتركة',
            icon: LucideIcons.users,
            actionLabel: 'عرض الكل',
            onAction: () => context.push(AppRouter.sharedWeddingPlans),
          ),
          const SizedBox(height: AarastV3Space.x3),
          if (!hasSharedPlans)
            const AarastEmptyState(
              title: 'لا توجد خطط مشتركة بعد',
              message: 'عندما يشاركك أحد أفراد العائلة خطة، ستظهر هنا.',
              icon: LucideIcons.userPlus,
            )
          else
            _SharedPlanRow(
              title: firstPlan!.title,
              subtitle: 'تم تحديثها مؤخراً',
              onTap: () => context.push(AppRouter.sharedWeddingPlans),
            ),
        ],
      ),
    );
  }
}

class _SharedPlanRow extends StatelessWidget {
  const _SharedPlanRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.brandMuted,
                borderRadius: BorderRadius.circular(AarastV3Radius.surface),
              ),
              child: const Icon(LucideIcons.users, color: AppTheme.brand),
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronLeft, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
