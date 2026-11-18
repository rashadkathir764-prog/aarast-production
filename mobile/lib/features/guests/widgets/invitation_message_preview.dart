import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';

/// D116: the invitation's text as WhatsApp shows it, for the previews on the
/// card and send screens. The text itself is the server's, unchanged; only
/// its drawing follows WhatsApp: `*الزفاف*` is bold without its stars, and
/// each link is kept left to right inside the Arabic (drawn bare, a link
/// came out reversed, «…/https://», and broke at its dashes).
class InvitationMessagePreview extends StatelessWidget {
  const InvitationMessagePreview({required this.text, super.key});

  final String text;

  static final _parts = RegExp(r'\*([^*\n]+)\*|(https?://\S+)');

  /// Left-to-right isolate around a link, so the paragraph's direction does
  /// not reorder it.
  static final _ltrStart = String.fromCharCode(0x2066);
  static final _ltrEnd = String.fromCharCode(0x2069);

  @override
  Widget build(BuildContext context) {
    final base = JourneyType.of(
      JourneyType.small,
      height: AarastV3Line.reading,
    );
    final spans = <InlineSpan>[];
    var at = 0;
    for (final match in _parts.allMatches(text)) {
      if (match.start > at) {
        spans.add(TextSpan(text: text.substring(at, match.start)));
      }
      final bold = match.group(1);
      spans.add(
        bold != null
            ? TextSpan(
                text: bold,
                style: const TextStyle(fontWeight: JourneyType.bold),
              )
            : TextSpan(
                text: '$_ltrStart${match.group(2)}$_ltrEnd',
                style: TextStyle(color: context.accent.primary),
              ),
      );
      at = match.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
