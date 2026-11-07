import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../providers/marketplace_provider.dart';

/// RA-ST-05 (D94): the one report flow, from the provider's page and from
/// the provider's own review (p27): the sheet, the report to the team, and
/// a toast that says it arrived or why not. Closing the sheet sends nothing.
Future<void> reportProviderReview(BuildContext context, String reviewId) async {
  final reason = await showReviewReportSheet(context);
  if (reason == null || !context.mounted) return;
  final failure = await context
      .read<ProviderMarketplaceProvider>()
      .reportReview(reviewId, reason);
  if (!context.mounted) return;
  if (failure == null) {
    AarastToast.showSuccess(context, 'وصل بلاغك، وفريق اعّرست بيراجعه.');
  } else {
    AarastToast.showError(context, failure);
  }
}

/// RA-ST-05 (D94): «بلّغ عن التقييم». The reader picks why, and «شي ثاني»
/// asks for their own words; the answer is the reason sent to the
/// moderation team, or null when the sheet is closed. The review stays
/// shown until the team decides, and the sheet says so.
Future<String?> showReviewReportSheet(BuildContext context) {
  return showJourneySheet<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _ReviewReportSheet(),
  );
}

const _offensive = 'كلام مسيء';
const _false = 'كلام كاذب';
const _other = 'شي ثاني';

class _ReviewReportSheet extends StatefulWidget {
  const _ReviewReportSheet();

  @override
  State<_ReviewReportSheet> createState() => _ReviewReportSheetState();
}

class _ReviewReportSheetState extends State<_ReviewReportSheet> {
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
    _other => _words.text.trim().isEmpty ? null : _words.text.trim(),
    final picked => picked,
  };

  @override
  Widget build(BuildContext context) {
    final reason = _reason;
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
            'بلّغ عن التقييم',
            style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            'فريق اعّرست يراجعه. التقييم يبقى ظاهر لين يقرر.',
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
              for (final option in const [_offensive, _false, _other])
                JourneyChip(
                  key: ValueKey('review-report-reason-$option'),
                  label: option,
                  selected: _picked == option,
                  selectedColor: context.accent.primary,
                  onTap: () => setState(() => _picked = option),
                ),
            ],
          ),
          if (_picked == _other) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyTextField(
              key: const ValueKey('review-report-words'),
              label: 'وش المشكلة؟',
              controller: _words,
              maxLines: 3,
              maxLength: 500,
            ),
          ],
          const SizedBox(height: AarastV3Space.x4),
          JourneyButton(
            key: const ValueKey('review-report-send'),
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
