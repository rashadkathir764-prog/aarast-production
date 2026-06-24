import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        color: AppTheme.dCard2.withAlpha(180),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
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
      color: AppTheme.dPinkBg.withAlpha(210),
      border: Border.all(color: AppTheme.danger.withAlpha(70)),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
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
            icon: const Icon(Icons.refresh_rounded),
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
                    Icons.favorite_rounded,
                    color: AppTheme.dMaroon,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'أهلاً $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.dInk,
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
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeaderCircleIcon(
          icon: Icons.notifications_none_rounded,
          badgeCount: notificationCount,
          onTap: onNotifications,
        ),
        const SizedBox(width: 10),
        _HeaderCircleIcon(
          icon: Icons.person_outline_rounded,
          borderColor: AppTheme.dGold2,
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
                  color: AppTheme.dCard2,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor ?? AppTheme.dLine),
                  boxShadow: AppTheme.softShadow(opacity: 0.04),
                ),
                child: Icon(icon, color: AppTheme.dMaroon, size: 23),
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
                    color: AppTheme.dMaroon,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.dCard2, width: 2),
                  ),
                  child: Text(
                    '$badgeCount',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
        icon: Icons.account_balance_wallet_outlined,
        title: 'ميزانية واضحة',
        subtitle: 'تابع مصاريفك وأقساطك بهدوء.',
      ),
      _WelcomeFeature(
        icon: Icons.checklist_rounded,
        title: 'مهام منظّمة',
        subtitle: 'قائمة مهام ذكية تتبع خطة الزفاف.',
      ),
      _WelcomeFeature(
        icon: Icons.groups_rounded,
        title: 'مشاركة العائلة',
        subtitle: 'أشرك أفراد عائلتك بصلاحيات دقيقة.',
      ),
      _WelcomeFeature(
        icon: Icons.storefront_rounded,
        title: 'عروض مزوّدي الخدمات',
        subtitle: 'قارن الأسعار واختر بثقة.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF800020), Color(0xFF5E0F1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroon.withAlpha(70),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.dGold2.withAlpha(38),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.dGold2.withAlpha(180)),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppTheme.dGold2,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'حلم زفافك يبدأ هنا',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'أنشئ خطة زفافك الأولى وسنرتب لك الميزانية والمهام والضيوف ومزوّدي الخدمات في مكان واحد.',
            style: TextStyle(
              color: Colors.white.withAlpha(225),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppTheme.dGold2.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature.icon,
                        color: AppTheme.dGold2,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            feature.subtitle,
                            style: TextStyle(
                              color: Colors.white.withAlpha(210),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.dGold2,
                foregroundColor: AppTheme.dMaroonDeep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.push(AppRouter.createWeddingPlan),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                'إنشاء خطة زفاف',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push(AppRouter.weddingPlans),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text(
              'عرض كل الخطط',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
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
            icon: Icons.groups_outlined,
            actionLabel: 'عرض الكل',
            onAction: () => context.push(AppRouter.sharedWeddingPlans),
          ),
          const SizedBox(height: 12),
          if (!hasSharedPlans)
            const AarastEmptyState(
              title: 'لا توجد خطط مشتركة بعد',
              message: 'عندما يشاركك أحد أفراد العائلة خطة، ستظهر هنا.',
              icon: Icons.group_add_outlined,
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
          color: AppTheme.dCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.dLine),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.dMaroon,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white),
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
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppTheme.dInkSoft),
          ],
        ),
      ),
    );
  }
}
