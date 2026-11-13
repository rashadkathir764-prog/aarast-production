import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/name_letter.dart';
import '../../../core/network/api_client.dart' show ApiException;
import '../models/guest.dart';
import '../models/guest_invite_text.dart';

/// Sends to [guests] one after another from this phone's WhatsApp (C30):
/// each guest's own link and text are made when their turn comes (the text
/// is the server's, D83), and their chat opens with it ready. Closing keeps
/// what was sent.
class GuestSendSheet extends StatefulWidget {
  const GuestSendSheet({
    required this.guests,
    required this.makeLink,
    required this.title,
    super.key,
  });

  final List<Guest> guests;

  /// The guest's own RSVP link and message, made now (a new link replaces
  /// the old).
  final Future<GuestInvitationLink> Function(Guest guest) makeLink;
  final String title;

  @override
  State<GuestSendSheet> createState() => _GuestSendSheetState();
}

class _GuestSendSheetState extends State<GuestSendSheet> {
  int _index = 0;
  int _sent = 0;
  bool _busy = false;
  String? _error;

  bool get _done => _index >= widget.guests.length;

  Future<void> _send() async {
    final guest = widget.guests[_index];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await widget.makeLink(guest);
      final opened = await launchUrl(
        guestWhatsAppUri(guest.phone ?? link.phone, link.message),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        setState(() => _error = 'ما قدرنا نفتح واتساب في هذا الجوال');
        return;
      }
      setState(() {
        _sent++;
        _index++;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'ما قدرنا نجهّز رابط ${guest.name}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.guests.length;
    return JourneySheetBody(
      title: widget.title,
      subtitle: _done
          ? 'انرسلت لـ $_sent من $total'
          : 'التالي ${_index + 1} من $total',
      children: [
        JourneyBar(
          value: total == 0 ? 1 : _index / total,
          color: AarastV3Color.mint,
        ),
        const SizedBox(height: AarastV3Space.x4),
        if (_done)
          JourneyNote(
            text: context.planWord(
              'خلصت. كل واحد يرد من رابطه ويتحدث ردّه في قائمتك.',
              'خلصت. كل وحدة ترد من رابطها ويتحدث ردّها في قائمتك.',
            ),
            icon: LucideIcons.checkCircle2,
            color: AarastV3Color.mint,
            soft: AarastV3Color.mintSoft,
          )
        else ...[
          JourneyBox(
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: Row(
              children: [
                JourneyAvatar(
                  letter: nameLetter(widget.guests[_index].name),
                  color: context.accent.primary,
                  size: 40,
                ),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Text(
                    widget.guests[_index].name,
                    key: const ValueKey('guest-send-current'),
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AarastV3Space.x2),
            Text(
              _error!,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ],
        ],
        const SizedBox(height: AarastV3Space.x4),
        if (_done)
          JourneyButton(
            key: const ValueKey('guest-send-close'),
            label: 'تمام',
            expand: true,
            large: true,
            onPressed: () => Navigator.pop(context, _sent),
          )
        else ...[
          JourneyButton(
            key: const ValueKey('guest-send-open'),
            label:
                '${context.say('افتح', 'افتحي')} واتساب لـ${widget.guests[_index].name}',
            icon: LucideIcons.send,
            background: AarastV3Color.mint,
            expand: true,
            large: true,
            loading: _busy,
            onPressed: _busy ? null : _send,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              JourneyTextAction(
                key: const ValueKey('guest-send-skip'),
                label:
                    '${context.say('تخطّا', 'تخطّي')}${context.planWord('ه', 'ها')}',
                onPressed: _busy ? null : () => setState(() => _index++),
              ),
              // RA-MO-233: stopping midway was only a swipe down; it keeps
              // what was sent and leaves the rest for later.
              JourneyTextAction(
                key: const ValueKey('guest-send-stop'),
                label: context.say('وقّف هنا', 'وقّفي هنا'),
                color: AarastV3Color.textMuted,
                onPressed: _busy ? null : () => Navigator.pop(context, _sent),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
