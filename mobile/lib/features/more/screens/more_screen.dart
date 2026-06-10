import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.dCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.danger.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.logOut, color: AppTheme.danger, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'تسجيل الخروج',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.dInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.dInkSoft,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        ),
                      ),
                      child: const Text('إلغاء', style: TextStyle(color: AppTheme.dMuted, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('خروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthController>().logout();
      if (context.mounted) context.go(AppRouter.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    
    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Decorative Background
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.dMaroon.withAlpha(15),
                ),
              ),
            ),
            
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              children: [
                _buildAnimated(
                  0,
                  Text(
                    'الإعدادات والملف الشخصي',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.dMaroonDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildAnimated(
                  1,
                  _AccountCard(
                    name: user?.name ?? 'مستخدم اعرست',
                    phone: user?.phone,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                _buildAnimated(
                  2,
                  const Text(
                    'مساحة العمل',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dInk,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildAnimated(
                  3,
                  _MoreTile(
                    icon: LucideIcons.gem,
                    iconColor: AppTheme.dGold2,
                    iconBg: AppTheme.dMaroonDeep,
                    label: 'خططي',
                    subtitle: 'إدارة وتعديل كل خطط الزفاف الخاصة بك',
                    onTap: () => context.push(AppRouter.weddingPlans),
                  ),
                ),
                
                _buildAnimated(
                  4,
                  _MoreTile(
                    icon: LucideIcons.users,
                    iconColor: AppTheme.dMaroon,
                    iconBg: AppTheme.dPinkBg,
                    label: 'الخطط المشتركة معي',
                    subtitle: 'الخطط التي تمت دعوتك للمشاركة فيها',
                    onTap: () => context.push(AppRouter.sharedWeddingPlans),
                  ),
                ),
                
                _buildAnimated(
                  5,
                  _MoreTile(
                    icon: LucideIcons.plusCircle,
                    iconColor: AppTheme.dBlue,
                    iconBg: AppTheme.dBlue.withAlpha(20),
                    label: 'إنشاء خطة زفاف',
                    subtitle: 'ابدأ خطة زفاف جديدة الآن',
                    onTap: () => context.push(AppRouter.createWeddingPlan),
                  ),
                ),

                const SizedBox(height: 32),

                _buildAnimated(
                  6,
                  const Text(
                    'الدعم والإعدادات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dInk,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildAnimated(
                  7,
                  _MoreTile(
                    icon: LucideIcons.bellRing,
                    iconColor: AppTheme.dGreen,
                    iconBg: AppTheme.dGreenBg,
                    label: 'الإشعارات',
                    subtitle: 'التحكم بتنبيهات المهام والديون',
                    onTap: () {},
                  ),
                ),
                
                _buildAnimated(
                  8,
                  _MoreTile(
                    icon: LucideIcons.helpCircle,
                    iconColor: AppTheme.warning,
                    iconBg: AppTheme.warning.withAlpha(20),
                    label: 'مركز المساعدة',
                    subtitle: 'تواصل معنا في حال واجهت أي مشكلة',
                    onTap: () {},
                  ),
                ),

                const SizedBox(height: 40),

                _buildAnimated(
                  9,
                  GestureDetector(
                    onTap: () => _logout(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withAlpha(15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.danger.withAlpha(30)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.logOut, color: AppTheme.danger, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                _buildAnimated(
                  10,
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Aarast V2.0',
                          style: TextStyle(
                            color: AppTheme.dMuted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'صُنع بحب في اليمن 🇾🇪',
                          style: TextStyle(
                            color: AppTheme.dMuted.withAlpha(150),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, childWidget) {
        final delay = (index * 0.05).clamp(0.0, 0.5);
        final value = (_animationController.value - delay).clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(value);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - curve)),
          child: Opacity(
            opacity: curve,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.name, this.phone});

  final String name;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow(opacity: 0.1),
            ),
            child: const Icon(
              LucideIcons.user,
              color: AppTheme.dMaroon,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (phone != null)
                  Row(
                    children: [
                      const Icon(LucideIcons.phone, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        phone!,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.pencil, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.dLine),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronLeft, color: AppTheme.dMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
