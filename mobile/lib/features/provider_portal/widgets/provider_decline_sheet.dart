import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../chat/chat_api.dart' show ChatProvider;
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import 'provider_request_parts.dart';

/// Why the provider says no (p18). The server keeps the reason (B-05) and
/// tells the customer «اعتذر … مشغول ذاك اليوم»; it also picks the polite
/// line the customer reads in the chat.
enum ProviderDeclineReason {
  busy('مشغول ذاك اليوم', 'BUSY_THAT_DAY'),
  area('خارج منطقتي', 'OUT_OF_AREA'),
  service('ما أقدم هذي الخدمة', 'NOT_MY_SERVICE'),
  other('سبب ثاني', 'OTHER');

  const ProviderDeclineReason(this.label, this.code);

  final String label;

  /// The server's reason code.
  final String code;
}

/// The line the customer reads in the chat for [reason].
String providerDeclineMessage(ProviderDeclineReason reason, DateTime? day) {
  const blessing = 'الله يتمم لك على خير.';
  return switch (reason) {
    ProviderDeclineReason.busy =>
      day == null
          ? 'نعتذر، ما نقدر ذاك اليوم. $blessing'
          : 'نعتذر، ما نقدر ليلة ${formatArabicDayMonth(day)}. $blessing',
    ProviderDeclineReason.area =>
      'نعتذر، مكان العرس خارج منطقة شغلنا. $blessing',
    ProviderDeclineReason.service => 'نعتذر، ما نقدم هذي الخدمة. $blessing',
    ProviderDeclineReason.other => 'نعتذر، ما نقدر نخدمك هذي المرة. $blessing',
  };
}

/// p18 «تعتذر من محمد؟». The polite line goes to the chat first, then the
/// request is declined (REJECTED, F7). «مشغول ذاك اليوم» also closes the
/// day in his calendar, at day level, unless a confirmed booking already
/// holds it. Returns true when the request was declined.
Future<bool> showProviderDeclineSheet(
  BuildContext context,
  QuoteRequest quote,
) async {
  final declined = await showJourneySheet<bool>(
    context: context,
    builder: (_) => _ProviderDeclineSheet(quote: quote),
  );
  return declined == true;
}

class _ProviderDeclineSheet extends StatefulWidget {
  const _ProviderDeclineSheet({required this.quote});

  final QuoteRequest quote;

  @override
  State<_ProviderDeclineSheet> createState() => _ProviderDeclineSheetState();
}

class _ProviderDeclineSheetState extends State<_ProviderDeclineSheet> {
  ProviderDeclineReason? _reason;
  bool _busy = false;
  String? _error;

  // A retry after a failed decline does not send the line twice.
  bool _messageSent = false;

  DateTime? get _day => widget.quote.eventDate;

  /// The day can be closed: it is known, not closed yet and not booked.
  bool _canClose(ProviderDashboardProvider dashboard) {
    final day = _day;
    if (day == null) return false;
    bool same(DateTime other) =>
        other.year == day.year &&
        other.month == day.month &&
        other.day == day.day;
    return !dashboard.blockedDates.any(same) &&
        !dashboard.bookings.any(
          (booking) => booking.isConfirmed && same(booking.eventDate),
        );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final first = providerFirstName(providerCustomerName(widget.quote));
    final reason = _reason;
    final canClose = _canClose(dashboard);
    return JourneySheetBody(
      title: 'تعتذر من $first؟',
      children: [
        for (final option in ProviderDeclineReason.values) ...[
          JourneyOption(
            key: Key('provider-decline-${option.name}'),
            title: option.label,
            subtitle: option == ProviderDeclineReason.busy && canClose
                ? 'ونقفل ليلة ${formatArabicWeekday(_day!)} في تقويمك'
                : null,
            selected: option == reason,
            onTap: _busy ? null : () => setState(() => _reason = option),
          ),
          const SizedBox(height: 8),
        ],
        if (reason != null) ...[
          const SizedBox(height: 4),
          JourneyBox(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اللي يوصل $first',
                  style: JourneyType.of(
                    JourneyType.label,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                Text(
                  '«${providerDeclineMessage(reason, _day)}»',
                  key: const Key('provider-decline-message'),
                  style: JourneyType.of(JourneyType.body, height: 1.5),
                ),
              ],
            ),
          ),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          JourneyNote(
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        const SizedBox(height: 12),
        JourneyButton(
          key: const Key('provider-quote-decline-confirm'),
          label: 'أرسل الاعتذار',
          expand: true,
          large: true,
          loading: _busy,
          onPressed: reason == null ? null : () => _send(reason, canClose),
        ),
      ],
    );
  }

  Future<void> _send(ProviderDeclineReason reason, bool canClose) async {
    final chat = context.read<ChatProvider>();
    final dashboard = context.read<ProviderDashboardProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!_messageSent) {
      final conversation = await chat.openQuote(widget.quote.id);
      final sent =
          conversation != null &&
          await chat.send(
            conversation.id,
            providerDeclineMessage(reason, _day),
          );
      if (!mounted) return;
      if (!sent) {
        setState(() {
          _busy = false;
          _error =
              chat.errorMessage ?? 'ما قدرنا نرسل الاعتذار. جرّب مرة ثانية.';
        });
        return;
      }
      _messageSent = true;
    }
    final closeDay = reason == ProviderDeclineReason.busy && canClose;
    final declined = await dashboard.updateQuoteStatus(
      quoteRequestId: widget.quote.id,
      status: 'REJECTED',
      declineReason: reason.code,
      declineMessage: providerDeclineMessage(reason, _day),
      blockDay: closeDay,
    );
    if (!mounted) return;
    if (!declined) {
      setState(() {
        _busy = false;
        _error =
            dashboard.errorMessage ?? 'ما قدرنا نقفل الطلب. جرّب مرة ثانية.';
      });
      return;
    }
    // B-05: the server closed the day in the same step as the decline.
    final closed = !closeDay || dashboard.lastDeclineClosedDay;
    if (closed) {
      AarastToast.showSuccess(context, 'وصل اعتذارك.');
    } else {
      AarastToast.showError(
        context,
        'وصل اعتذارك، بس ما قدرنا نقفل اليوم. قفله من التقويم.',
      );
    }
    Navigator.of(context).pop(true);
  }
}
