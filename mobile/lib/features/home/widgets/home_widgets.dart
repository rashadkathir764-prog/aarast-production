import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/home_dashboard_provider.dart';

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _skeletonBox(height: 220),
        const SizedBox(height: 16),
        _skeletonBox(height: 132),
        const SizedBox(height: 16),
        _skeletonBox(height: 110),
      ],
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface.withAlpha(180),
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
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
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
    required this.notificationCount,
    required this.onNotifications,
    required this.onProfile,
    super.key,
  });

  final String? userName;
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
                    color: AppTheme.burgundy,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'أهلاً $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.title,
                            fontFamily: AppTheme.displayFontFamily,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'لننظم خطة زفافك معاً بهدوء وذكاء.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderCircleIcon(
          icon: LucideIcons.bell,
          badgeCount: notificationCount,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _HeaderCircleIcon(
          icon: LucideIcons.user,
          borderColor: AppTheme.gold,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _HeaderCircleIcon extends StatelessWidget {
  const _HeaderCircleIcon({
    required this.icon,
    required this.onTap,
    this.badgeCount,
    this.borderColor,
  });

  final IconData icon;
  final int? badgeCount;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor ?? AppTheme.border),
                  boxShadow: AppTheme.softShadow(opacity: 0.06),
                ),
                child: Icon(icon, color: AppTheme.gold, size: 23),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                  child: Text(
                    '$badgeCount',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.goldSoft.withAlpha(200), width: 1.2),
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
                  color: AppTheme.gold.withAlpha(25),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.ivory,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.gold.withAlpha(80)),
                      boxShadow: AppTheme.softShadow(opacity: 0.05),
                    ),
                    child: const Icon(
                      LucideIcons.heart,
                      color: AppTheme.gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'حلم زفافك يبدأ هنا',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.title,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'أنشئ خطة زفافك الأولى وسنرتب لك الميزانية والمهام والضيوف ومزوّدي الخدمات في مكان واحد.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.ivory,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Icon(
                      feature.icon,
                      color: AppTheme.burgundy,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feature.subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.muted,
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
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.burgundy,
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push(AppRouter.weddingPlans),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.burgundy,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastSectionHeader(
            title: 'الخطط المشتركة',
            icon: LucideIcons.users,
            actionLabel: 'عرض الكل',
            onAction: () => context.push(AppRouter.sharedWeddingPlans),
          ),
          const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.burgundySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.users, color: AppTheme.burgundy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
