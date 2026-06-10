import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Soft background decorations
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: AppTheme.dPinkBg.withAlpha(120),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppTheme.dGold.withAlpha(20),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content
            LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          
                          // Logo and Title
                          const _BrandMark(),
                          const SizedBox(height: 30),
                          
                          // Greetings
                          Text(
                            'أهلاً بك في أعرسِت',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium?.copyWith(
                              color: AppTheme.dMaroonDeep,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'كل ما تحتاجينه لتنظيم زفافك\nفي مكان واحد',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppTheme.dInkSoft,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Feature Cards
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  _FeatureCard(
                                    title: 'تنظيم المهام',
                                    subtitle:
                                        'خطة ذكية لمهامك مع تذكيرات\nللتأكد من كل التفاصيل.',
                                    icon: LucideIcons.clipboardCheck,
                                    delayMs: 100,
                                  ),
                                  const SizedBox(height: 16),
                                  _FeatureCard(
                                    title: 'إدارة الميزانية',
                                    subtitle:
                                        'تابعي ميزانيتك بسهولة و تحكمي\nفي مصاريف زفافك.',
                                    icon: LucideIcons.wallet,
                                    delayMs: 250,
                                  ),
                                  const SizedBox(height: 16),
                                  _FeatureCard(
                                    title: 'اكتشاف الموردين',
                                    subtitle:
                                        'ابحثي واختاري من أفضل الموردين\nالموثوقين في مكان واحد.',
                                    icon: LucideIcons.store, // Representing bouquet/vendors
                                    delayMs: 400,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Actions
                          const SizedBox(height: 16),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                            child: PrimaryActionButton(
                              label: 'ابدئي الآن',
                              onPressed: () {
                                context.push(AppRouter.register);
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 1,
                                color: AppTheme.dGold,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.favorite,
                                  size: 12,
                                  color: AppTheme.dGoldDeep,
                                ),
                              ),
                              Container(
                                width: 24,
                                height: 1,
                                color: AppTheme.dGold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Subtle Login link
                          GestureDetector(
                            onTap: () {
                              context.push(AppRouter.login);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Text(
                                'لديك حساب بالفعل؟ تسجيل الدخول',
                                textAlign: TextAlign.center,
                                style: textTheme.labelLarge?.copyWith(
                                  color: AppTheme.dMaroon,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Text(
              'أعرسِت',
              textAlign: TextAlign.center,
              style: textTheme.displayMedium?.copyWith(
                color: AppTheme.dMaroonDeep,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            Positioned(
              top: -6,
              right: -12,
              child: Icon(
                Icons.favorite,
                color: AppTheme.dPinkBg,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 1.5, color: AppTheme.dGold2),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.favorite, color: AppTheme.dGoldDeep, size: 14),
            ),
            Container(width: 40, height: 1.5, color: AppTheme.dGold2),
          ],
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int delayMs;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.delayMs,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // We simulate a staggered entry by delaying the value manually,
        // but for simplicity in Tween, we just use a small transform offset.
        // A robust staggered approach would use an AnimationController.
        // Here we keep it lightweight.
        final delayedValue = (value - (delayMs / 1000)).clamp(0.0, 1.0);
        
        return Transform.translate(
          offset: Offset(0, 20 * (1 - delayedValue)),
          child: Opacity(
            opacity: delayedValue,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusLg),
        child: Row(
          children: [
            // Texts flow Right to Left, so Icon is on the left in RTL if we use standard Row 
            // Wait, flutter handles RTL natively. In RTL, index 0 is on the right.
            // Design shows Icon on the right, texts on the left.
            // So if Directionality is RTL, index 0 is Right.
            // Let's explicitly put Icon first, it will be Right.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dPinkBg.withAlpha(100),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.dMaroonDeep, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppTheme.dMaroonDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
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
    );
  }
}
