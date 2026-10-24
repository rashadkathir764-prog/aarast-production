import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import 'provider_request_parts.dart';

/// p21 «محمد قبل عرضك»: the customer asks to book the day. Confirming
/// re-checks the day on the server (409 `BOOKING_DATE_UNAVAILABLE`), which
/// the note says at day level; the drawn team choice is not here (one
/// booking per day, D-2). «ما أقدر، اعتذر» turns the sheet into the
/// apology, with an optional reason the customer reads (D35).
Future<void> showProviderConfirmSheet(
  BuildContext context, {
  required QuoteRequest? quote,
  required MarketplaceBooking booking,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => _ConfirmSheet(quote: quote, booking: booking),
  );
}

/// p22's «إلغاء الحجز»: asks first, with an optional reason the customer
/// reads. True when the booking was cancelled.
Future<bool> showProviderCancelSheet(
  BuildContext context, {
  required QuoteRequest? quote,
  required MarketplaceBooking booking,
}) async {
  final cancelled = await showJourneySheet<bool>(
    context: context,
    builder: (_) => _CancelSheet(quote: quote, booking: booking),
  );
  return cancelled ?? false;
}

String _nameOf(QuoteRequest? quote, MarketplaceBooking booking) {
  final named = booking.customerName?.trim() ?? '';
  if (named.isNotEmpty) return named;
  return quote == null ? 'العميل' : providerCustomerName(quote);
}

/// «تأكيد الحجز يحتاج نت» (p43): confirming checks the day on the server,
/// so it never waits on the phone.
class ProviderConfirmNeedsNetwork extends StatelessWidget {
  const ProviderConfirmNeedsNetwork({super.key});

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const Key('provider-confirm-needs-network'),
      color: AarastV3Color.brandAccentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تأكيد الحجز يحتاج نت',
            style: JourneyType.of(
              JourneyType.body,
              weight: JourneyType.bold,
              color: AarastV3Color.brandAccentStrong,
            ),
          ),
          Text(
            'لازم نتأكد إن اليوم ما انحجز من غيرك في نفس اللحظة.',
            style: JourneyType.of(JourneyType.detail, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.quote, required this.booking});

  final QuoteRequest? quote;
  final MarketplaceBooking booking;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  final _reason = TextEditingController();
  bool _declining = false;
  bool _busy = false;
  bool _offline = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final first = providerFirstName(_nameOf(widget.quote, booking));
    final service = widget.quote?.service?.title.trim() ?? '';
    final day = formatArabicWeekdayDayMonth(booking.eventDate);
    final asks = service.isEmpty
        ? 'يشتي يحجز $day'
        : 'يشتي يحجز $service · $day';
    final error = _error;
    if (_declining) {
      return JourneySheetBody(
        title: 'تعتذر من $first؟',
        subtitle: 'يوصله إنك ما تقدر $day.',
        children: [
          JourneyTextField(
            key: const Key('provider-booking-reason'),
            label: 'السبب (اختياري)',
            hint: 'مثلًا: عندنا ارتباط ذاك اليوم',
            helper: 'يشوفه $first مع الاعتذار.',
            controller: _reason,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            _ErrorNote(text: error),
          ],
          const SizedBox(height: 16),
          JourneyButton(
            key: const Key('provider-booking-decline-send'),
            label: 'أرسل الاعتذار',
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            loading: _busy,
            onPressed: () => _decide('decline'),
          ),
          const SizedBox(height: 8),
          JourneyButton.quiet(
            label: 'رجوع',
            expand: true,
            onPressed: _busy
                ? null
                : () => setState(() {
                    _declining = false;
                    _error = null;
                  }),
          ),
        ],
      );
    }
    return JourneySheetBody(
      title: '$first قبل عرضك',
      subtitle: asks,
      children: [
        const JourneyNote(
          icon: LucideIcons.shieldCheck,
          text:
              'نتأكد إن اليوم فاضي لحظة ما تضغط. لو انحجز في نفس الثانية، نقولك.',
        ),
        if (_offline) ...[
          const SizedBox(height: 10),
          const ProviderConfirmNeedsNetwork(),
        ] else if (error != null) ...[
          const SizedBox(height: 10),
          _ErrorNote(text: error),
        ],
        const SizedBox(height: 12),
        JourneyButton(
          key: Key('provider-booking-confirm-${booking.id}'),
          label: 'أكّد الحجز',
          icon: LucideIcons.check,
          expand: true,
          large: true,
          loading: _busy,
          onPressed: () => _decide('confirm'),
        ),
        const SizedBox(height: 8),
        Center(
          child: JourneyTextAction(
            key: Key('provider-booking-decline-${booking.id}'),
            label: 'ما أقدر، اعتذر',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _declining = true;
                    _error = null;
                    _offline = false;
                  }),
          ),
        ),
      ],
    );
  }

  Future<void> _decide(String action) async {
    final dashboard = context.read<ProviderDashboardProvider>();
    setState(() {
      _busy = true;
      _error = null;
      _offline = false;
    });
    final ok = await dashboard.decideBooking(
      bookingId: widget.booking.id,
      action: action,
      note: action == 'decline' ? _reason.text.trim() : null,
    );
    if (!mounted) return;
    if (!ok) {
      final day = formatArabicWeekday(widget.booking.eventDate);
      setState(() {
        _busy = false;
        _offline = dashboard.lastChangeOffline && action == 'confirm';
        _error = switch (dashboard.errorCode) {
          'BOOKING_DATE_UNAVAILABLE' =>
            'يوم $day ما عاد فاضي عندك، فما تأكد الحجز.',
          _ => dashboard.errorMessage ?? 'ما قدرنا نحفظ قرارك. جرّب مرة ثانية.',
        };
      });
      return;
    }
    AarastToast.showSuccess(
      context,
      action == 'confirm' ? 'تأكد الحجز، ووصله خبر.' : 'وصله اعتذارك.',
    );
    Navigator.of(context).pop();
  }
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.quote, required this.booking});

  final QuoteRequest? quote;
  final MarketplaceBooking booking;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = providerFirstName(_nameOf(widget.quote, widget.booking));
    final day = formatArabicWeekdayDayMonth(widget.booking.eventDate);
    final error = _error;
    return JourneySheetBody(
      title: 'تلغي حجز $first؟',
      subtitle: 'يوصله إن حجز $day انلغى، ويرجع اليوم فاضي في تقويمك.',
      children: [
        JourneyTextField(
          key: const Key('provider-booking-reason'),
          label: 'السبب (اختياري)',
          hint: 'مثلًا: صار عندنا ظرف',
          helper: 'يشوفه $first مع الإلغاء.',
          controller: _reason,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          _ErrorNote(text: error),
        ],
        const SizedBox(height: 16),
        JourneyButton(
          key: const Key('provider-booking-cancel-send'),
          label: 'ألغِ الحجز',
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          loading: _busy,
          onPressed: _cancel,
        ),
        const SizedBox(height: 8),
        JourneyButton.quiet(
          label: 'رجوع',
          expand: true,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Future<void> _cancel() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await dashboard.decideBooking(
      bookingId: widget.booking.id,
      action: 'cancel',
      note: _reason.text.trim(),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = dashboard.errorMessage ?? 'ما قدرنا نلغي الحجز.';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return JourneyNote(
      key: const Key('provider-booking-error'),
      text: text,
      icon: LucideIcons.alertCircle,
      color: AarastV3Color.danger,
      soft: AarastV3Color.dangerSoft,
    );
  }
}
