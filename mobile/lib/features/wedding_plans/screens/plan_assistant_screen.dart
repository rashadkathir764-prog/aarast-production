import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/report_reason_sheet.dart';
import '../../../core/widgets/aarast_ui.dart'
    show AarastInlineSpinner, AarastPressable, AarastScreenFrame;
import '../data/plan_assistant_api.dart';
import '../models/plan_assistant.dart';

/// b11 «اسأل اعّرست»: the owner or partner asks about their own plan and
/// reads the answer under the question. w36 asks once before the first
/// question; w37 says why no answer came (today's questions are used up,
/// or there is no connection). Nothing is kept on the phone; the consent is
/// the server's record (RA-BE-161).
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
  _Exchange({
    required this.kind,
    required this.question,
    required this.typed,
    required this.askedAt,
  });

  final PlanAssistantKind kind;

  /// What the bubble shows: the typed question or the request's name.
  final String question;

  /// The reader's own words, for «سؤال آخر» only.
  final String? typed;
  final DateTime askedAt;
  PlanAssistantAnswer? answer;

  /// RA-ST-04: this answer was reported; it is not offered again.
  bool reported = false;
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

  /// RA-BE-161: the server's record opens the assistant; w36 asks once and
  /// records the agreement there before the first question goes out.
  Future<bool> _ensureConsent(PlanAssistantStatus status) async {
    if (status.consentedAt != null) return true;
    final weddingPlanId = widget.weddingPlanId;
    final agreed = await showJourneySheet<bool>(
      context: context,
      builder: (_) => _ConsentSheet(dailyLimit: status.dailyLimit),
    );
    if (agreed != true || !mounted) return false;
    try {
      final at = await _api.recordConsent(weddingPlanId);
      if (!mounted || weddingPlanId != widget.weddingPlanId) return false;
      setState(() => _status = _status?.copyWith(consentedAt: () => at));
      return true;
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
      return false;
    }
  }

  /// [consentAskedAgain]: this is the one retry after the sheet asked
  /// again because the server held no consent (item 7).
  Future<void> _ask(
    PlanAssistantKind kind, {
    bool consentAskedAgain = false,
  }) async {
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
    if (!await _ensureConsent(status) || !mounted) return;
    final consentLost = await _send(
      kind,
      typed,
      consentAskedAgain: consentAskedAgain,
    );
    if (consentLost && mounted) {
      // Item 7: the server no longer holds the consent (taken back from
      // another phone): the sheet asks again, and the question goes once
      // more when it is given; a second refusal is said, not asked again.
      await _ask(kind, consentAskedAgain: true);
    }
  }

  /// Sends one question; true when the server holds no consent for it and
  /// the sheet has not asked again yet.
  Future<bool> _send(
    PlanAssistantKind kind,
    String typed, {
    required bool consentAskedAgain,
  }) async {
    var consentGone = false;
    FocusScope.of(context).unfocus();
    final exchange = _Exchange(
      kind: kind,
      question: kind == PlanAssistantKind.question ? typed : kind.label,
      typed: kind == PlanAssistantKind.question ? typed : null,
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
      if (!mounted) return false;
      if (kind == PlanAssistantKind.question) _questionController.clear();
      setState(() {
        exchange.answer = answer;
        _status = _status?.copyWith(remainingToday: answer.remainingToday);
      });
    } on ApiException catch (error) {
      if (!mounted) return false;
      setState(() {
        _exchanges.remove(exchange);
        if (error.serverCode == 'ASSISTANT_CONSENT_REQUIRED') {
          _status = _status?.copyWith(consentedAt: () => null);
          if (consentAskedAgain) {
            _askError = error.message;
          } else {
            consentGone = true;
          }
        } else if (error.serverCode == 'ASSISTANT_DAILY_LIMIT') {
          _stop = _Stop.limit;
        } else if (error.isNetworkFailure) {
          _stop = _Stop.offline;
        } else {
          _askError = error.message;
        }
      });
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _exchanges.remove(exchange);
        _askError = context.say(
          'ما وصلتنا إجابة. جرّب مرة ثانية.',
          'ما وصلتنا إجابة. جرّبي مرة ثانية.',
        );
      });
    } finally {
      if (mounted) setState(() => _asking = false);
    }
    return consentGone;
  }

  /// RA-ST-04 (D95): «بلّغ عن الإجابة»: why, then the answer to the team.
  Future<void> _report(_Exchange exchange) async {
    final answer = exchange.answer;
    if (answer == null || exchange.reported) return;
    final reason = await showReportReasonSheet(
      context,
      title: 'بلّغ عن الإجابة',
      note: 'فريق اعّرست يقرأ الإجابة وسببك، ويحسّن المساعد.',
      reasons: const ['كلام مسيء', 'معلومة غلط أو تضر'],
      keyPrefix: 'assistant-report',
    );
    if (reason == null || !mounted) return;
    try {
      await _api.reportAnswer(
        widget.weddingPlanId,
        answerId: answer.answerId,
        kind: exchange.kind,
        question: exchange.typed,
        answer: answer.answer,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => exchange.reported = true);
      AarastToast.showSuccess(context, 'وصل بلاغك، وفريق اعّرست بيراجعه.');
    } on ApiException catch (error) {
      if (!mounted) return;
      AarastToast.showError(
        context,
        error.serverCode == 'ASSISTANT_REPORT_LIMIT'
            ? context.say(
                'عندك بلاغات كثير ما راجعها الفريق بعد. جرّب بعدين.',
                'عندك بلاغات كثير ما راجعها الفريق بعد. جرّبي بعدين.',
              )
            : error.message,
      );
    } catch (_) {
      if (mounted) {
        AarastToast.showError(
          context,
          context.say(
            'ما قدرنا نرسل البلاغ. جرّب مرة ثانية.',
            'ما قدرنا نرسل البلاغ. جرّبي مرة ثانية.',
          ),
        );
      }
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
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                JourneySubHeader(
                  title: context.say('اسأل اعّرست', 'اسألي اعّرست'),
                  subtitle: context.say(
                    'يجاوبك من خطتك أنت، وما يخترع أسعار',
                    'يجاوبك من خطتك أنتِ، وما يخترع أسعار',
                  ),
                  onBack: _goBack,
                ),
                ..._body(status),
              ],
            ),
          ),
          if (usable)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x4,
                AarastV3Space.x1,
                AarastV3Space.x4,
                AarastV3Space.x3,
              ),
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
          text: 'المساعد مش شغّال في هذي النسخة بعد.',
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
      const SizedBox(height: AarastV3Space.x4),
      for (final exchange in _exchanges) ...[
        _QuestionBubble(exchange: exchange),
        const SizedBox(height: AarastV3Space.x2),
        if (exchange.answer case final answer?) ...[
          _AnswerCard(
            answer: answer,
            reported: exchange.reported,
            onReport: () => _report(exchange),
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
      ],
      if (_asking)
        Row(
          key: const ValueKey('assistant-thinking'),
          children: [
            AarastInlineSpinner(color: context.accent.primary),
            const SizedBox(width: AarastV3Space.x2),
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
                size: AarastV3Size.mark,
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
        constraints: const BoxConstraints(
          maxWidth: AarastV3Density.narrowWidth,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.accent.primary,
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(AarastV3Radius.card),
              topEnd: Radius.circular(AarastV3Radius.card),
              bottomEnd: Radius.circular(AarastV3Radius.card),
              bottomStart: Radius.circular(AarastV3Radius.xs),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x3,
              AarastV3Space.x4,
              AarastV3Space.x2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exchange.question,
                  key: const ValueKey('assistant-question-bubble'),
                  style: JourneyType.of(
                    JourneyType.lead,
                    color: AarastV3Color.onPrimary,
                  ),
                ),
                const SizedBox(height: AarastV3Space.half),
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

/// «من خطتك»: the answer, and the reminder that it is a suggestion. An
/// answer the model gave (not its refusal) can be reported (RA-ST-04).
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.answer,
    required this.reported,
    required this.onReport,
  });

  final PlanAssistantAnswer answer;
  final bool reported;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('assistant-answer'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.sparkles,
                size: AarastV3Icon.md,
                color: context.accent.primary,
              ),
              const SizedBox(width: AarastV3Space.x1),
              Text(
                'من خطتك',
                style: JourneyType.of(
                  JourneyType.small,
                  weight: JourneyType.bold,
                  color: context.accent.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x2),
          if (answer.answer.isNotEmpty)
            SelectableText(
              answer.answer,
              style: JourneyType.of(
                JourneyType.body,
                height: AarastV3Line.reading,
              ),
            ),
          // RA-BE-163: cut at the model's limit, it is not shown as whole.
          if (answer.truncated) ...[
            const SizedBox(height: AarastV3Space.x2),
            Text(
              context.say(
                'الجواب طويل، اسأل بشكل أضيق',
                'الجواب طويل، اسألي بشكل أضيق',
              ),
              key: const ValueKey('assistant-truncated'),
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
          if (!answer.declined && !answer.marketDataAvailable) ...[
            const SizedBox(height: AarastV3Space.x2),
            Text(
              'ما عندنا أسعار سوق لمدينتك بعد، فالأرقام هنا من خطتك بس.',
              key: const ValueKey('assistant-no-market'),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AarastV3Space.x2),
          Text(
            'اقتراح، والقرار لك.',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          if (!answer.declined && answer.answer.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: reported
                  ? Padding(
                      key: const ValueKey('assistant-reported'),
                      padding: const EdgeInsets.only(top: AarastV3Space.x2),
                      child: Text(
                        'بلّغت عنها، والفريق بيراجعها.',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    )
                  : JourneyTextAction(
                      key: const ValueKey('assistant-report'),
                      label: 'بلّغ عن الإجابة',
                      icon: LucideIcons.flag,
                      color: AarastV3Color.textMuted,
                      onPressed: onReport,
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
      padding: const EdgeInsets.only(top: AarastV3Space.x1),
      child: JourneyBox(
        padding: const EdgeInsets.all(AarastV3Space.x4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JourneyIconTile(icon: icon, color: color, soft: soft),
            const SizedBox(width: AarastV3Space.x3),
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
                  const SizedBox(height: AarastV3Space.half),
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
      padding: const EdgeInsetsDirectional.fromSTEB(
        AarastV3Space.x4,
        AarastV3Space.x1,
        AarastV3Space.x1,
        AarastV3Space.x1,
      ),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.feature),
        border: Border.all(color: AarastV3Color.fieldEdge),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.sparkles,
            size: AarastV3Icon.md,
            color: context.accent.primary,
          ),
          const SizedBox(width: AarastV3Space.x2),
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
              style: JourneyType.of(JourneyType.lead),
              cursorColor: context.accent.primary,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                hintText: context.say('اسأل عن عرسك…', 'اسألي عن عرسك…'),
                hintStyle: JourneyType.of(
                  JourneyType.lead,
                  color: AarastV3Color.textFaint,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AarastV3Space.x2,
                ),
              ),
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          // RA-MO-361: the pressable says its own word, so its tap is the
          // one a screen reader presses; a label over it hid that tap.
          AarastPressable(
            key: const ValueKey('assistant-send'),
            onTap: enabled ? onSend : null,
            semanticLabel: context.say('اسأل', 'اسألي'),
            borderRadius: BorderRadius.circular(AarastV3Radius.pill),
            // The circle is drawn 40; the finger gets the 48 of D74
            // around it (RA-MO-367).
            child: SizedBox.square(
              dimension: AarastV3Size.touch,
              child: Center(
                child: Container(
                  width: AarastV3Size.mark,
                  height: AarastV3Size.mark,
                  decoration: BoxDecoration(
                    color: enabled
                        ? context.accent.primary
                        : AarastV3Color.lineStrong,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.send,
                    size: AarastV3Icon.md,
                    color: AarastV3Color.onPrimary,
                  ),
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
/// question; RA-BE-160 made it say exactly what the server sends and keeps. «ويقرأ الفواتير» and «تقدر توقفه من الحساب» are dropped: no
/// receipt is read and no switch exists in the account.
class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet({required this.dailyLimit});

  final int dailyLimit;

  Widget _row(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AarastV3Icon.lg, color: context.accent.primary),
          const SizedBox(width: AarastV3Space.x3),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AarastV3Space.x4,
            vertical: AarastV3Space.x2,
          ),
          child: Column(
            children: [
              _row(
                context,
                LucideIcons.send,
                'سؤالك وملخص خطتك يروحون لخدمة Claude من Anthropic تفهمه: المدينة والموعد، والميزانية وبنودها، والعروض، وعدد الضيوف والمهام',
              ),
              // Item 8: item names go as written, so «no name at all»
              // was not true.
              _row(
                context,
                LucideIcons.eyeOff,
                'ما نرسل أسماء الأشخاص، وأسماء البنود تروح كما كتبتها. ولا رقم جوال، ولا اسم الخطة ولا مهامها',
              ),
              _row(
                context,
                LucideIcons.users,
                'أرقام مال الخطة ما تروح مع سؤال الشريك إلا بموافقة صاحب الخطة',
              ),
              _row(
                context,
                LucideIcons.checkCircle2,
                'ما نحفظ أسئلتك ولا الإجابات، بس تاريخ موافقتك، وما يتغيّر شيء في خطتك',
              ),
              _row(
                context,
                LucideIcons.clock,
                'عند Anthropic تنحفظ حسب سياسة خدمتها، وما تدرّب عليها نماذجها',
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
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('assistant-consent-agree'),
          label: context.say('شغّل المساعد', 'شغّلي المساعد'),
          icon: LucideIcons.sparkles,
          expand: true,
          large: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AarastV3Space.x1),
        Center(
          child: JourneyTextAction(
            label: 'مش الحين',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    );
  }
}
