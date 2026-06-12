import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final name = user?.name ?? 'مستخدم اعّرست';
    final phone = user?.phone;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 124),
                children: [
                  _MoreHeader(
                    name: name,
                    onNotifications: () =>
                        context.push(AppRouter.notifications),
                  ),
                  const SizedBox(height: 18),
                  _ProfileCard(name: name, phone: phone),
                  const SizedBox(height: 20),
                  _MenuGroup(
                    children: [
                      _MoreActionTile(
                        title: 'الخطط المشتركة معي',
                        subtitle: 'الخطط التي تمت مشاركتها معك للوصول إليها',
                        icon: Icons.groups_2_outlined,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.sharedWeddingPlans),
                      ),
                      _MoreActionTile(
                        title: 'خططي',
                        subtitle: 'إدارة كل خطط الزفاف الخاصة بك',
                        icon: Icons.event_note_outlined,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.weddingPlans),
                      ),
                      _MoreActionTile(
                        title: 'إنشاء خطة زفاف',
                        subtitle: 'ابدئي خطة جديدة لتنظيم يومك المميز',
                        icon: Icons.add_circle_outline_rounded,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.createWeddingPlan),
                      ),
                      _MoreActionTile(
                        title: 'الموردين',
                        subtitle: 'استكشفي الموردين والخدمات المتاحة لخطتك',
                        icon: Icons.storefront_outlined,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () =>
                            context.push(AppRouter.providerMarketplace),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MenuGroup(
                    children: [
                      _MoreActionTile(
                        title: 'الدخول كمورد',
                        subtitle:
                            'تابعي حساب المورد أو أرسلي طلب الانضمام كمورد',
                        icon: Icons.store_mall_directory_outlined,
                        iconColor: AppTheme.dGoldDeep,
                        iconBackground: AppTheme.dCreamBg,
                        onTap: () => context.push(AppRouter.providerDashboard),
                      ),
                      _MoreActionTile(
                        title: 'الإعدادات',
                        subtitle: 'تخصيص التطبيق والتفضيلات',
                        icon: Icons.settings_outlined,
                        iconColor: AppTheme.dGoldDeep,
                        iconBackground: AppTheme.dCreamBg,
                        onTap: () => context.push(AppRouter.settings),
                      ),
                      _MoreActionTile(
                        title: 'الدعم والمساعدة',
                        subtitle: 'تواصلي معنا أو استعرضي الأسئلة الشائعة',
                        icon: Icons.support_agent_outlined,
                        iconColor: AppTheme.dGoldDeep,
                        iconBackground: AppTheme.dCreamBg,
                        onTap: () => context.push(AppRouter.support),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LogoutTile(onTap: () => _logout(context)),
                  const SizedBox(height: 22),
                  const _VersionFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _logout(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withAlpha(22),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تسجيل الخروج',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هل ترغبين في الخروج من حسابك الآن؟',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('خروج'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthController>().logout();
      if (context.mounted) context.go(AppRouter.login);
    }
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({required this.name, required this.onNotifications});

  final String name;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المزيد',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.dMaroonDeep,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppTheme.displayFontFamily,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'كل ما تحتاجينه في مكان واحد',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _RoundIconButton(
          icon: Icons.person_outline_rounded,
          onTap: () => _showAccountSnack(context, name),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          badge: '3',
          onTap: onNotifications,
        ),
      ],
    );
  }

  void _showAccountSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap, this.badge});

  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dLine),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppTheme.dMaroon),
            if (badge != null)
              PositionedDirectional(
                top: 1,
                start: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.dMaroon,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.dCard, width: 2),
                  ),
                  child: Text(
                    badge!,
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, this.phone});

  final String name;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(20),
      color: AppTheme.dCard,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.dCreamBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.dGold.withAlpha(90)),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 38,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.dMaroonDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phone == null || phone!.trim().isEmpty
                          ? 'حساب اعّرست'
                          : phone!,
                      textDirection: phone == null
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.dGoldDeep,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.softShadow(opacity: .08),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.dCard2,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.dLine),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: _ProfileMetric(
                    label: 'التقدم',
                    value: '—',
                    icon: Icons.donut_large_rounded,
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _ProfileMetric(
                    label: 'المهام',
                    value: '—',
                    icon: Icons.check_box_outlined,
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _ProfileMetric(
                    label: 'خططي',
                    value: '—',
                    icon: Icons.description_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.dMaroon, size: 18),
            const SizedBox(width: 5),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.dMaroon,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.dInkSoft,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: AppTheme.dLine);
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.dCard2,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: AppTheme.dLine),
          ],
        ],
      ),
    );
  }
}

class _MoreActionTile extends StatelessWidget {
  const _MoreActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 13),
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
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.dMuted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.dCard2,
      border: Border.all(color: AppTheme.danger.withAlpha(45)),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.danger.withAlpha(18),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.danger,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                'تسجيل الخروج',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.danger,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Aarast V2.0',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.dMuted,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'صُنع بحب في اليمن',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.dLine,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
