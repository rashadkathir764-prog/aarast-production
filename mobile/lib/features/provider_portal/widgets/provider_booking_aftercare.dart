import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../marketplace/marketplace_api.dart' show MarketplaceBooking;
import '../providers/provider_dashboard_provider.dart';

/// G25 (B-22, B-23, B-24): what the provider does after a booking is
/// confirmed: answer a new day the customer asked for, say «تم» or «ما صار»
/// after the day, and deliver. Each step goes to the server and reloads the
/// dashboard; the screen closes on success so it never shows a stale copy.
class ProviderBookingAftercare extends StatelessWidget {
  const ProviderBookingAftercare({
    required this.booking,
    required this.customerFirstName,
    this.now,
    super.key,
  });

  final MarketplaceBooking booking;
  final String customerFirstName;

  /// Today, for tests; the clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();
    final change = booking.change;
    final children = <Widget>[
      if (change != null && change.isPending)
        JourneyBox(
          key: const Key('provider-booking-change'),
          color: AarastV3Color.brandAccentSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$customerFirstName غيّر موعد العرس',
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                ),
              ),
              Text(
                'من ${formatArabicWeekdayDayMonth(change.fromDate)} '
                'إلى ${formatArabicWeekdayDayMonth(change.toDate)}',
                style: JourneyType.of(JourneyType.bodySmall),
              ),
              if (change.note case final note?)
                Text('«$note»', style: JourneyType.of(JourneyType.bodySmall)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: JourneyButton(
                      key: const Key('provider-booking-change-accept'),
                      label: 'ثبّت الموعد الجديد',
                      expand: true,
                      onPressed: () => _decideChange(context, accept: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: JourneyButton(
                      key: const Key('provider-booking-change-decline'),
                      label: 'ما أقدر',
                      background: AarastV3Color.paper,
                      foreground: AarastV3Color.danger,
                      expand: true,
                      onPressed: () => _decideChange(context, accept: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (booking.canRecordOutcome(today))
        JourneyBox(
          key: const Key('provider-booking-outcome'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم العرس؟',
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                ),
              ),
              Text(
                'لو ما قلت شي خلال يومين ينحسب تم.',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: JourneyButton(
                      key: const Key('provider-booking-complete'),
                      label: 'تم',
                      icon: LucideIcons.checkCircle,
                      expand: true,
                      onPressed: () => _outcome(context, happened: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: JourneyButton(
                      key: const Key('provider-booking-not-happened'),
                      label: 'ما صار',
                      background: AarastV3Color.paper,
                      foreground: AarastV3Color.ink,
                      expand: true,
                      onPressed: () => _outcome(context, happened: false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (booking.notHappenedAt != null)
        JourneyNote(
          key: const Key('provider-booking-not-happened-note'),
          text:
              'سجّلت إن العرس ما صار: '
              '${_notHappenedWords[booking.notHappenedReason] ?? ''}',
          icon: LucideIcons.calendarX,
        ),
      if (booking.canDeliver)
        JourneyBox(
          key: const Key('provider-booking-delivery'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التسليم',
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                ),
              ),
              if (booking.deliveryDueAt case final due?)
                Text(
                  'وعدت تسلّم قبل ${formatArabicDayMonth(due.toLocal())}',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: due.isBefore(today)
                        ? AarastV3Color.danger
                        : AarastV3Color.textMuted,
                  ),
                ),
              const SizedBox(height: 10),
              JourneyButton(
                key: const Key('provider-booking-deliver'),
                label: 'سلّمت',
                icon: LucideIcons.packageCheck,
                expand: true,
                onPressed: () => _deliver(context),
              ),
            ],
          ),
        ),
      if (booking.deliveredAt case final delivered?)
        JourneyNote(
          key: const Key('provider-booking-delivered'),
          text: booking.deliveryConfirmedAt != null
              ? '$customerFirstName أكّد إنه استلم.'
              : 'سلّمت ${formatArabicDayMonth(delivered.toLocal())}، '
                    'وننتظر $customerFirstName يأكّد.',
          icon: LucideIcons.packageCheck,
          color: AarastV3Color.mint,
          soft: AarastV3Color.mintSoft,
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children) ...[const SizedBox(height: 10), child],
      ],
    );
  }

  Future<void> _decideChange(
    BuildContext context, {
    required bool accept,
  }) async {
    final change = booking.change;
    if (change == null) return;
    String? reason;
    if (!accept) {
      reason = await _askText(
        context,
        title: 'ليش ما تقدر؟',
        hint: 'مثل: عندنا عرس ذاك اليوم',
      );
      if (reason == null || !context.mounted) return;
    }
    final dashboard = context.read<ProviderDashboardProvider>();
    final done = await dashboard.decideBookingChange(
      changeId: change.id,
      accept: accept,
      reason: reason,
    );
    if (!context.mounted) return;
    _finish(
      context,
      done,
      accept ? 'ثبّتنا الموعد الجديد، ووصله خبر.' : 'وصله ردك، والحجز باقي.',
      dashboard.errorMessage,
    );
  }

  Future<void> _outcome(BuildContext context, {required bool happened}) async {
    String? reason;
    if (!happened) {
      reason = await showJourneySheet<String>(
        context: context,
        builder: (sheetContext) => JourneySheetBody(
          title: 'ليش ما صار؟',
          children: [
            for (final entry in _notHappenedWords.entries) ...[
              JourneyOption(
                key: Key('provider-not-happened-${entry.key}'),
                title: entry.value,
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
      if (reason == null || !context.mounted) return;
    }
    final dashboard = context.read<ProviderDashboardProvider>();
    final done = await dashboard.recordBookingOutcome(
      bookingId: booking.id,
      happened: happened,
      reason: reason,
    );
    if (!context.mounted) return;
    _finish(
      context,
      done,
      happened ? 'ألف مبروك! انسجّل إن العرس تم.' : 'انسجّل، ووصله خبر.',
      dashboard.errorMessage,
    );
  }

  Future<void> _deliver(BuildContext context) async {
    final link = await _askText(
      context,
      title: 'رابط التسليم',
      hint: 'رابط التحميل لو عندك',
      optional: true,
    );
    if (link == null || !context.mounted) return;
    final dashboard = context.read<ProviderDashboardProvider>();
    final done = await dashboard.deliverBooking(
      bookingId: booking.id,
      link: link.isEmpty ? null : link,
    );
    if (!context.mounted) return;
    _finish(context, done, 'وصله إنك سلّمت.', dashboard.errorMessage);
  }

  void _finish(BuildContext context, bool done, String success, String? error) {
    if (done) {
      AarastToast.showSuccess(context, success);
      Navigator.of(context).maybePop();
    } else {
      AarastToast.showError(context, error ?? 'ما قدرنا نحفظ. جرّب مرة ثانية.');
    }
  }
}

/// B-22: «ما صار» and why, in the provider's words.
const _notHappenedWords = {
  'CUSTOMER_NO_SHOW': 'العرس ما صار في موعده',
  'WE_DID_NOT_ATTEND': 'ما قدرنا نحضر',
  'FORCE_MAJEURE': 'ظرف قاهر',
  'OFFICIAL_DECISION': 'قرار رسمي',
};

/// One line of text in a sheet; null when dismissed, empty when skipped.
Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String hint,
  bool optional = false,
}) {
  return showJourneySheet<String>(
    context: context,
    builder: (_) => _TextSheet(title: title, hint: hint, optional: optional),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.hint,
    required this.optional,
  });

  final String title;
  final String hint;
  final bool optional;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: widget.title,
      children: [
        JourneyTextField(
          key: const Key('provider-aftercare-text'),
          label: widget.hint,
          controller: _text,
          maxLength: 500,
          autofocus: true,
        ),
        const SizedBox(height: 12),
        JourneyButton(
          key: const Key('provider-aftercare-send'),
          label: 'أرسل',
          expand: true,
          large: true,
          onPressed: () {
            final value = _text.text.trim();
            if (value.isEmpty && !widget.optional) return;
            Navigator.of(context).pop(value);
          },
        ),
      ],
    );
  }
}
