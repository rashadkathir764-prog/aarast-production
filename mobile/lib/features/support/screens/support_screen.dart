import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/diagnostics/diagnostic_report_sender.dart';
import '../../../core/push/push_notifications_controller.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, this.devicePushAvailableOverride});

  final bool? devicePushAvailableOverride;

  @override
  Widget build(BuildContext context) {
    final devicePushAvailable =
        devicePushAvailableOverride ?? _maybeDevicePushAvailable(context);
    return AarastPageScaffold(
      title: 'الدعم والمساعدة',
      subtitle: 'إرشادات آمنة وحلول سريعة داخل أعرست',
      showBack: true,
      child: ListView(
        children: AarastStagger.children(context, [
          const _SafetyStrip(),
          const SizedBox(height: 12),
          _QuickHelpCard(devicePushAvailable: devicePushAvailable),
          const SizedBox(height: 12),
          AarastCard(
            padding: EdgeInsets.zero,
            color: AppTheme.canvas,
            border: Border.all(color: AppTheme.brandMuted.withAlpha(80)),
            child: Column(
              children: [
                _SupportLinkRow(
                  title: 'فتح الإعدادات',
                  subtitle: 'مساعدة في الحساب والتنبيهات',
                  icon: LucideIcons.settings,
                  onTap: () => context.push(AppRouter.settings),
                ),
                Divider(height: 1, color: AppTheme.brandMuted.withAlpha(150)),
                _SupportLinkRow(
                  title: 'فتح التنبيهات',
                  subtitle: 'الدعوات وعروض الأسعار والمهام المهمة',
                  icon: LucideIcons.bell,
                  onTap: () => context.push(AppRouter.notifications),
                ),
                Divider(height: 1, color: AppTheme.brandMuted.withAlpha(150)),
                _SupportLinkRow(
                  title: 'الخطط المشتركة',
                  subtitle: 'صلاحياتك في الخطط المشتركة معك',
                  icon: LucideIcons.users,
                  onTap: () => context.push(AppRouter.sharedWeddingPlans),
                ),
                // V1 checklist 6.3: the published policy and terms.
                Divider(height: 1, color: AppTheme.brandMuted.withAlpha(150)),
                _SupportLinkRow(
                  key: const Key('support-privacy-link'),
                  title: 'سياسة الخصوصية',
                  subtitle: 'ما نجمعه من بيانات وكيف نحميه',
                  icon: LucideIcons.shieldCheck,
                  onTap: () => _openPublicPage(context, '/privacy'),
                ),
                Divider(height: 1, color: AppTheme.brandMuted.withAlpha(150)),
                _SupportLinkRow(
                  key: const Key('support-terms-link'),
                  title: 'شروط الاستخدام',
                  subtitle: 'ما يقدمه اعّرست وما لا يقدمه',
                  icon: LucideIcons.fileText,
                  onTap: () => _openPublicPage(context, '/terms'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _DiagnosticReportCard(),
          const SizedBox(height: 14),
          const _SupportBoundaryCard(),
          const SizedBox(height: 90),
        ]),
      ),
    );
  }
}

/// Opens a page of the public site (privacy policy, terms) in the browser.
Future<void> _openPublicPage(BuildContext context, String path) async {
  final opened = await launchUrl(
    Uri.https(AppRouter.inviteAppLinkHost, path),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    AarastToast.showError(context, 'تعذر فتح الصفحة على هذا الجهاز.');
  }
}

class _DiagnosticReportCard extends StatefulWidget {
  const _DiagnosticReportCard();

  @override
  State<_DiagnosticReportCard> createState() => _DiagnosticReportCardState();
}

class _DiagnosticReportCardState extends State<_DiagnosticReportCard> {
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final service = _readService();
    final isAvailable = service?.isAvailable == true;
    return AarastCard(
      color: AppTheme.canvas,
      padding: const EdgeInsets.all(14),
      border: Border.all(color: AppTheme.brandMuted.withAlpha(80)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.fileSearch,
                color: AppTheme.brand,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تقرير تشخيصي بموافقتك',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAvailable
                          ? 'يرسل أحداثاً تقنية منقحة بعد موافقتك فقط، ولا ينشئ ملفاً على الجهاز.'
                          : 'إرسال التقارير غير مفعّل في إعدادات هذه النسخة.',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('diagnostic-report-send'),
            onPressed: !isAvailable || _isSending
                ? null
                : () => _confirmAndSend(service!),
            icon: _isSending
                ? const AarastInlineSpinner(dimension: 18, color: Colors.white)
                : const Icon(LucideIcons.send, size: 18),
            label: Text(_isSending ? 'جارٍ الإرسال…' : 'مراجعة وإرسال التقرير'),
          ),
        ],
      ),
    );
  }

  DiagnosticReportService? _readService() {
    try {
      return context.read<DiagnosticReportService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _confirmAndSend(DiagnosticReportService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        key: const Key('diagnostic-report-consent-dialog'),
        title: const Text('إرسال تقرير تشخيصي؟'),
        content: const Text(
          'سيحتوي التقرير على آخر 15 دقيقة بحد أقصى 300 حدث تقني: '
          'أسماء العمليات ونتائجها، مسارات API المنقحة، رموز الحالة، '
          'المدد ومعرّفات الطلبات.\n\n'
          'لن يتضمن الاسم أو رقم الجوال أو كلمات المرور أو رموز الجلسة '
          'أو محتوى الطلبات والاستجابات. سيُرسل إلى نظام مراقبة الأعطال '
          'ولن يُحفظ كملف على جهازك.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            key: const Key('diagnostic-report-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('diagnostic-report-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('موافق وإرسال'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    final result = await service.send();
    if (!mounted) return;
    setState(() => _isSending = false);
    final message = switch (result) {
      DiagnosticReportSendResult.sent => 'تم إرسال التقرير التشخيصي بأمان.',
      DiagnosticReportSendResult.empty =>
        'لا توجد أحداث تشخيصية حديثة لإرسالها.',
      DiagnosticReportSendResult.failed =>
        'تعذر إرسال التقرير، ولم يتم حفظه. حاول مرة أخرى عند تحسن الاتصال.',
    };
    switch (result) {
      case DiagnosticReportSendResult.sent:
        AarastToast.showSuccess(context, message);
      case DiagnosticReportSendResult.empty:
        AarastToast.showInfo(context, message);
      case DiagnosticReportSendResult.failed:
        AarastToast.showError(context, message);
    }
  }
}

class _QuickHelpCard extends StatelessWidget {
  const _QuickHelpCard({required this.devicePushAvailable});

  final bool devicePushAvailable;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      color: AppTheme.canvas,
      border: Border.all(color: AppTheme.brandMuted.withAlpha(80)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(start: 8, bottom: 4),
              child: Text(
                'حلول سريعة',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _HelpTile(
              question: 'لماذا لا تصلني التنبيهات؟',
              answer: devicePushAvailable
                  ? 'التنبيهات داخل التطبيق متاحة، ونسخة Android هذه مهيأة لإشعارات الجهاز. تحقق من سماح النظام ومن تفعيل خدمة الإرسال في الخادم. الرسائل النصية وواتساب والبريد الإلكتروني ليست قنوات تنبيه مدعومة حالياً.'
                  : 'التنبيهات داخل التطبيق متاحة. إشعارات الجهاز تحتاج نسخة Android مهيأة وإعداد Firebase صالحاً مع تفعيل خدمة الإرسال في الخادم. الرسائل النصية وواتساب والبريد الإلكتروني ليست قنوات تنبيه مدعومة حالياً.',
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

bool _maybeDevicePushAvailable(BuildContext context) {
  try {
    return context.watch<PushNotificationsController>().isAvailable;
  } on ProviderNotFoundException {
    return false;
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
          color: AppTheme.textPrimary,
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
              color: AppTheme.textSecondary,
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
        color: AppTheme.focus.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.shieldAlert, size: 15, color: AppTheme.focus),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لا تشارك كلمة المرور أو رمز التحقق أو تفاصيل مالية حساسة '
              'عند طلب المساعدة.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textPrimary,
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
    super.key,
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
                color: AppTheme.brandMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: AppTheme.brand, size: 18),
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
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronLeft,
              color: AppTheme.textSecondary,
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
      color: AppTheme.canvas,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 17,
                color: AppTheme.focus,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حدود الدعم في هذه النسخة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
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
          const Icon(LucideIcons.checkCircle, color: AppTheme.focus, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textSecondary,
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
