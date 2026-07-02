import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AarastPageScaffold(
      title: 'الدعم والمساعدة',
      subtitle: 'إرشادات آمنة وحلول سريعة داخل أعرست',
      showBack: true,
      child: ListView(
        children: [
          const _SupportIntroCard(),
          const SizedBox(height: 14),
          _SupportActionCard(
            title: 'أحتاج مساعدة في الحساب أو التنبيهات',
            body:
                'راجع إعدادات الحساب والتنبيهات، ثم احفظ التغييرات إذا كانت متاحة لحسابك.',
            icon: Icons.settings_outlined,
            buttonLabel: 'فتح الإعدادات',
            onPressed: () => context.push(AppRouter.settings),
          ),
          const SizedBox(height: 12),
          _SupportActionCard(
            title: 'أبحث عن تنبيه أو دعوة',
            body:
                'افتح التنبيهات المحفوظة لمراجعة دعوات المشاركة، عروض الأسعار، والمهام المهمة.',
            icon: Icons.notifications_none_rounded,
            buttonLabel: 'فتح التنبيهات',
            onPressed: () => context.push(AppRouter.notifications),
          ),
          const SizedBox(height: 12),
          _SupportActionCard(
            title: 'مشكلة في خطة مشتركة',
            body:
                'تحقق من الخطط المشتركة معك وصلاحيات كل خطة قبل طلب تعديل من مالك الخطة.',
            icon: Icons.groups_2_outlined,
            buttonLabel: 'الخطط المشتركة',
            onPressed: () => context.push(AppRouter.sharedWeddingPlans),
          ),
          const SizedBox(height: 14),
          const _SupportBoundaryCard(),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _SupportIntroCard extends StatelessWidget {
  const _SupportIntroCard();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.ivory,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupportIcon(icon: Icons.support_agent_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'هذه الصفحة تساعدك على الوصول للمكان الصحيح داخل التطبيق. لا تشارك كلمة المرور أو رمز التحقق أو تفاصيل مالية حساسة عند طلب المساعدة.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportActionCard extends StatelessWidget {
  const _SupportActionCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SupportIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.burgundyDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AarastButton(
            label: buttonLabel,
            icon: Icons.chevron_left_rounded,
            variant: AarastButtonVariant.secondary,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _SupportBoundaryCard extends StatelessWidget {
  const _SupportBoundaryCard();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.ivory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastSectionHeader(
            title: 'حدود الدعم في هذه النسخة',
            icon: Icons.privacy_tip_outlined,
          ),
          SizedBox(height: 10),
          _BoundaryLine(
            text: 'أعرست لا يدير مدفوعات أو عربون أو حجز مؤكد داخل هذه النسخة.',
          ),
          _BoundaryLine(
            text:
                'مشاكل الموردين وعروض الأسعار تُعامل كمتابعة تنظيمية، وليست ضماناً قانونياً أو مالياً.',
          ),
          _BoundaryLine(
            text:
                'صلاحيات المشاركة والبيانات المالية تبقى خاصة ولا تظهر إلا حسب إذن واضح من مالك الخطة.',
          ),
        ],
      ),
    );
  }
}

class _BoundaryLine extends StatelessWidget {
  const _BoundaryLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppTheme.gold,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportIcon extends StatelessWidget {
  const _SupportIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.burgundySoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(icon, color: AppTheme.burgundy),
    );
  }
}
