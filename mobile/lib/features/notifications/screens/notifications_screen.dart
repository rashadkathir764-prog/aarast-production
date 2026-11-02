import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../models/aarast_notification.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_route_policy.dart';
import '../utils/notification_line.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _notificationsEmptyTop = 60.0;

/// A fixed dimension of this layout, not a spacing step (D74).
const _notificationsSkeletonRow = 90.0;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({this.weddingPlanId, this.clock, super.key});

  final String? weddingPlanId;

  /// The time the «when» labels and groups are read against; the device
  /// clock unless a caller (a golden) pins it.
  final DateTime Function()? clock;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isCheckingAccount = true;
  bool _showLoginGate = false;
  bool _suppressAccountData = false;

  bool get _isLocalPlanNotifications =>
      widget.weddingPlanId != null &&
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  /// q21: a participant reads one plan's notices, plainly, under its name.
  String? _participantPlanTitle(BuildContext context) {
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final planId = widget.weddingPlanId;
    if (planId == null ||
        selected?.role != AccountContextRole.contributor ||
        selected?.weddingPlanId != planId) {
      return null;
    }
    return selected!.displayName;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final suppressData = _isLocalPlanNotifications || _suppressAccountData;
    final notifications = suppressData
        ? const <AarastNotification>[]
        : provider.notifications;
    final unreadInList = notifications.where((item) => item.isUnread).length;
    final participantPlan = _participantPlanTitle(context);

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x4,
              0,
            ),
            child: JourneySubHeader(
              title: 'التنبيهات',
              // The count of unread matters more than a fixed description.
              subtitle: participantPlan != null
                  ? 'من $participantPlan'
                  : unreadInList > 0
                  ? '$unreadInList غير مقروء'
                  : widget.weddingPlanId == null
                  ? 'كل تنبيهات الحساب المحفوظة'
                  : 'تنبيهات الخطة المحفوظة',
              trailing: participantPlan == null && unreadInList > 0
                  ? JourneyTextAction(
                      label: 'قراءة الكل',
                      color: context.accent.primary,
                      onPressed: provider.isSubmitting
                          ? null
                          : () => _markAllRead(provider),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.accent.primary,
              onRefresh: _load,
              child: _body(
                provider,
                notifications: notifications,
                participant: participantPlan != null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    NotificationsProvider provider, {
    required List<AarastNotification> notifications,
    bool participant = false,
  }) {
    final suppressData = _isLocalPlanNotifications || _suppressAccountData;

    if (!_isLocalPlanNotifications && _isCheckingAccount) {
      return AarastSkeleton.list(
        rows: 6,
        rowHeight: 84,
        withHeader: false,
        padding: const EdgeInsets.fromLTRB(
          0,
          AarastV3Space.x2,
          0,
          AarastV3Space.x6,
        ),
      );
    }

    if (!_isLocalPlanNotifications && _showLoginGate) {
      return const AuthGatePanel(
        title: 'سجّل الدخول لعرض التنبيهات',
        body:
            'التنبيهات مرتبطة بحسابك وخططك المحفوظة، لذلك نعرضها بعد تسجيل الدخول.',
        icon: LucideIcons.bell,
      );
    }

    if (!suppressData && provider.isLoading && notifications.isEmpty) {
      return AarastSkeleton.list(
        rows: 6,
        rowHeight: 84,
        withHeader: false,
        padding: const EdgeInsets.fromLTRB(
          0,
          AarastV3Space.x2,
          0,
          AarastV3Space.x6,
        ),
      );
    }

    if (!suppressData &&
        provider.errorMessage != null &&
        notifications.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: _notificationsEmptyTop),
          AarastErrorState(
            title: 'تعذر تحميل التنبيهات',
            message: provider.errorMessage!,
            onRetry: _load,
          ),
        ],
      );
    }

    if (notifications.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: _notificationsSkeletonRow),
          AarastEmptyState(
            icon: LucideIcons.bellOff,
            title: AarastV3Copy.quietNotificationsTitle,
            message: AarastV3Copy.quietNotificationsMessage,
            tone: AarastEmptyStateTone.positive,
          ),
        ],
      );
    }

    final now = (widget.clock ?? appNow)();
    if (participant) {
      return ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneyList(
            children: [
              for (final notification in notifications)
                _NotificationRow(
                  notification: notification,
                  now: now,
                  plain: true,
                  onTap: () => _openNotification(provider, notification),
                  onArchive: () => _archive(provider, notification),
                ),
            ],
          ),
          if (provider.hasMore) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyButton.quiet(
              label: 'عرض المزيد',
              icon: LucideIcons.chevronsDown,
              loading: provider.isLoadingMore,
              expand: true,
              onPressed: () =>
                  provider.loadMore(weddingPlanId: widget.weddingPlanId),
            ),
          ],
          const SizedBox(height: AarastV3Space.x3),
          // True: a notice goes to its own reader only, and the push copy is
          // chosen by type and marked private (push-delivery.service.ts).
          const JourneyNote(
            key: ValueKey('participant-notifications-note'),
            text:
                'توصلك بس الأشياء اللي تخصك، وعلى شاشة القفل تطلع بدون أسماء ولا مبالغ.',
            icon: LucideIcons.bellRing,
          ),
        ],
      );
    }

    final groups = groupNotificationsByTime(notifications, now);

    return ListView(
      padding: AarastV3Density.pageInsets,
      children: [
        for (final group in groups) ...[
          JourneySectionTitle(group.$1),
          JourneyBox(
            padding: EdgeInsets.zero,
            child: JourneyList(
              children: [
                for (final notification in group.$2)
                  _NotificationRow(
                    notification: notification,
                    now: now,
                    onTap: () => _openNotification(provider, notification),
                    onArchive: () => _archive(provider, notification),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        if (provider.hasMore) ...[
          const SizedBox(height: AarastV3Space.x1),
          JourneyButton.quiet(
            label: 'عرض المزيد',
            icon: LucideIcons.chevronsDown,
            loading: provider.isLoadingMore,
            expand: true,
            onPressed: () =>
                provider.loadMore(weddingPlanId: widget.weddingPlanId),
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        // True: the push copy is chosen by type only and marked private
        // (push-delivery.service.ts), so names and amounts never show there.
        const JourneyNote(
          text: 'على شاشة القفل تطلع بدون أسماء ولا مبالغ.',
          icon: LucideIcons.lock,
        ),
      ],
    );
  }

  Future<void> _load() {
    if (_isLocalPlanNotifications) {
      if (mounted && !_suppressAccountData) {
        setState(() {
          _isCheckingAccount = false;
          _showLoginGate = false;
          _suppressAccountData = true;
        });
      }
      return Future<void>.value();
    }
    return _loadAccountNotifications();
  }

  Future<void> _loadAccountNotifications() async {
    setState(() {
      _isCheckingAccount = true;
      _showLoginGate = false;
    });

    final shouldGate = await AuthActionGuard.shouldGateAccountOnly(context);
    if (!mounted) return;

    setState(() {
      _isCheckingAccount = false;
      _showLoginGate = shouldGate;
    });

    if (shouldGate) return;

    if (AppFeatureFlags.devBypassLoginGatesForUxExploration &&
        !await AuthActionGuard.hasAccount(context)) {
      if (mounted && !_suppressAccountData) {
        setState(() => _suppressAccountData = true);
      }
      return;
    }
    if (!mounted) return;
    if (_suppressAccountData) {
      setState(() => _suppressAccountData = false);
    }
    return context.read<NotificationsProvider>().loadNotifications(
      weddingPlanId: widget.weddingPlanId,
    );
  }

  Future<void> _markAllRead(NotificationsProvider provider) async {
    final marked = await provider.markAllRead(
      weddingPlanId: widget.weddingPlanId,
    );
    if (!mounted) return;
    if (marked) {
      AarastToast.showSuccess(context, 'تمت قراءة كل التنبيهات.');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر قراءة كل التنبيهات.',
      );
    }
  }

  Future<void> _openNotification(
    NotificationsProvider provider,
    AarastNotification notification,
  ) async {
    final target = resolveNotificationRouteTarget(notification);
    if (target == null || !isSafeNotificationRouteTarget(target)) return;
    // Being marked read is secondary: a failure (offline) still opens what
    // the notification points to, and it stays unread to be marked later.
    if (!_isNotificationTargetCompatible(target)) {
      await _openInItsPlan(provider, notification, target);
      return;
    }
    await provider.markRead(notification);
    if (!mounted) return;
    if (isPlanShellNotificationRouteTarget(target)) {
      context.go(target);
      return;
    }
    await context.push(target);
  }

  /// A notice for another of the account's plans (the groom's second plan,
  /// or one he helps in): that plan opens first, then the notice's page, as
  /// choosing the plan by hand does. A plan no longer reachable says so.
  Future<void> _openInItsPlan(
    NotificationsProvider provider,
    AarastNotification notification,
    String target,
  ) async {
    final planId = _targetPlanId(target);
    final controller = context.read<AccountContextController?>();
    final path = planId == null || _isLocalPlanNotifications
        ? null
        : controller?.availableContexts
              .where((path) => path.isPlan && path.weddingPlanId == planId)
              .firstOrNull;
    if (controller == null || path == null) {
      AarastToast.showError(
        context,
        'هذا التنبيه لخطة ما عاد توصل لها من هذا الحساب.',
      );
      return;
    }
    // Read before the switch: switching plans starts the session afresh.
    await provider.markRead(notification);
    if (!mounted) return;
    final router = GoRouter.of(context);
    final switched = await controller.select(path.contextKey);
    if (!switched || controller.selectedContext?.weddingPlanId != planId) {
      if (mounted) {
        AarastToast.showError(
          context,
          controller.errorMessage ?? 'ما قدرنا نفتح الخطة. جرّب مرة ثانية.',
        );
      }
      return;
    }
    router.go(target);
  }

  String? _targetPlanId(String target) {
    final segments = Uri.tryParse(target)?.pathSegments;
    return segments != null &&
            segments.length >= 2 &&
            segments.first == 'wedding-plans'
        ? segments[1]
        : null;
  }

  Future<void> _archive(
    NotificationsProvider provider,
    AarastNotification notification,
  ) async {
    final archived = await provider.archiveNotification(notification);
    if (archived || !mounted) return;
    AarastToast.showError(
      context,
      provider.errorMessage ?? 'ما قدرنا نشيل التنبيه',
    );
  }

  bool _isNotificationTargetCompatible(String target) {
    final targetPlanId = _targetPlanId(target);
    if (targetPlanId == null) return true;
    if (_isLocalPlanNotifications) {
      return targetPlanId == widget.weddingPlanId;
    }
    final selected = context.read<AccountContextController?>()?.selectedContext;
    return selected?.isPlan == true && selected?.weddingPlanId == targetPlanId;
  }
}

/// «اليوم», «هذا الأسبوع» and «أقدم»: a notification keeps its place when
/// it is read.
@visibleForTesting
List<(String, List<AarastNotification>)> groupNotificationsByTime(
  List<AarastNotification> notifications,
  DateTime now,
) {
  final today = DateUtils.dateOnly(now);
  final weekStart = today.subtract(const Duration(days: 6));
  final todays = <AarastNotification>[];
  final week = <AarastNotification>[];
  final older = <AarastNotification>[];
  for (final notification in notifications) {
    final day = DateUtils.dateOnly(notification.createdAt.toLocal());
    if (!day.isBefore(today)) {
      todays.add(notification);
    } else if (!day.isBefore(weekStart)) {
      week.add(notification);
    } else {
      older.add(notification);
    }
  }
  return [
    if (todays.isNotEmpty) ('اليوم', todays),
    if (week.isNotEmpty) ('هذا الأسبوع', week),
    if (older.isNotEmpty) ('أقدم', older),
  ];
}

/// «قبل ساعة», «قبل 3 ساعات», then the weekday, then the date.
@visibleForTesting
String notificationWhenLabel(DateTime at, DateTime now) {
  final local = at.toLocal();
  final minutes = now.difference(local).inMinutes;
  if (minutes < 1) return 'الآن';
  if (minutes < 60) {
    return 'قبل ${arabicCount(minutes, one: 'دقيقة', two: 'دقيقتين', few: 'دقائق', many: 'دقيقة')}';
  }
  if (DateUtils.isSameDay(local, now)) {
    final hours = now.difference(local).inHours;
    return 'قبل ${arabicCount(hours, one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة')}';
  }
  if (now.difference(local).inDays < 7) return formatArabicWeekday(local);
  return formatArabicCompactDate(local);
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.onArchive,
    required this.now,
    this.plain = false,
  });

  final AarastNotification notification;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  /// q21: the title, the line and a teal dot when new; no time and no
  /// archive button (archiving stays a screen-reader action).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(notification.type, context.accent);
    final hideAmounts = context.select<FinanceProvider?, bool>(
      (finance) => finance?.amountsHidden ?? false,
    );
    final copy = (
      title: notification.title,
      body: notificationLine(notification, hideAmounts: hideAmounts),
    );
    final urgent = notification.priority.toUpperCase() == 'URGENT';
    final when = notificationWhenLabel(notification.createdAt, now);
    return Semantics(
      button: true,
      label: [
        if (notification.isUnread) 'جديد',
        if (urgent) 'عاجل',
        copy.title,
        copy.body,
        when,
      ].join('، '),
      onTap: onTap,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'أرشفة التنبيه'): onArchive,
      },
      child: AarastPressable(
        key: ValueKey('notification-${notification.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AarastV3Space.x4,
            AarastV3Space.x3,
            AarastV3Space.x2,
            AarastV3Space.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JourneyIconTile(
                icon: tone.icon,
                color: tone.color,
                soft: tone.soft,
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        style: JourneyType.of(
                          JourneyType.bodyLarge,
                          weight: JourneyType.bold,
                          color: urgent
                              ? AarastV3Color.danger
                              : AarastV3Color.ink,
                        ),
                      ),
                      if (copy.body.trim().isNotEmpty)
                        Text(
                          copy.body,
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      if (!plain)
                        Text(
                          when,
                          style: JourneyType.of(
                            JourneyType.caption,
                            color: AarastV3Color.textFaint,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (plain)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: AarastV3Space.x1,
                    end: AarastV3Space.x2,
                  ),
                  child: SizedBox.square(
                    dimension: AarastV3Space.x2,
                    child: notification.isUnread
                        ? DecoratedBox(
                            key: const ValueKey('notification-unread-dot'),
                            decoration: BoxDecoration(
                              color: context.accent.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                )
              else
                Column(
                  children: [
                    if (notification.isUnread)
                      const Padding(
                        padding: EdgeInsets.only(
                          top: AarastV3Space.x1,
                          bottom: AarastV3Space.half,
                        ),
                        child: SizedBox.square(
                          dimension: AarastV3Space.x2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AarastV3Color.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: onArchive,
                      icon: const Icon(LucideIcons.archive, size: 16),
                      tooltip: 'أرشفة التنبيه',
                      color: AarastV3Color.textFaint,
                      visualDensity: VisualDensity.compact,
                      // Quiet: the unread dot is the row's only signal.
                      style: IconButton.styleFrom(
                        backgroundColor: AarastV3Color.paper,
                        side: BorderSide.none,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTone {
  const _NotificationTone({
    required this.icon,
    required this.color,
    required this.soft,
  });

  final IconData icon;
  final Color color;
  final Color soft;
}

/// Each notification takes its section's colour: providers cobalt, tasks
/// and payments saffron, guests lilac, danger for what is late or over.
_NotificationTone _tone(String type, JourneyAccent accent) {
  final t = type.toUpperCase();
  if (t.contains('OVERDUE') || t.contains('EXCEEDED')) {
    return const _NotificationTone(
      icon: LucideIcons.alertTriangle,
      color: AarastV3Color.danger,
      soft: AarastV3Color.dangerSoft,
    );
  }
  if (t.contains('QUOTE')) {
    return _NotificationTone(
      icon: LucideIcons.mailOpen,
      color: accent.primary,
      soft: accent.primarySoft,
    );
  }
  if (t == 'BOOKING_UPDATED') {
    return const _NotificationTone(
      icon: LucideIcons.calendarCheck,
      color: AarastV3Color.mint,
      soft: AarastV3Color.mintSoft,
    );
  }
  if (t.contains('PAYMENT_SCHEDULE') || t.contains('LOAN_REPAYMENT')) {
    return const _NotificationTone(
      icon: LucideIcons.calendarClock,
      color: AarastV3Color.brandAccentStrong,
      soft: AarastV3Color.brandAccentSoft,
    );
  }
  if (t == 'GUEST_RESPONDED') {
    return _NotificationTone(
      icon: LucideIcons.userCheck,
      color: accent.primary,
      soft: accent.primarySoft,
    );
  }
  if (t.contains('TASK')) {
    return const _NotificationTone(
      icon: LucideIcons.listChecks,
      color: AarastV3Color.brandAccentStrong,
      soft: AarastV3Color.brandAccentSoft,
    );
  }
  if (t.contains('SHARING')) {
    return _NotificationTone(
      icon: LucideIcons.userPlus,
      color: accent.primary,
      soft: accent.primarySoft,
    );
  }
  return _NotificationTone(
    icon: LucideIcons.heart,
    color: accent.primary,
    soft: accent.primarySoft,
  );
}
