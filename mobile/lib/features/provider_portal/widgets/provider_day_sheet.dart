import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../marketplace/marketplace_api.dart' show MarketplaceBooking;
import '../providers/provider_dashboard_provider.dart';
import 'provider_calendar_parts.dart';
import 'provider_request_parts.dart';

/// p29: one day of his calendar in a journey sheet. The server keeps whole
/// days (F9, F11), so the drawn periods, teams and «حجز من برا» are not
/// here: the booking or the requests waiting on the day, each opening its
/// case, and closing or opening the day.
Future<void> showProviderDaySheet(BuildContext context, DateTime day) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => _ProviderDaySheet(day: day),
  );
}

class _ProviderDaySheet extends StatelessWidget {
  const _ProviderDaySheet({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final showHijri = context.watch<DevicePreferences?>()?.showHijri ?? true;
    final info = providerDayOf(day, dashboard);
    final hijri = showHijri ? HijriDate.fromGregorian(day) : null;
    final stateLine = switch (info.state) {
      ProviderDayState.booked =>
        info.capacity > 1 ? 'اليوم مليان' : 'عندك حجز مؤكد',
      ProviderDayState.room => 'باقي ${info.left} من ${info.capacity}',
      ProviderDayState.waiting =>
        info.asked.length == 1 ? 'طلب ينتظر تأكيدك' : 'طلبات تنتظر تأكيدك',
      ProviderDayState.closed => 'قفلته في تقويمك',
      ProviderDayState.free => 'فاضي',
    };
    final bookings = [...info.confirmed, ...info.asked];
    // A confirmed booking holds the day: the server refuses to close it.
    final canClose = !info.closed && info.confirmed.isEmpty;
    return JourneySheetBody(
      title: formatArabicWeekdayDayMonth(day),
      subtitle: [?hijri?.dayAndMonth, stateLine].join(' · '),
      children: [
        if (bookings.isNotEmpty) ...[
          JourneyList(
            children: [
              for (final booking in bookings)
                _bookingRow(context, dashboard, booking),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        if (info.closed)
          JourneyButton(
            key: const Key('provider-day-open'),
            label: 'افتح اليوم',
            icon: LucideIcons.calendarPlus,
            background: AarastV3Color.paper,
            foreground: AarastV3Color.primary,
            expand: true,
            large: true,
            loading: dashboard.isSubmitting,
            onPressed: () => _change(context, dashboard, close: false),
          )
        else if (canClose)
          JourneyButton(
            key: const Key('provider-day-close'),
            label: 'أقفل اليوم',
            icon: LucideIcons.calendarX,
            background: AarastV3Color.paper,
            foreground: AarastV3Color.primary,
            expand: true,
            large: true,
            loading: dashboard.isSubmitting,
            onPressed: () => _change(context, dashboard, close: true),
          ),
      ],
    );
  }

  Widget _bookingRow(
    BuildContext context,
    ProviderDashboardProvider dashboard,
    MarketplaceBooking booking,
  ) {
    final quote = providerQuoteOfBooking(dashboard, booking);
    final name = booking.customerName?.trim().isNotEmpty == true
        ? booking.customerName!.trim()
        : quote == null
        ? 'العميل'
        : providerCustomerName(quote);
    final service = quote?.service?.title.trim() ?? '';
    final confirmed = booking.isConfirmed;
    return JourneyListRow(
      key: Key('provider-day-booking-${booking.id}'),
      icon: confirmed ? LucideIcons.calendarCheck : LucideIcons.calendarClock,
      color: confirmed ? AarastV3Color.mint : AarastV3Color.brandAccentStrong,
      soft: confirmed ? AarastV3Color.mintSoft : AarastV3Color.brandAccentSoft,
      title: 'عرس $name',
      subtitle: service.isEmpty
          ? (confirmed ? 'حجز مؤكد' : 'طلب حجز لهذا اليوم')
          : service,
      trailing: JourneyTag(
        label: confirmed ? 'محجوز' : 'ينتظر تأكيدك',
        color: confirmed ? AarastV3Color.mint : AarastV3Color.brandAccentStrong,
        soft: confirmed
            ? AarastV3Color.mintSoft
            : AarastV3Color.brandAccentSoft,
      ),
      onTap: () {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(AppRouter.providerRequest(booking.quoteRequestId));
      },
    );
  }

  Future<void> _change(
    BuildContext context,
    ProviderDashboardProvider dashboard, {
    required bool close,
  }) async {
    final ok = close
        ? await dashboard.blockDate(day)
        : await dashboard.unblockDate(day);
    if (!context.mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        dashboard.errorMessage ??
            (close ? 'ما قدرنا نقفل اليوم.' : 'ما قدرنا نفتح اليوم.'),
      );
      return;
    }
    Navigator.of(context).pop();
  }
}
