import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../widgets/auth_wedding_widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthWeddingScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const AuthBrandMark(),
          const SizedBox(height: 26),
          const WeddingRingsBadge(size: 106),
          const SizedBox(height: 26),
          Text(
            'أهلاً بك في أعرسِت',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: AppTheme.dMaroonDeep,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'كل ما تحتاجينه لتنظيم زفافك\nفي مكان واحد',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          const AuthFeatureTile(
            title: 'تنظيم المهام',
            subtitle: 'خطة واضحة لكل تفاصيل الزفاف مع تذكيرات مريحة.',
            icon: Icons.fact_check_rounded,
          ),
          const SizedBox(height: 12),
          const AuthFeatureTile(
            title: 'إدارة الميزانية',
            subtitle: 'تابعي المصاريف والديون والأقساط بهدوء ووضوح.',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 12),
          const AuthFeatureTile(
            title: 'اكتشاف الموردين',
            subtitle: 'قارني الخيارات واحفظي الموردين المناسبين لخطتك.',
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 24),
          PrimaryActionButton(
            label: 'ابدأ الآن',
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.go(AppRouter.register),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: 'لديك حساب بالفعل؟',
            action: 'تسجيل الدخول',
            onTap: () => context.go(AppRouter.login),
          ),
        ],
      ),
    );
  }
}
