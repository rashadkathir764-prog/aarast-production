import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../../notifications/notifications_api.dart'
    show
        AarastNotification,
        NoticeLookup,
        NoticeLookupOutcome,
        NotificationsProvider,
        isSafeNotificationRouteTarget,
        noticeGoneLine,
        noticeUnreachableLine,
        resolveNotificationRouteTarget;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_request_parts.dart';

/// The notices about his account: approved, to fix, refused, stopped, back
/// in review, a claim decided (B-19). They name no audience, because the
/// server shows a provider-audience notice only to an operational provider.
const _accountNoticeTypes = {
  'PROVIDER_APPROVED',
  'PROVIDER_NEEDS_CHANGES',
  'PROVIDER_REJECTED',
  'PROVIDER_SUSPENDED',
  'PROVIDER_IN_REVIEW',
  'PROVIDER_CLAIM_DECIDED',
};

/// A notice of his: addressed to the provider, or about his account.
bool isProviderNotice(AarastNotification notice) =>
    notice.data?['recipientAudience']?.toString() == 'PROVIDER' ||
    _accountNoticeTypes.contains(notice.type.toUpperCase());

/// p42 «التنبيهات»: his notices, each opening its own screen (B-19): a
/// request or its booking opens the request (p16, p19), a message its chat,
/// a review p27, his featured placement «ملفي» (p35), his account the
/// portal. The line of a request notice is written on the phone from the
/// request it names (p42 «طلب جديد من سلمى · حفلة نساء · 21 يناير»); any
/// other keeps the server's words. Deposit, postpone and hold notices do
/// not exist on the server (B-18, B-22, B-25), so none is shown.
class ProviderNotificationsScreen extends StatefulWidget {
  const ProviderNotificationsScreen({this.openNotificationId, super.key});

  /// The notice a push tap named: opened once the list is read.
  final String? openNotificationId;

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

  /// The store this inbox is on the screen of, so a notice that arrives
  /// meanwhile reads the list again.
  NotificationsProvider? _shownOn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<NotificationsProvider>();
    if (identical(store, _shownOn)) return;
    _shownOn?.inboxClosed();
    _shownOn = store..inboxOpened();
  }

  @override
  void dispose() {
    _shownOn?.inboxClosed();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final dashboard = context.read<ProviderDashboardProvider>();
    final notices = context.read<NotificationsProvider>();
    // The pushed notice is asked for by its id, beside the list.
    final requested = _lookUpRequestedNotice(notices);
    await Future.wait([
      notices.loadNotifications(),
      // A notice opened from outside the portal still names its request.
      if (dashboard.quoteRequests.isEmpty && !dashboard.isLoading)
        dashboard.loadDashboard(),
    ]);
    if (requested != null) await _openRequestedNotice(notices, requested);
  }

  bool _requestedNoticeOpened = false;

  Future<NoticeLookup>? _lookUpRequestedNotice(NotificationsProvider notices) {
    final id = widget.openNotificationId;
    if (id == null || _requestedNoticeOpened) return null;
    _requestedNoticeOpened = true;
    notices.markOpened(id);
    return notices.lookUpNotice(id);
  }

  /// A push tap names its notice: looked up by its id, it opens as a tap on
  /// its row does, through the same guards, and is marked read. A notice
  /// that is not his (the account's plan's) opens in the account's inbox,
  /// which opens it in its plan; one gone says so in one line.
  Future<void> _openRequestedNotice(
    NotificationsProvider notices,
    Future<NoticeLookup> requested,
  ) async {
    var lookup = await requested;
    if (lookup.outcome == NoticeLookupOutcome.unreachable) {
      // Asked beside the list: the list read since may hold its copy.
      final copy = await notices.listedNotice(widget.openNotificationId!);
      if (copy != null) {
        lookup = (outcome: NoticeLookupOutcome.found, notice: copy);
      }
    }
    if (!mounted) return;
    switch (lookup.outcome) {
      case NoticeLookupOutcome.found:
        final notice = lookup.notice!;
        if (isProviderNotice(notice)) {
          await _open(notices, notice);
          return;
        }
        context.go(
          Uri(
            path: AppRouter.notifications,
            queryParameters: {AppRouter.openNotificationParameter: notice.id},
          ).toString(),
        );
      case NoticeLookupOutcome.gone:
        AarastToast.showInfo(context, noticeGoneLine);
      case NoticeLookupOutcome.unreachable:
        AarastToast.showInfo(context, noticeUnreachableLine(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<NotificationsProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final mine = [
      for (final notice in notices.notifications)
        if (isProviderNotice(notice)) notice,
    ];
    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
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
              const SizedBox(height: AarastV3Space.x2),
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
      iconSize: AarastV3Size.mark,
      title: look.title,
      subtitle: look.subtitle,
      trailing: notice.isUnread
          ? Container(
              key: Key('provider-notice-unread-${notice.id}'),
              width: AarastV3Size.dot,
              height: AarastV3Size.dot,
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
  ProviderNoticeLook server(IconData icon, Color color, Color soft) => (
    icon: icon,
    color: color,
    soft: soft,
    title: notice.title,
    subtitle: notice.body,
  );

  switch (type) {
    case 'CHAT_MESSAGE_RECEIVED':
      return (
        icon: LucideIcons.messageCircle,
        color: AarastV3Color.primary,
        soft: AarastV3Color.primarySoft,
        title: 'رسالة جديدة',
        subtitle: 'فتح المحادثة',
      );
    // p42 «تقييم جديد · 4 نجوم من محمد»: the server's words, as drawn.
    case 'REVIEW_RECEIVED':
      return server(
        LucideIcons.star,
        AarastV3Color.brandAccentStrong,
        AarastV3Color.brandAccentSoft,
      );
    // B-16: a portfolio photo approved or refused with its reason (p37).
    case 'PORTFOLIO_REVIEWED':
      return server(
        LucideIcons.image,
        AarastV3Color.primary,
        AarastV3Color.primarySoft,
      );
    case 'LISTING_PLAN_CHANGED':
      return server(
        LucideIcons.crown,
        AarastV3Color.brandAccentStrong,
        AarastV3Color.brandAccentSoft,
      );
    case 'PROVIDER_APPROVED':
      return server(
        LucideIcons.badgeCheck,
        AarastV3Color.mint,
        AarastV3Color.mintSoft,
      );
    case 'PROVIDER_NEEDS_CHANGES':
    case 'PROVIDER_REJECTED':
    case 'PROVIDER_SUSPENDED':
      return server(
        LucideIcons.alertTriangle,
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
      );
    case 'PROVIDER_IN_REVIEW':
    case 'PROVIDER_CLAIM_DECIDED':
      return server(
        LucideIcons.store,
        AarastV3Color.primary,
        AarastV3Color.primarySoft,
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
        // Critique ب4: the customer may be the bride, «them».
        title: '$first قبلوا عرضك',
        subtitle: switch (state) {
          ProviderCaseState.bookingAsked => 'أكّد الحجز',
          ProviderCaseState.waitingBooking => 'ما طلبوا الحجز لسا',
          ProviderCaseState.booked => 'الحجز مؤكد',
          _ => requestLine,
        },
      );
    case 'QUOTE_REJECTED':
      return (
        icon: LucideIcons.xCircle,
        color: AarastV3Color.textMuted,
        soft: AarastV3Color.line,
        title: '$first ما اختاروا عرضك',
        subtitle: requestLine,
      );
    // B-19: a booking request is its own type.
    case 'BOOKING_REQUESTED':
      return (
        icon: LucideIcons.calendarCheck,
        color: AarastV3Color.brandAccentStrong,
        soft: AarastV3Color.brandAccentSoft,
        // RA-MO-303: the customer may be a bride.
        title: 'طلب حجز من $first',
        subtitle: asked ? 'أكّد الحجز' : requestLine,
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
      if (notice.data?['bookingEvent']?.toString() == 'CANCELLED') {
        return (
          icon: LucideIcons.calendarX,
          color: AarastV3Color.cobalt,
          soft: AarastV3Color.cobaltSoft,
          title: '$first لغوا الحجز',
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
