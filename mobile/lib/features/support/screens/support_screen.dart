import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_motion.dart';
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
        children: AarastStagger.children(context, [
          const _SafetyStrip(),
          const SizedBox(height: 12),
          const _QuickHelpCard(),
          const SizedBox(height: 12),
          AarastCard(
            padding: EdgeInsets.zero,
            color: AppTheme.ivory,
            border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
            child: Column(
              children: [
                _SupportLinkRow(
                  title: 'فتح الإعدادات',
                  subtitle: 'مساعدة في الحساب والتنبيهات',
                  icon: LucideIcons.settings,
                  onTap: () => context.push(AppRouter.settings),
                ),
                Divider(height: 1, color: AppTheme.burgundySoft.withAlpha(150)),
                _SupportLinkRow(
                  title: 'فتح التنبيهات',
                  subtitle: 'الدعوات وعروض الأسعار والمهام المهمة',
                  icon: LucideIcons.bell,
                  onTap: () => context.push(AppRouter.notifications),
                ),
                Divider(height: 1, color: AppTheme.burgundySoft.withAlpha(150)),
                _SupportLinkRow(
                  title: 'الخطط المشتركة',
                  subtitle: 'صلاحياتك في الخطط المشتركة معك',
                  icon: LucideIcons.users,
                  onTap: () => context.push(AppRouter.sharedWeddingPlans),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _SupportBoundaryCard(),
          const SizedBox(height: 90),
        ]),
      ),
    );
  }
}

class _QuickHelpCard extends StatelessWidget {
  const _QuickHelpCard();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(start: 8, bottom: 4),
              child: Text(
                'حلول سريعة',
                style: TextStyle(
                  color: AppTheme.burgundyDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _HelpTile(
              question: 'لماذا لا تصلني التنبيهات؟',
              answer:
                  'افتح الإعدادات وتأكد من تفعيل التنبيهات المهمة ونوع التذكير المطلوب. بعض القنوات الخارجية تعمل فقط عند توفرها.',
            ),
            _HelpTile(
              question: 'لماذا لا تظهر الخطة المشتركة؟',
              answer:
                  'تأكد أنك سجلت الدخول بنفس الرقم الذي استلم الدعوة، ثم افتح الخطط المشتركة وحدّث القائمة بعد قبول الدعوة.',
            ),
            _HelpTile(
              question: 'كيف أحمي بياناتي المالية؟',
              answer:
                  'لا تمنح صلاحيات الميزانية أو المصاريف أو إدارة المال إلا لشخص تثق به. يمكنك تعديل صلاحيات أي عضو من شاشة المشاركة.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      dense: true,
      title: Text(
        question,
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppTheme.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            answer,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.muted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// سطر الأمان الوحيد الذي يستحق مكانًا قبل الروابط — بدل كرت تمهيد كامل.
class _SafetyStrip extends StatelessWidget {
  const _SafetyStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.gold.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.shieldAlert, size: 15, color: AppTheme.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لا تشارك كلمة المرور أو رمز التحقق أو تفاصيل مالية حساسة '
              'عند طلب المساعدة.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportLinkRow extends StatelessWidget {
  const _SupportLinkRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.burgundySoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: AppTheme.burgundy, size: 18),
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
                    style: textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronLeft,
              color: AppTheme.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportBoundaryCard extends StatelessWidget {
  const _SupportBoundaryCard();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.ivory,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 17,
                color: AppTheme.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حدود الدعم في هذه النسخة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _BoundaryLine(
            text: 'أعرست لا يدير مدفوعات أو عربون أو حجز مؤكد داخل هذه النسخة.',
          ),
          const _BoundaryLine(
            text:
                'مشاكل الموردين وعروض الأسعار تُعامل كمتابعة تنظيمية، وليست ضماناً قانونياً أو مالياً.',
          ),
          const _BoundaryLine(
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
          const Icon(LucideIcons.checkCircle, color: AppTheme.gold, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
