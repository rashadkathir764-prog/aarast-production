import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/report_reason_sheet.dart';
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
  return showReportReasonSheet(
    context,
    title: 'بلّغ عن التقييم',
    note: 'فريق اعّرست يراجعه. التقييم يبقى ظاهر لين يقرر.',
    reasons: const ['كلام مسيء', 'كلام كاذب'],
    keyPrefix: 'review-report',
  );
}
