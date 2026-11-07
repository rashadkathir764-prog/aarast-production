import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../experience_v3/aarast_v3.dart';

/// «شي ثاني»: the last reason, which asks for the reader's own words.
const reportOtherReason = 'شي ثاني';

/// The one sheet that asks why something is reported to the team: a review
/// (RA-ST-05, D94) or an assistant answer (RA-ST-04, D95). The reader picks
/// one of [reasons]; [reportOtherReason] asks for their own words. Returns
/// the reason to send, or null when the sheet is closed. [keyPrefix] names
/// the sheet's parts for tests («$keyPrefix-reason-…», «-words», «-send»).
Future<String?> showReportReasonSheet(
  BuildContext context, {
  required String title,
  required String note,
  required List<String> reasons,
  required String keyPrefix,
}) {
  return showJourneySheet<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _ReportReasonSheet(
      title: title,
      note: note,
      reasons: [...reasons, reportOtherReason],
      keyPrefix: keyPrefix,
    ),
  );
}

class _ReportReasonSheet extends StatefulWidget {
  const _ReportReasonSheet({
    required this.title,
    required this.note,
    required this.reasons,
    required this.keyPrefix,
  });

  final String title;
  final String note;
  final List<String> reasons;
  final String keyPrefix;

  @override
  State<_ReportReasonSheet> createState() => _ReportReasonSheetState();
}

class _ReportReasonSheetState extends State<_ReportReasonSheet> {
  final _words = TextEditingController();
  String? _picked;

  @override
  void initState() {
    super.initState();
    _words.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  String? get _reason => switch (_picked) {
    null => null,
    reportOtherReason => _words.text.trim().isEmpty ? null : _words.text.trim(),
    final picked => picked,
  };

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
    final prefix = widget.keyPrefix;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AarastV3Space.x4,
        AarastV3Space.x2,
        AarastV3Space.x4,
        AarastV3Space.x4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            widget.note,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          Wrap(
            spacing: AarastV3Space.x2,
            runSpacing: AarastV3Space.x2,
            children: [
              for (final option in widget.reasons)
                JourneyChip(
                  key: ValueKey('$prefix-reason-$option'),
                  label: option,
                  selected: _picked == option,
                  selectedColor: context.accent.primary,
                  onTap: () => setState(() => _picked = option),
                ),
            ],
          ),
          if (_picked == reportOtherReason) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyTextField(
              key: ValueKey('$prefix-words'),
              label: 'وش المشكلة؟',
              controller: _words,
              maxLines: 3,
              maxLength: 500,
            ),
          ],
          const SizedBox(height: AarastV3Space.x4),
          JourneyButton(
            key: ValueKey('$prefix-send'),
            label: 'أرسل البلاغ',
            icon: LucideIcons.flag,
            expand: true,
            large: true,
            onPressed: reason == null
                ? null
                : () => Navigator.of(context).pop(reason),
          ),
        ],
      ),
    );
  }
}
