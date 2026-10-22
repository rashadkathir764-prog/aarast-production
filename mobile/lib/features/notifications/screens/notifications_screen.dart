import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../models/aarast_notification.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_route_policy.dart';
import '../utils/notification_copy.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({this.weddingPlanId, super.key});

  final String? weddingPlanId;

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

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: JourneySubHeader(
              title: 'التنبيهات',
              // The count of unread matters more than a fixed description.
              subtitle: unreadInList > 0
                  ? '$unreadInList غير مقروء'
                  : widget.weddingPlanId == null
                  ? 'كل تنبيهات الحساب المحفوظة'
                  : 'تنبيهات الخطة المحفوظة',
              trailing: unreadInList > 0
                  ? JourneyTextAction(
                      label: 'قراءة الكل',
                      color: AarastV3Color.primary,
                      onPressed: provider.isSubmitting
                          ? null
                          : () => _markAllRead(provider),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.primary,
              onRefresh: _load,
              child: _body(provider, notifications: notifications),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    NotificationsProvider provider, {
    required List<AarastNotification> notifications,
  }) {
    final suppressData = _isLocalPlanNotifications || _suppressAccountData;

    if (!_isLocalPlanNotifications && _isCheckingAccount) {
      return AarastSkeleton.list(
        rows: 6,
        rowHeight: 84,
        withHeader: false,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
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
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      );
    }

    if (!suppressData &&
        provider.errorMessage != null &&
        notifications.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
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
          SizedBox(height: 90),
          AarastEmptyState(
            icon: LucideIcons.bellOff,
            title: AarastV3Copy.quietNotificationsTitle,
            message: AarastV3Copy.quietNotificationsMessage,
            tone: AarastEmptyStateTone.positive,
          ),
        ],
      );
    }

    final groups = groupNotificationsByTime(notifications, DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                    onTap: () => _openNotification(provider, notification),
                    onArchive: () => provider.archiveNotification(notification),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (provider.hasMore) ...[
          const SizedBox(height: 4),
          JourneyButton.quiet(
            label: 'عرض المزيد',
            icon: LucideIcons.chevronsDown,
            loading: provider.isLoadingMore,
            expand: true,
            onPressed: () =>
                provider.loadMore(weddingPlanId: widget.weddingPlanId),
          ),
          const SizedBox(height: 12),
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
    if (!_isNotificationTargetCompatible(target)) {
      AarastToast.showError(
        context,
        'هذا التنبيه لا يطابق مسار الخطة المحدد حاليًا.',
      );
      return;
    }
    final marked = await provider.markRead(notification);
    if (!mounted || !marked) return;
    if (isPlanShellNotificationRouteTarget(target)) {
      context.go(target);
      return;
    }
    await context.push(target);
  }

  bool _isNotificationTargetCompatible(String target) {
    final targetUri = Uri.tryParse(target);
    final segments = targetUri?.pathSegments;
    final targetPlanId =
        segments != null &&
            segments.length >= 2 &&
            segments.first == 'wedding-plans'
        ? segments[1]
        : null;
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
  if (minutes < 1) return 'الحين';
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
  });

  final AarastNotification notification;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(notification.type);
    final copy = localizeNotification(
      type: notification.type,
      title: notification.title,
      body: notification.body,
    );
    final urgent = notification.priority.toUpperCase() == 'URGENT';
    final when = notificationWhenLabel(notification.createdAt, DateTime.now());
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
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JourneyIconTile(
                icon: tone.icon,
                color: tone.color,
                soft: tone.soft,
              ),
              const SizedBox(width: 12),
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
              Column(
                children: [
                  if (notification.isUnread)
                    const Padding(
                      padding: EdgeInsets.only(top: 6, bottom: 2),
                      child: SizedBox.square(
                        dimension: 9,
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
_NotificationTone _tone(String type) {
  final t = type.toUpperCase();
  if (t.contains('OVERDUE') || t.contains('EXCEEDED')) {
    return const _NotificationTone(
      icon: LucideIcons.alertTriangle,
      color: AarastV3Color.danger,
      soft: AarastV3Color.dangerSoft,
    );
  }
  if (t.contains('QUOTE')) {
    return const _NotificationTone(
      icon: LucideIcons.mailOpen,
      color: AarastV3Color.cobalt,
      soft: AarastV3Color.cobaltSoft,
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
    return const _NotificationTone(
      icon: LucideIcons.userCheck,
      color: AarastV3Color.lilac,
      soft: AarastV3Color.lilacSoft,
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
    return const _NotificationTone(
      icon: LucideIcons.userPlus,
      color: AarastV3Color.primary,
      soft: AarastV3Color.primarySoft,
    );
  }
  return const _NotificationTone(
    icon: LucideIcons.heart,
    color: AarastV3Color.primary,
    soft: AarastV3Color.primarySoft,
  );
}
