import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/whatsapp_share.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/rafd.dart';
import '../providers/rafd_provider.dart';

/// e10's message to one giver: his first name, thanks for coming and for
/// the gift, never the amount (C23), signed with the owner's name.
String rafdThanksMessage({
  required RafdEntry entry,
  required String signature,
  required bool bridePlan,
}) {
  final gift = bridePlan ? 'وهديتك' : 'ورفدك';
  return [
    'الله يجزاك خير يا ${entry.firstName} على حضورك $gift',
    'فرحتنا كملت بوجودك، وعقبال أفراحكم.',
    if (signature.trim().isNotEmpty) signature.trim(),
  ].join('\n');
}

/// e10 «رسالة الشكر»: each giver gets the message with his own name, from
/// the phone's WhatsApp one after another; the app sends nothing itself
/// (D66). Once WhatsApp opens with his message, he counts as thanked.
Future<void> showRafdThanksSheet(
  BuildContext context, {
  required String weddingPlanId,
  required RafdProvider provider,
  required String signature,
  Future<bool> Function(String text) share = shareOnWhatsApp,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => RafdThanksSheet(
      weddingPlanId: weddingPlanId,
      provider: provider,
      signature: signature,
      share: share,
    ),
  );
}

class RafdThanksSheet extends StatefulWidget {
  const RafdThanksSheet({
    required this.weddingPlanId,
    required this.provider,
    required this.signature,
    required this.share,
    super.key,
  });

  final String weddingPlanId;
  final RafdProvider provider;
  final String signature;
  final Future<bool> Function(String text) share;

  @override
  State<RafdThanksSheet> createState() => _RafdThanksSheetState();
}

class _RafdThanksSheetState extends State<RafdThanksSheet> {
  bool _sending = false;
  String? _error;

  Future<void> _sendNext(RafdEntry entry, String message) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final opened = await widget.share(message);
    if (!mounted) return;
    if (!opened) {
      setState(() {
        _sending = false;
        _error = 'ما قدرنا نفتح واتساب في هذا الجوال.';
      });
      return;
    }
    try {
      await widget.provider.markThanked(widget.weddingPlanId, [entry]);
      if (mounted) setState(() => _sending = false);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final book = widget.provider.bookOf(widget.weddingPlanId);
        final queue = book?.toThank ?? const <RafdEntry>[];
        final bride = context.journeyProfile.isBride;
        final next = queue.isEmpty ? null : queue.first;
        final message = next == null
            ? null
            : rafdThanksMessage(
                entry: next,
                signature: widget.signature,
                bridePlan: bride,
              );
        return JourneySheetBody(
          title: 'رسالة الشكر',
          subtitle: context.planWord(
            'تنرسل لكل واحد باسمه',
            'تنرسل لكل وحدة باسمها',
          ),
          bottom: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error case final error?) ...[
                JourneyNote(
                  text: error,
                  icon: LucideIcons.alertCircle,
                  color: AarastV3Color.danger,
                  soft: AarastV3Color.dangerSoft,
                ),
                const SizedBox(height: 8),
              ],
              if (next != null)
                JourneyButton(
                  key: const ValueKey('rafd-thanks-send'),
                  label:
                      '${context.say('أرسل', 'أرسلي')} لـ ${queue.length}',
                  icon: LucideIcons.send,
                  background: AarastV3Color.brandAccentStrong,
                  expand: true,
                  large: true,
                  loading: _sending,
                  onPressed: _sending ? null : () => _sendNext(next, message!),
                )
              else
                JourneyButton(
                  label: context.say('تمام', 'تمام'),
                  expand: true,
                  large: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
          children: [
            if (message != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  key: const ValueKey('rafd-thanks-message'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AarastV3Color.mintSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message,
                    style: JourneyType.of(JourneyType.body, height: 1.6),
                  ),
                ),
              )
            else
              JourneyNote(
                text: context.say(
                  'شكرت كل اللي سجّلتهم.',
                  'شكرتِ كل اللي سجّلتيهم.',
                ),
                icon: LucideIcons.heartHandshake,
                color: AarastV3Color.mint,
                soft: AarastV3Color.mintSoft,
              ),
            const SizedBox(height: 14),
            if (queue.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    LucideIcons.users,
                    size: 20,
                    color: AarastV3Color.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bride
                          ? '${queue.length} باقيات ما ${context.say('شكرتهن', 'شكرتيهن')}'
                          : '${queue.length} باقين ما ${context.say('شكرتهم', 'شكرتيهم')}',
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'نفتح واتساب برسالة ${context.planWord('باسمه', 'باسمها')}، '
              'و${context.say('أنت تختار المحادثة وترسل', 'أنتِ تختارين المحادثة وترسلين')}.',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
        );
      },
    );
  }
}
