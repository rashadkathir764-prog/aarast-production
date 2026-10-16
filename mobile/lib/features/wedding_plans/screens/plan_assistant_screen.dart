import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../data/plan_assistant_api.dart';
import '../models/plan_assistant.dart';

/// The planning assistant (V1 checklist 4.12): the owner or partner picks
/// what they need, agrees once to sending the plan's data, and reads the
/// answer. Nothing is kept on the device but the consent.
class PlanAssistantScreen extends StatefulWidget {
  const PlanAssistantScreen({required this.weddingPlanId, this.api, super.key});

  final String weddingPlanId;

  /// For tests; the app builds it from the shared client.
  final PlanAssistantApi? api;

  @override
  State<PlanAssistantScreen> createState() => _PlanAssistantScreenState();
}

class _PlanAssistantScreenState extends State<PlanAssistantScreen> {
  final _questionController = TextEditingController();
  late PlanAssistantApi _api =
      widget.api ?? PlanAssistantApi(context.read<ApiClient>());

  PlanAssistantStatus? _status;
  String? _loadError;
  bool _asking = false;
  PlanAssistantKind? _lastKind;
  PlanAssistantAnswer? _answer;
  String? _askError;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void didUpdateWidget(covariant PlanAssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId ||
        oldWidget.api != widget.api) {
      // Another plan: nothing of the previous one stays on screen.
      setState(() {
        _api = widget.api ?? PlanAssistantApi(context.read<ApiClient>());
        _status = null;
        _loadError = null;
        _answer = null;
        _askError = null;
      });
      _loadStatus();
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final weddingPlanId = widget.weddingPlanId;
    try {
      final status = await _api.status(weddingPlanId);
      if (mounted && weddingPlanId == widget.weddingPlanId) {
        setState(() => _status = status);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'تعذر فتح المساعد. حاول مجددًا.');
    }
  }

  String get _consentKey {
    final userId = context.read<AuthController?>()?.user?.id ?? 'device';
    return 'aarast.assistant.consent.v1.$userId';
  }

  Future<bool> _ensureConsent() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_consentKey) == true) return true;
    if (!mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('قبل أن تسأل المساعد'),
        content: const Text(
          'ليجيبك من خطتك، نرسل إلى خدمة Claude من شركة Anthropic ملخص خطتك كما '
          'تراها أنت: المدينة والموعد، وعدد الضيوف والمهام، والميزانية وبنودها، '
          'وعروض الأسعار. لا نرسل أسماء ضيوفك ولا أرقام هواتف، ولا نحفظ أسئلتك. '
          'الإجابات اقتراحات، فراجعها قبل قراراتك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ليس الآن'),
          ),
          FilledButton(
            key: const ValueKey('assistant-consent-agree'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('أوافق'),
          ),
        ],
      ),
    );
    if (agreed != true) return false;
    await preferences.setBool(_consentKey, true);
    return true;
  }

  Future<void> _ask(PlanAssistantKind kind) async {
    final question = _questionController.text.trim();
    if (kind == PlanAssistantKind.question && question.isEmpty) {
      AarastToast.showError(context, 'اكتب سؤالك أولًا.');
      return;
    }
    if (!await _ensureConsent() || !mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _lastKind = kind;
      _askError = null;
    });
    try {
      final answer = await _api.ask(
        widget.weddingPlanId,
        kind: kind,
        question: question.isEmpty ? null : question,
      );
      if (!mounted) return;
      setState(() {
        _answer = answer;
        final status = _status;
        if (status != null) {
          _status = PlanAssistantStatus(
            enabled: status.enabled,
            allowed: status.allowed,
            dailyLimit: status.dailyLimit,
            remainingToday: answer.remainingToday,
          );
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _askError = error.message);
    } catch (_) {
      if (mounted) setState(() => _askError = 'تعذر الحصول على إجابة. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _copyAnswer(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) AarastToast.showSuccess(context, 'نُسخت الإجابة.');
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.weddingPlanDashboard(widget.weddingPlanId));
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return AarastScreenFrame(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          AarastPageHeader(
            title: 'مساعد اعّرست',
            subtitle: 'اقتراحات من خطتك أنت. لا يخترع أسعارًا، وأنت صاحب القرار.',
            showBack: true,
            onBack: _goBack,
          ),
          const SizedBox(height: AppTheme.space14),
          if (status == null && _loadError == null)
            const Center(child: AarastInlineSpinner(dimension: 24))
          else if (_loadError != null)
            AarastStatusPill(
              label: _loadError!,
              color: AppTheme.danger,
              icon: LucideIcons.alertCircle,
            )
          else if (!status!.enabled)
            const AarastStatusPill(
              key: ValueKey('assistant-off'),
              label: 'المساعد غير مفعّل بعد في هذه النسخة.',
              icon: LucideIcons.info,
            )
          else if (!status.allowed)
            const AarastStatusPill(
              key: ValueKey('assistant-not-allowed'),
              label: 'المساعد متاح لصاحب الخطة وشريكه فقط.',
              icon: LucideIcons.lock,
            )
          else
            ..._askingArea(status),
        ],
      ),
    );
  }

  List<Widget> _askingArea(PlanAssistantStatus status) {
    final exhausted = status.remainingToday <= 0;
    final answer = _answer;
    return [
      AarastStatusPill(
        key: const ValueKey('assistant-remaining'),
        label: exhausted
            ? 'انتهت أسئلة اليوم. عد غدًا.'
            : 'باقي لك اليوم ${status.remainingToday} من ${status.dailyLimit} أسئلة',
        icon: LucideIcons.sparkles,
        color: exhausted ? AppTheme.warning : AppTheme.brand,
      ),
      const SizedBox(height: AppTheme.space14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final kind in PlanAssistantKind.values)
            if (kind != PlanAssistantKind.question)
              ActionChip(
                key: ValueKey('assistant-kind-${kind.apiValue}'),
                avatar: Icon(kind.icon, size: 16, color: AppTheme.brand),
                label: Text(kind.label),
                onPressed: _asking || exhausted ? null : () => _ask(kind),
              ),
        ],
      ),
      const SizedBox(height: AppTheme.space14),
      TextField(
        key: const ValueKey('assistant-question'),
        controller: _questionController,
        maxLength: 500,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _ask(PlanAssistantKind.question),
        decoration: InputDecoration(
          labelText: 'أو اكتب سؤالك عن عرسك',
          hintText: 'مثال: كم أخصص للتصوير؟',
          suffixIcon: IconButton(
            key: const ValueKey('assistant-send'),
            tooltip: 'اسأل',
            onPressed: _asking || exhausted
                ? null
                : () => _ask(PlanAssistantKind.question),
            icon: const Icon(LucideIcons.send),
          ),
        ),
      ),
      const SizedBox(height: AppTheme.space10),
      if (_asking)
        Row(
          key: const ValueKey('assistant-thinking'),
          children: [
            const AarastInlineSpinner(),
            const SizedBox(width: AppTheme.space10),
            Expanded(
              child: Text(
                'يفكر المساعد في "${_lastKind?.label ?? ''}"… قد يأخذ دقيقة.',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      if (_askError != null)
        AarastStatusPill(
          key: const ValueKey('assistant-error'),
          label: _askError!,
          color: AppTheme.danger,
          icon: LucideIcons.alertCircle,
        ),
      if (answer != null && !_asking) ...[
        const SizedBox(height: AppTheme.space10),
        DecoratedBox(
          key: const ValueKey('assistant-answer'),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  answer.answer,
                  style: const TextStyle(height: 1.7, color: AppTheme.textPrimary),
                ),
                if (!answer.declined && !answer.marketDataAvailable) ...[
                  const SizedBox(height: AppTheme.space10),
                  const Text(
                    'لا تتوفر أسعار سوق لمدينتك بعد، فالأرقام هنا من خطتك فقط.',
                    key: ValueKey('assistant-no-market'),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const ValueKey('assistant-copy'),
                    onPressed: () => _copyAnswer(answer.answer),
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('نسخ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }
}
