import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../../notifications/notifications_api.dart'
    show
        AarastNotification,
        NotificationsProvider,
        isSafeNotificationRouteTarget,
        localizeNotification,
        resolveNotificationRouteTarget;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_request_parts.dart';

/// p42 «التنبيهات»: his notices (the ones the server addresses to the
/// provider), each opening its case: a request or its booking opens the
/// request screen, a message its chat (F12). The line is written on the
/// phone from the request the notice names; one whose request is not in his
/// list keeps the server's own words. Deposit, postpone, hold and review
/// notices do not exist on the server (B-18, B-22, B-19, F12), so none is
/// shown.
class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({super.key});

  @override
  State<ProviderNotificationsScreen> createState() =>
      _ProviderNotificationsScreenState();
}

class _ProviderNotificationsScreenState
    extends State<ProviderNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final dashboard = context.read<ProviderDashboardProvider>();
    final notices = context.read<NotificationsProvider>();
    await Future.wait([
      notices.loadNotifications(),
      // A notice opened from outside the portal still names its request.
      if (dashboard.quoteRequests.isEmpty && !dashboard.isLoading)
        dashboard.loadDashboard(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<NotificationsProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final mine = [
      for (final notice in notices.notifications)
        if (notice.data?['recipientAudience']?.toString() == 'PROVIDER') notice,
    ];
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const JourneySubHeader(
              title: 'التنبيهات',
              subtitle: 'كل واحد يفتح طلبه',
            ),
            if (mine.isEmpty)
              JourneyListState(
                phase: notices.isLoading
                    ? JourneyListPhase.loading
                    : notices.errorMessage != null
                    ? JourneyListPhase.error
                    : JourneyListPhase.empty,
                section: JourneySection.home,
                emptyIcon: LucideIcons.bell,
                emptyTitle: 'ما وصلك تنبيه لسا',
                emptyMessage: 'الطلبات والحجوزات الجديدة توصلك هنا.',
                onRetry: _load,
              )
            else
              JourneyList(
                children: [
                  for (final notice in mine)
                    _row(context, notices, dashboard, notice),
                ],
              ),
            if (notices.hasMore) ...[
              const SizedBox(height: 8),
              Center(
                child: JourneyTextAction(
                  key: const Key('provider-notifications-more'),
                  label: 'اللي قبلها',
                  color: AarastV3Color.primary,
                  onPressed: notices.isLoadingMore ? null : notices.loadMore,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    NotificationsProvider notices,
    ProviderDashboardProvider dashboard,
    AarastNotification notice,
  ) {
    final quoteId = notice.data?['quoteRequestId']?.toString();
    QuoteRequest? quote;
    for (final item in dashboard.quoteRequests) {
      if (item.id == quoteId) quote = item;
    }
    final look = providerNoticeLook(notice, quote, dashboard);
    return JourneyListRow(
      key: Key('provider-notice-${notice.id}'),
      icon: look.icon,
      color: look.color,
      soft: look.soft,
      iconSize: 40,
      title: look.title,
      subtitle: look.subtitle,
      trailing: notice.isUnread
          ? Container(
              key: Key('provider-notice-unread-${notice.id}'),
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AarastV3Color.danger,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () => _open(notices, notice),
    );
  }

  Future<void> _open(
    NotificationsProvider notices,
    AarastNotification notice,
  ) async {
    final target = resolveNotificationRouteTarget(notice);
    if (target == null || !isSafeNotificationRouteTarget(target)) return;
    if (notice.isUnread) await notices.markRead(notice);
    if (!mounted) return;
    await context.push(target);
  }
}

/// How one notice reads (prototype p42): an icon on its colour, a title
/// and a line.
typedef ProviderNoticeLook = ({
  IconData icon,
  Color color,
  Color soft,
  String title,
  String subtitle,
});

ProviderNoticeLook providerNoticeLook(
  AarastNotification notice,
  QuoteRequest? quote,
  ProviderDashboardProvider dashboard,
) {
  final type = notice.type.toUpperCase();
  ProviderNoticeLook server(IconData icon, Color color, Color soft) {
    final copy = localizeNotification(
      type: notice.type,
      title: notice.title,
      body: notice.body,
    );
    return (
      icon: icon,
      color: color,
      soft: soft,
      title: copy.title,
      subtitle: copy.body,
    );
  }

  if (type == 'CHAT_MESSAGE_RECEIVED') {
    return (
      icon: LucideIcons.messageCircle,
      color: AarastV3Color.primary,
      soft: AarastV3Color.primarySoft,
      title: 'رسالة جديدة',
      subtitle: 'افتح المحادثة',
    );
  }
  // Without the request the phone cannot name it: the server's words.
  if (quote == null) {
    return server(
      LucideIcons.bell,
      AarastV3Color.textMuted,
      AarastV3Color.line,
    );
  }
  final first = providerFirstName(providerCustomerName(quote));
  final booking = providerBookingOf(quote, dashboard);
  final state = providerCaseOf(quote, booking);
  final day = booking?.eventDate ?? quote.eventDate;
  final dayLine = day == null ? '' : formatArabicDayMonth(day);
  final requestLine = [
    if (quote.service?.title.trim().isNotEmpty == true)
      quote.service!.title.trim(),
    if (dayLine.isNotEmpty) dayLine,
  ].join(' · ');
  final asked = state == ProviderCaseState.bookingAsked;

  switch (type) {
    case 'QUOTE_REQUEST_SUBMITTED':
      return (
        icon: LucideIcons.inbox,
        color: AarastV3Color.danger,
        soft: AarastV3Color.dangerSoft,
        title: 'طلب جديد من $first',
        subtitle: requestLine,
      );
    case 'QUOTE_ACCEPTED':
      return (
        icon: LucideIcons.calendarCheck,
        color: AarastV3Color.brandAccentStrong,
        soft: AarastV3Color.brandAccentSoft,
        title: '$first قبل عرضك',
        subtitle: switch (state) {
          ProviderCaseState.bookingAsked => 'أكّد الحجز',
          ProviderCaseState.waitingBooking => 'ينتظر يطلب الحجز',
          ProviderCaseState.booked => 'الحجز مؤكد',
          _ => requestLine,
        },
      );
    case 'QUOTE_REJECTED':
      return (
        icon: LucideIcons.xCircle,
        color: AarastV3Color.textMuted,
        soft: AarastV3Color.line,
        title: '$first ما اختار عرضك',
        subtitle: requestLine,
      );
    case 'BOOKING_UPDATED':
      final daysUntil = int.tryParse(
        notice.data?['daysUntil']?.toString() ?? '',
      );
      if (daysUntil != null) {
        return (
          icon: LucideIcons.bell,
          color: AarastV3Color.primary,
          soft: AarastV3Color.primarySoft,
          title: switch (daysUntil) {
            1 => 'عرس $first بكرة',
            7 => 'عرس $first بعد أسبوع',
            2 => 'عرس $first بعد يومين',
            _ => 'عرس $first بعد $daysUntil أيام',
          },
          subtitle: requestLine,
        );
      }
      // The server words a booking notice by its event; its title is the
      // only field that tells a request from a cancellation (F12).
      if (notice.title.trim() == 'طلب حجز جديد') {
        return (
          icon: LucideIcons.calendarCheck,
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
          title: '$first يشتي يحجز',
          subtitle: asked ? 'أكّد الحجز' : requestLine,
        );
      }
      if (notice.title.trim() == 'أُلغي حجز') {
        return (
          icon: LucideIcons.calendarX,
          color: AarastV3Color.cobalt,
          soft: AarastV3Color.cobaltSoft,
          title: '$first لغى الحجز',
          subtitle: dayLine.isEmpty ? 'الحجز انلغى' : '$dayLine · الحجز انلغى',
        );
      }
      return server(
        LucideIcons.calendarDays,
        AarastV3Color.primary,
        AarastV3Color.primarySoft,
      );
  }
  return server(LucideIcons.bell, AarastV3Color.textMuted, AarastV3Color.line);
}
