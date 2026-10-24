import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart'
    show AarastInlineSpinner, AarastPressable, AarastScreenFrame;
import '../../auth/auth_api.dart' show AuthController;
import '../data/plan_assistant_api.dart';
import '../models/plan_assistant.dart';

/// b11 «اسأل اعّرست»: the owner or partner asks about their own plan and
/// reads the answer under the question. w36 asks once before the first
/// question; w37 says why no answer came (today's questions are used up,
/// or there is no connection). Nothing is kept on the phone but the consent.
/// The design's «لو» what-if box and the market range are dropped (the
/// server sends neither, C22), and the field has no microphone.
class PlanAssistantScreen extends StatefulWidget {
  const PlanAssistantScreen({required this.weddingPlanId, this.api, super.key});

  final String weddingPlanId;

  /// For tests; the app builds it from the shared client.
  final PlanAssistantApi? api;

  /// The three questions b11 draws; anything else is typed.
  static const quickKinds = [
    PlanAssistantKind.forgotten,
    PlanAssistantKind.cheaper,
    PlanAssistantKind.negotiation,
  ];

  @override
  State<PlanAssistantScreen> createState() => _PlanAssistantScreenState();
}

/// One question and what came back for it.
class _Exchange {
  _Exchange({required this.question, required this.askedAt});

  final String question;
  final DateTime askedAt;
  PlanAssistantAnswer? answer;
}

/// Why no answer came (w37).
enum _Stop { limit, offline }

class _PlanAssistantScreenState extends State<PlanAssistantScreen> {
  final _questionController = TextEditingController();
  late PlanAssistantApi _api =
      widget.api ?? PlanAssistantApi(context.read<ApiClient>());

  PlanAssistantStatus? _status;
  bool _loadFailed = false;
  bool _asking = false;
  final _exchanges = <_Exchange>[];
  String? _askError;
  _Stop? _stop;

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
        _loadFailed = false;
        _exchanges.clear();
        _askError = null;
        _stop = null;
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
    setState(() => _loadFailed = false);
    try {
      final status = await _api.status(weddingPlanId);
      if (mounted && weddingPlanId == widget.weddingPlanId) {
        setState(() => _status = status);
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  String get _consentKey {
    final userId = context.read<AuthController?>()?.user?.id ?? 'device';
    return 'aarast.assistant.consent.v1.$userId';
  }

  Future<bool> _ensureConsent(int dailyLimit) async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_consentKey) == true) return true;
    if (!mounted) return false;
    final agreed = await showJourneySheet<bool>(
      context: context,
      builder: (_) => _ConsentSheet(dailyLimit: dailyLimit),
    );
    if (agreed != true) return false;
    await preferences.setBool(_consentKey, true);
    return true;
  }

  Future<void> _ask(PlanAssistantKind kind) async {
    final status = _status;
    if (status == null || _asking) return;
    final typed = _questionController.text.trim();
    if (kind == PlanAssistantKind.question && typed.isEmpty) {
      AarastToast.showError(
        context,
        context.say('اكتب سؤالك أول.', 'اكتبي سؤالك أول.'),
      );
      return;
    }
    if (!await _ensureConsent(status.dailyLimit) || !mounted) return;
    FocusScope.of(context).unfocus();
    final exchange = _Exchange(
      question: kind == PlanAssistantKind.question ? typed : kind.label,
      askedAt: DateTime.now(),
    );
    setState(() {
      _asking = true;
      _askError = null;
      _stop = null;
      _exchanges.add(exchange);
    });
    try {
      final answer = await _api.ask(
        widget.weddingPlanId,
        kind: kind,
        question: kind == PlanAssistantKind.question ? typed : null,
      );
      if (!mounted) return;
      if (kind == PlanAssistantKind.question) _questionController.clear();
      setState(() {
        exchange.answer = answer;
        _status = PlanAssistantStatus(
          enabled: status.enabled,
          allowed: status.allowed,
          dailyLimit: status.dailyLimit,
          remainingToday: answer.remainingToday,
        );
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _exchanges.remove(exchange);
        if (error.serverCode == 'ASSISTANT_DAILY_LIMIT') {
          _stop = _Stop.limit;
        } else if (error.isNetworkFailure) {
          _stop = _Stop.offline;
        } else {
          _askError = error.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exchanges.remove(exchange);
        _askError = 'ما وصلتنا إجابة. حاول مرة ثانية.';
      });
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) AarastToast.showSuccess(context, 'انسخت الإجابة');
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
    final usable = status != null && status.available;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                JourneySubHeader(
                  title: context.say('اسأل اعّرست', 'اسألي اعّرست'),
                  subtitle: 'يجاوبك من خطتك أنت، وما يخترع أسعار',
                  onBack: _goBack,
                ),
                ..._body(status),
              ],
            ),
          ),
          if (usable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _AskField(
                controller: _questionController,
                enabled: !_asking && status.remainingToday > 0,
                onSend: () => _ask(PlanAssistantKind.question),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(PlanAssistantStatus? status) {
    if (_loadFailed) {
      return [
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.home,
          onRetry: _loadStatus,
        ),
      ];
    }
    if (status == null) {
      return const [
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.home,
        ),
      ];
    }
    if (!status.enabled) {
      return const [
        JourneyNote(
          key: ValueKey('assistant-off'),
          text: 'المساعد مو شغّال في هذي النسخة بعد.',
          icon: LucideIcons.info,
        ),
      ];
    }
    if (!status.allowed) {
      return const [
        JourneyNote(
          key: ValueKey('assistant-not-allowed'),
          text: 'المساعد لصاحب الخطة وشريكه بس.',
          icon: LucideIcons.lock,
        ),
      ];
    }
    final exhausted = status.remainingToday <= 0;
    final last = _exchanges.isEmpty ? null : _exchanges.last;
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final kind in PlanAssistantScreen.quickKinds)
            JourneyChip(
              key: ValueKey('assistant-kind-${kind.apiValue}'),
              label: kind.label,
              icon: _quickIcon(kind),
              selected: false,
              onTap: _asking || exhausted ? null : () => _ask(kind),
            ),
        ],
      ),
      const SizedBox(height: 16),
      for (final exchange in _exchanges) ...[
        _QuestionBubble(exchange: exchange),
        const SizedBox(height: 10),
        if (exchange.answer case final answer?) ...[
          _AnswerCard(answer: answer),
          const SizedBox(height: 10),
        ],
      ],
      if (_asking)
        Row(
          key: const ValueKey('assistant-thinking'),
          children: [
            AarastInlineSpinner(color: context.accent.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'يفكّر… ممكن ياخذ دقيقة',
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
          ],
        ),
      if (_askError case final error?)
        JourneyNote(
          key: const ValueKey('assistant-error'),
          text: error,
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
        ),
      if (_stop == _Stop.offline)
        const _StopCard(
          key: ValueKey('assistant-offline'),
          icon: LucideIcons.wifiOff,
          color: AarastV3Color.textMuted,
          soft: AarastV3Color.line,
          title: 'المساعد يحتاج نت',
          line: 'كل شيء ثاني شغّال بدون نت.',
        ),
      if (_stop == _Stop.limit || exhausted)
        _StopCard(
          key: const ValueKey('assistant-limit'),
          icon: LucideIcons.gauge,
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
          title: 'خلصت أسئلة اليوم',
          line:
              '${context.say('استخدمت', 'استخدمتِ')} الـ${status.dailyLimit}. '
              '${context.say('ترجع', 'ترجعين')} بكرة الساعة 12 الليل.',
        ),
      if (!exhausted && _stop != _Stop.limit)
        Row(
          children: [
            Expanded(
              child: Text(
                'باقي لك اليوم ${arabicCount(status.remainingToday, one: 'سؤال واحد', two: 'سؤالين', few: 'أسئلة', many: 'سؤال')}',
                key: const ValueKey('assistant-remaining'),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ),
            if (last?.answer case final answer? when !_asking)
              JourneyRoundButton(
                key: const ValueKey('assistant-copy'),
                icon: LucideIcons.copy,
                tooltip: context.say('انسخ الإجابة', 'انسخي الإجابة'),
                size: 40,
                onPressed: () => _copy(answer.answer),
              ),
          ],
        ),
    ];
  }

  IconData _quickIcon(PlanAssistantKind kind) => switch (kind) {
    PlanAssistantKind.cheaper => LucideIcons.scissors,
    _ => kind.icon,
  };
}

/// The person's question, on the right in teal (b11).
class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({required this.exchange});

  final _Exchange exchange;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(exchange.askedAt);
    final clock =
        '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.accent.primary,
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(22),
              topEnd: Radius.circular(22),
              bottomEnd: Radius.circular(22),
              bottomStart: Radius.circular(6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exchange.question,
                  key: const ValueKey('assistant-question-bubble'),
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    color: AarastV3Color.onPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  clock,
                  style: JourneyType.of(
                    JourneyType.caption,
                    color: AarastV3Color.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «من خطتك»: the answer, and the reminder that it is a suggestion.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final PlanAssistantAnswer answer;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('assistant-answer'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.sparkles,
                size: 18,
                color: context.accent.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'من خطتك',
                style: JourneyType.of(
                  JourneyType.bodySmall,
                  weight: JourneyType.bold,
                  color: context.accent.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            answer.answer,
            style: JourneyType.of(JourneyType.body, height: 1.7),
          ),
          if (!answer.declined && !answer.marketDataAvailable) ...[
            const SizedBox(height: 10),
            Text(
              'ما عندنا أسعار سوق لمدينتك بعد، فالأرقام هنا من خطتك بس.',
              key: const ValueKey('assistant-no-market'),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'اقتراح، والقرار لك.',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// w37: why the assistant gave no answer.
class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.line,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: JourneyBox(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JourneyIconTile(icon: icon, color: color, soft: soft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: JourneyType.of(
                      JourneyType.lead,
                      weight: JourneyType.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: JourneyType.of(
                      JourneyType.body,
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

/// «اسأل عن عرسك…»: the field at the bottom and its round send button.
class _AskField extends StatelessWidget {
  const _AskField({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AarastV3Color.line),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.sparkles, size: 20, color: context.accent.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('assistant-question'),
              controller: controller,
              enabled: enabled,
              maxLength: 500,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: JourneyType.of(JourneyType.bodyLarge),
              cursorColor: context.accent.primary,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: context.say('اسأل عن عرسك…', 'اسألي عن عرسك…'),
                hintStyle: JourneyType.of(
                  JourneyType.bodyLarge,
                  color: AarastV3Color.textFaint,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: enabled,
            label: context.say('اسأل', 'اسألي'),
            excludeSemantics: true,
            child: AarastPressable(
              key: const ValueKey('assistant-send'),
              onTap: enabled ? onSend : null,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: enabled
                      ? context.accent.primary
                      : AarastV3Color.lineStrong,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.send,
                  size: 20,
                  color: AarastV3Color.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// w36 «المساعد الذكي»: what is sent and what is not, before the first
/// question. «ويقرأ الفواتير» and «تقدر توقفه من الحساب» are dropped: no
/// receipt is read and no switch exists in the account.
class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet({required this.dailyLimit});

  final int dailyLimit;

  Widget _row(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: context.accent.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: JourneyType.of(JourneyType.body))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: 'المساعد الذكي',
      subtitle: 'يفهم سؤالك ويجاوبك من خطتك',
      children: [
        JourneyBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _row(
                context,
                LucideIcons.send,
                'سؤالك وملخص خطتك (المدينة والموعد والميزانية وبنودها والعروض) يروحون لخدمة Claude من Anthropic تفهمه',
              ),
              _row(
                context,
                LucideIcons.eyeOff,
                context.say(
                  'ما نرسل أسماء ضيوفك ولا أرقامهم',
                  'ما نرسل أسماء ضيفاتك ولا أرقامهن',
                ),
              ),
              _row(
                context,
                LucideIcons.checkCircle2,
                'ما نحفظ أسئلتك، وما يتغيّر شيء في خطتك',
              ),
              _row(
                context,
                LucideIcons.gauge,
                arabicCount(
                  dailyLimit,
                  one: 'سؤال واحد في اليوم',
                  two: 'سؤالين في اليوم',
                  few: 'أسئلة في اليوم',
                  many: 'سؤال في اليوم',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        JourneyButton(
          key: const ValueKey('assistant-consent-agree'),
          label: context.say('شغّل المساعد', 'شغّلي المساعد'),
          icon: LucideIcons.sparkles,
          expand: true,
          large: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 4),
        Center(
          child: JourneyTextAction(
            label: 'مو الآن',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    );
  }
}
