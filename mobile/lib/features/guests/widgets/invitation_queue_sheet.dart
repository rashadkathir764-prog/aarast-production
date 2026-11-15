import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart' show ApiException;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invitations.dart';
import '../models/guest_invite_text.dart';
import '../utils/invitation_share.dart';
import 'guest_invitation_card_image.dart';

/// The card drawn small in the turn, a fixed picture area (D74).
const double _cardPreviewHeight = 200;

/// One guest's turn in a round of sends: what the text is and, for an
/// invitation of its own, the occasion it is about.
typedef InvitationTurn = ({
  Guest guest,
  InvitationSendKind kind,
  String? planEventId,
});

/// D116: sends to [turns] one after another from this phone's own WhatsApp.
/// Each guest's turn is two steps: the text to the guest's own chat (the
/// server's words and the guest's link, by WhatsApp's documented link), then
/// the card as a picture (Android's standard share; WhatsApp asks for the
/// chat, the guest's first). Back from WhatsApp, the person says whether it
/// was sent: only that counts, never opening WhatsApp. A send prepared
/// before and never answered is asked about first, so nobody gets the same
/// invitation twice by mistake.
class InvitationQueueSheet extends StatefulWidget {
  const InvitationQueueSheet({
    required this.turns,
    required this.api,
    required this.title,
    this.cardFor,
    this.readyCard,
    super.key,
  });

  final List<InvitationTurn> turns;
  final GuestsApi api;
  final String title;

  /// The card Aarast lays out for a guest, drawn here and sent as a picture;
  /// null when a ready card is sent instead, or none.
  final Widget Function(Guest guest)? cardFor;

  /// A card designed elsewhere, sent as it is.
  final Future<Uint8List?> Function()? readyCard;

  @override
  State<InvitationQueueSheet> createState() => _InvitationQueueSheetState();
}

enum _Phase { askEarlier, ready, textOpened }

class _InvitationQueueSheetState extends State<InvitationQueueSheet> {
  final _cardKey = GlobalKey();
  int _index = 0;
  int _sent = 0;
  bool _busy = false;
  bool _canShareImage = false;
  bool _imageHanded = false;
  String? _error;
  String? _notice;
  GuestInvitationLink? _link;
  late _Phase _phase = _phaseFor(0);

  bool get _done => _index >= widget.turns.length;
  bool get _hasCard => widget.cardFor != null || widget.readyCard != null;

  @override
  void initState() {
    super.initState();
    InvitationShare.canShareImage().then((value) {
      if (mounted) setState(() => _canShareImage = value);
    });
  }

  _Phase _phaseFor(int index) {
    if (index >= widget.turns.length) return _Phase.ready;
    return widget.turns[index].guest.lastSend?.awaitsAnswer == true
        ? _Phase.askEarlier
        : _Phase.ready;
  }

  void _next({required bool sent}) {
    setState(() {
      if (sent) _sent++;
      _index++;
      _link = null;
      _imageHanded = false;
      _error = null;
      _notice = null;
      _phase = _phaseFor(_index);
    });
  }

  Future<bool> _settle(String sendId, {required bool sent}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.settleInvitationSend(sendId, sent: sent);
      return true;
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
      return false;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.say(
            'ما قدرنا نسجّلها. تأكد من النت وجرّب مرة ثانية.',
            'ما قدرنا نسجّلها. تأكدي من النت وجرّبي مرة ثانية.',
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The earlier send, prepared and never answered: was it sent?
  Future<void> _answerEarlier({required bool sent}) async {
    final earlier = widget.turns[_index].guest.lastSend!;
    if (!await _settle(earlier.id, sent: sent) || !mounted) return;
    if (sent) {
      // It reached them: this round has nothing more for them.
      _next(sent: false);
    } else {
      setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _openText() async {
    final turn = widget.turns[_index];
    if (!guestChatCanOpen(turn.guest.phone)) {
      setState(() => _error = guestNumberWithoutCountry(turn.guest.name));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link =
          _link ??
          await widget.api.createInvitationLink(
            turn.guest.id,
            kind: turn.kind.wire,
            planEventId: turn.planEventId,
          );
      _link = link;
      final chat = guestWhatsAppUri(
        link.phone ?? turn.guest.phone,
        link.message,
      );
      if (chat == null) {
        if (mounted) {
          setState(() => _error = guestNumberWithoutCountry(turn.guest.name));
        }
        return;
      }
      final opened = await launchUrl(
        chat,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        setState(() => _error = 'ما قدرنا نفتح واتساب في هذا الجوال');
        return;
      }
      setState(() => _phase = _Phase.textOpened);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'ما قدرنا نجهّز دعوة ${turn.guest.name}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCard() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final bytes = widget.readyCard != null
          ? await widget.readyCard!()
          : await captureCard(_cardKey);
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _error = 'ما قدرنا نجهّز صورة البطاقة');
        return;
      }
      final result = await InvitationShare.shareImage(bytes);
      if (!mounted) return;
      setState(() {
        _imageHanded = result == 'opened';
        if (result != 'opened') {
          _error = 'ما قدرنا نفتح واتساب للصورة. النص يكفي ويوصله كل شي.';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answerThis({required bool sent}) async {
    final link = _link;
    if (link?.sendId case final sendId?) {
      if (!await _settle(sendId, sent: sent) || !mounted) return;
    }
    _next(sent: sent);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.turns.length;
    return JourneySheetBody(
      title: widget.title,
      subtitle: _done
          ? 'انرسلت لـ $_sent من $total'
          : 'التالي ${_index + 1} من $total',
      children: [
        JourneyBar(
          value: total == 0 ? 1 : _index / total,
          color: context.accent.primary,
        ),
        const SizedBox(height: AarastV3Space.x4),
        if (_done) ..._doneParts(context) else ..._turnParts(context),
      ],
    );
  }

  List<Widget> _doneParts(BuildContext context) => [
    JourneyNote(
      key: const ValueKey('queue-done'),
      text: context.say(
        'خلصت. كل واحد يرد من رابطه، ويتحدث ردّه في قائمتك.',
        'خلصت. كل واحد يرد من رابطه، ويتحدث ردّه في قائمتك.',
      ),
      icon: LucideIcons.checkCircle2,
    ),
    const SizedBox(height: AarastV3Space.x4),
    JourneyButton(
      key: const ValueKey('queue-close'),
      label: 'تمام',
      expand: true,
      onPressed: () => Navigator.of(context).pop(_sent),
    ),
  ];

  List<Widget> _turnParts(BuildContext context) {
    final turn = widget.turns[_index];
    final guest = turn.guest;
    final kindWords = switch (turn.kind) {
      InvitationSendKind.invitation => 'دعوة',
      InvitationSendKind.addition => 'مناسبة زيادة',
      InvitationSendKind.change => 'تغيير في الموعد أو المكان',
      InvitationSendKind.reminder => 'تذكير',
    };
    return [
      Text(
        guest.name,
        key: const ValueKey('queue-guest'),
        style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
      ),
      Text(
        kindWords,
        style: JourneyType.of(
          JourneyType.small,
          color: AarastV3Color.textMuted,
        ),
      ),
      const SizedBox(height: AarastV3Space.x3),
      if (_phase == _Phase.askEarlier) ...[
        JourneyNote(
          key: const ValueKey('queue-earlier'),
          text: context.say(
            'جهّزنا دعوة لـ${guest.name} قبل، وما قلت إنها انرسلت. انرسلت؟',
            'جهّزنا دعوة لـ${guest.name} قبل، وما قلتِ إنها انرسلت. انرسلت؟',
          ),
          icon: LucideIcons.helpCircle,
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          key: const ValueKey('queue-earlier-sent'),
          label: 'أيوه، انرسلت',
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : () => _answerEarlier(sent: true),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyButton.outline(
          key: const ValueKey('queue-earlier-not-sent'),
          label: 'لا، ما انرسلت',
          expand: true,
          onPressed: _busy ? null : () => _answerEarlier(sent: false),
        ),
      ] else ...[
        _Step(
          number: 1,
          title: context.say('افتح واتساب بالدعوة', 'افتحي واتساب بالدعوة'),
          done: _phase == _Phase.textOpened,
          child: _phase == _Phase.textOpened
              ? JourneyButton.outline(
                  key: const ValueKey('queue-open-text'),
                  label: context.say('افتحه مرة ثانية', 'افتحيه مرة ثانية'),
                  icon: LucideIcons.messageCircle,
                  expand: true,
                  onPressed: _busy ? null : _openText,
                )
              : JourneyButton(
                  key: const ValueKey('queue-open-text'),
                  label: '${context.say('افتح', 'افتحي')} محادثة ${guest.name}',
                  icon: LucideIcons.messageCircle,
                  expand: true,
                  loading: _busy,
                  onPressed: _busy ? null : _openText,
                ),
        ),
        if (_hasCard && _canShareImage) ...[
          const SizedBox(height: AarastV3Space.x3),
          _Step(
            number: 2,
            title: 'البطاقة صورة',
            done: _imageHanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.cardFor case final cardFor?)
                  Center(
                    child: SizedBox(
                      height: _cardPreviewHeight,
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: cardFor(guest),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AarastV3Space.x2),
                JourneyButton.outline(
                  key: const ValueKey('queue-share-card'),
                  label: '${context.say('أرسل', 'أرسلي')} البطاقة صورة',
                  icon: LucideIcons.image,
                  expand: true,
                  onPressed: _busy || _phase != _Phase.textOpened
                      ? null
                      : _shareCard,
                ),
                const SizedBox(height: AarastV3Space.x1),
                Text(
                  context.say(
                    'واتساب بيسألك لمين: اختر محادثة ${guest.name}، هي أول وحدة.',
                    'واتساب بيسألك لمين: اختاري محادثة ${guest.name}، هي أول وحدة.',
                  ),
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_phase == _Phase.textOpened) ...[
          const SizedBox(height: AarastV3Space.x4),
          Text(
            context.say('أرسلت لـ${guest.name}؟', 'أرسلتِ لـ${guest.name}؟'),
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton(
            key: const ValueKey('queue-sent'),
            label: context.say('أرسلتها، التالي', 'أرسلتها، التالي'),
            expand: true,
            loading: _busy,
            onPressed: _busy ? null : () => _answerThis(sent: true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.outline(
            key: const ValueKey('queue-not-sent'),
            label: 'ما أرسلتها',
            expand: true,
            onPressed: _busy ? null : () => _answerThis(sent: false),
          ),
        ],
      ],
      if (_error case final error?) ...[
        const SizedBox(height: AarastV3Space.x3),
        Text(
          error,
          key: const ValueKey('queue-error'),
          style: JourneyType.of(
            JourneyType.bodySmall,
            weight: JourneyType.bold,
            color: AarastV3Color.danger,
          ),
        ),
      ],
      if (_notice case final notice?) ...[
        const SizedBox(height: AarastV3Space.x2),
        Text(notice, style: JourneyType.of(JourneyType.small)),
      ],
      const SizedBox(height: AarastV3Space.x3),
      Row(
        children: [
          if (_phase == _Phase.ready)
            Expanded(
              child: JourneyTextAction(
                key: const ValueKey('queue-skip'),
                label:
                    '${context.say('تخطّا', 'تخطّي')}${context.planWord('ه', 'ها')}',
                color: AarastV3Color.textMuted,
                onPressed: _busy ? null : () => _next(sent: false),
              ),
            ),
          Expanded(
            child: JourneyTextAction(
              key: const ValueKey('queue-stop'),
              label: context.say('وقّف هنا', 'وقّفي هنا'),
              color: AarastV3Color.textMuted,
              onPressed: _busy ? null : () => Navigator.of(context).pop(_sent),
            ),
          ),
        ],
      ),
    ];
  }
}

/// One step of a guest's turn, numbered, marked when done.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.done,
    required this.child,
  });

  final int number;
  final String title;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? context.accent.primary
                    : context.accent.primarySoft,
              ),
              child: done
                  ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                  : Text(
                      '$number',
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            // A long title wraps under itself instead of running off a
            // narrow screen with large text.
            Expanded(
              child: Text(
                title,
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x2),
        child,
      ],
    );
  }
}
