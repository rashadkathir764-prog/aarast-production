import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/support_config.dart';
import '../../../core/diagnostics/diagnostic_report_sender.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_links.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';

/// g10 «المساعدة»: the team on WhatsApp, the questions people ask most, and
/// the published privacy policy and terms (D26).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, this.whatsAppOverride});

  /// Fixed in tests; the app reads [SupportConfig.whatsApp].
  final String? whatsAppOverride;

  @override
  Widget build(BuildContext context) {
    final whatsApp = whatsAppChatUri(
      whatsAppOverride ?? SupportConfig.whatsApp,
    );
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          JourneySubHeader(
            title: 'المساعدة',
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRouter.more),
          ),
          if (whatsApp != null) ...[
            const SizedBox(height: 4),
            _WhatsAppCard(uri: whatsApp),
          ],
          const JourneySectionTitle('أسئلة كثير يسألونها'),
          const JourneyList(
            dividers: false,
            children: [
              _Question(
                question: 'كيف أضيف العروسة أو أخوي مشارك؟',
                answer:
                    'من حسابي › المشاركين › أضف مشارك. يوصله رابط على '
                    'واتساب، يدخل برقمه ويوافق، وأنت تختار ايش يشوف.',
              ),
              _Question(
                question: 'ايش يصير لو أجّلت العرس؟',
                answer:
                    'غيّر الموعد من حسابي › تأجيل العرس. خطتك كلها تبقى، '
                    'والعد يمشي على الموعد الجديد، وتقدر تبلّغ المزودين '
                    'اللي حجزتهم من محادثاتهم.',
              ),
              _Question(
                question: 'هل اعّرست يحوّل فلوس؟',
                answer:
                    'لا. اعّرست يسجّل اللي دفعته واللي باقي عليك بس، '
                    'والفلوس تدفعها أنت للمزود مباشرة.',
              ),
              _Question(
                question: 'مين يشوف أرقامي؟',
                answer:
                    'أنت بس. المشارك ما يشوف المبالغ إلا إذا أعطيته صلاحية '
                    'المال، وتقدر تسحبها منه متى ما تبي.',
              ),
              _Question(
                question: 'كيف أطلب عرض سعر من مزود؟',
                answer:
                    'افتح صفحة المزود واضغط «اطلب عرض». يوصله طلبك مع موعد '
                    'عرسك، ويرد عليك بعرض في المحادثة.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PageChip(
                  key: const Key('support-privacy-link'),
                  label: 'الخصوصية',
                  icon: LucideIcons.lock,
                  path: '/privacy',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PageChip(
                  key: const Key('support-terms-link'),
                  label: 'الشروط',
                  icon: LucideIcons.fileText,
                  path: '/terms',
                ),
              ),
            ],
          ),
          const _DiagnosticReportAction(),
        ],
      ),
    );
  }
}

class _WhatsAppCard extends StatelessWidget {
  const _WhatsAppCard({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      key: const Key('support-whatsapp'),
      onTap: () => _open(context, uri),
      borderRadius: BorderRadius.circular(24),
      semanticLabel: 'كلّمنا على واتساب',
      child: JourneyBox(
        color: AarastV3Color.mintSoft,
        radius: 24,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const JourneyIconTile(
              icon: LucideIcons.messageCircle,
              color: AarastV3Color.onPrimary,
              soft: AarastV3Color.mint,
              size: 50,
              radius: 16,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كلّمنا على واتساب',
                    style: JourneyType.of(
                      JourneyType.title,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    // Isolated so the digit groups keep their order inside
                    // the Arabic line.
                    '\u2066${_shownNumber(uri)}\u2069',
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: AarastV3Color.mint,
                    ),
                  ),
                  Text(
                    'نرد عادة خلال ساعة',
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
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

/// «777 000 111» for a Yemeni number, the international form otherwise.
String _shownNumber(Uri whatsApp) {
  final digits = whatsApp.path.replaceAll('/', '');
  if (digits.length == 12 && digits.startsWith('967')) {
    final local = digits.substring(3);
    return '${local.substring(0, 3)} ${local.substring(3, 6)} '
        '${local.substring(6)}';
  }
  return '+$digits';
}

/// A question that opens its answer in place.
class _Question extends StatefulWidget {
  const _Question({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: () => setState(() => _open = !_open),
      semanticLabel: widget.question,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const JourneyIconTile(
              icon: LucideIcons.helpCircle,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              size: 36,
              radius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.question,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  if (_open) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.answer,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                _open ? LucideIcons.chevronDown : LucideIcons.chevronLeft,
                size: 18,
                color: AarastV3Color.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The published privacy policy or terms, opened in the browser.
class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.label,
    required this.icon,
    required this.path,
    super.key,
  });

  final String label;
  final IconData icon;
  final String path;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: () => _open(context, Uri.https(AppRouter.inviteAppLinkHost, path)),
      borderRadius: BorderRadius.circular(19),
      semanticLabel: label,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AarastV3Color.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _open(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    AarastToast.showError(context, 'ما قدرنا نفتحها على هذا الجوال.');
  }
}

/// A crash report, sent only with fresh consent each time and only when this
/// build reports to the monitoring system (kept beside g10, D26).
class _DiagnosticReportAction extends StatefulWidget {
  const _DiagnosticReportAction();

  @override
  State<_DiagnosticReportAction> createState() =>
      _DiagnosticReportActionState();
}

class _DiagnosticReportActionState extends State<_DiagnosticReportAction> {
  bool _isSending = false;

  DiagnosticReportService? _readService() {
    try {
      return context.read<DiagnosticReportService>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _readService();
    if (service == null || !service.isAvailable) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: JourneyTextAction(
          key: const Key('diagnostic-report-send'),
          label: _isSending ? 'نرسل التقرير…' : 'أرسل تقرير عطل لفريقنا',
          onPressed: _isSending ? null : () => _confirmAndSend(service),
        ),
      ),
    );
  }

  Future<void> _confirmAndSend(DiagnosticReportService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        key: const Key('diagnostic-report-consent-dialog'),
        title: const Text('ترسل تقرير عطل؟'),
        content: const Text(
          'فيه آخر 15 دقيقة من عمل التطبيق، 300 حدث بالكثير: أسماء '
          'العمليات ونتائجها ومساراتها ومددها.\n\n'
          'ما فيه اسمك ولا رقمك ولا رمز الدخول ولا محتوى خطتك. يروح '
          'لنظام متابعة الأعطال، وما ينحفظ ملف في جوالك.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            key: const Key('diagnostic-report-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لا'),
          ),
          FilledButton(
            key: const Key('diagnostic-report-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('أرسله'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    final result = await service.send();
    if (!mounted) return;
    setState(() => _isSending = false);
    switch (result) {
      case DiagnosticReportSendResult.sent:
        AarastToast.showSuccess(context, 'وصل التقرير، شكرًا لك.');
      case DiagnosticReportSendResult.empty:
        AarastToast.showInfo(context, 'ما فيه شيء جديد يستاهل نرسله.');
      case DiagnosticReportSendResult.failed:
        AarastToast.showError(
          context,
          'ما وصل التقرير، وما انحفظ. جرّب لما يتحسن النت.',
        );
    }
  }
}
