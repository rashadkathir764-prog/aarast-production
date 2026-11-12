import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/whatsapp_share.dart';
import 'aarast_bottom_sheet.dart';
import 'aarast_toast.dart';
import '../experience_v3/aarast_v3_foundations.dart';

/// Shows the exact text before it leaves the app, with an optional switch
/// (for example "hide amounts"), then hands it to WhatsApp (V1 checklist
/// 4.16). Nothing is uploaded: the text goes from this device to WhatsApp.
Future<void> showAarastShareSheet({
  required BuildContext context,
  required String title,
  required String Function(bool switchOn) buildText,
  String? switchLabel,
  bool switchInitial = false,
}) {
  return showAarastBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(
      title: title,
      buildText: buildText,
      switchLabel: switchLabel,
      switchInitial: switchInitial,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.title,
    required this.buildText,
    required this.switchLabel,
    required this.switchInitial,
  });

  final String title;
  final String Function(bool switchOn) buildText;
  final String? switchLabel;
  final bool switchInitial;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late bool _switchOn = widget.switchInitial;

  Future<void> _send(String text) async {
    final opened = await shareOnWhatsApp(text);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      AarastToast.showError(context, 'ما قدرنا نفتح واتساب على هذا الجوال.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.buildText(_switchOn);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AarastV3Space.x4,
          AarastV3Space.x2,
          AarastV3Space.x4,
          AarastV3Space.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (widget.switchLabel != null)
              SwitchListTile(
                key: const Key('share-sheet-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(widget.switchLabel!),
                value: _switchOn,
                onChanged: (value) => setState(() => _switchOn = value),
              ),
            const SizedBox(height: AarastV3Space.x2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Container(
                padding: const EdgeInsets.all(AarastV3Space.x3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    key: const Key('share-sheet-preview'),
                    style: textTheme.bodySmall?.copyWith(height: 1.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AarastV3Space.x3),
            FilledButton.icon(
              onPressed: () => _send(text),
              icon: const Icon(LucideIcons.send),
              label: const Text('إرسال عبر واتساب'),
            ),
          ],
        ),
      ),
    );
  }
}
