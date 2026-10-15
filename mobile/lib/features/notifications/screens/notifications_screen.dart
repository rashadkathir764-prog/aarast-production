import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
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

    return AarastPageScaffold(
      title: 'التنبيهات',
      // العنوان الفرعي حي: عدد غير المقروء أهم من وصف ثابت.
      subtitle: unreadInList > 0
          ? '$unreadInList غير مقروء'
          : widget.weddingPlanId == null
          ? 'كل تنبيهات الحساب المحفوظة'
          : 'تنبيهات الخطة المحفوظة',
      actions: [
        if (unreadInList > 0)
          TextButton.icon(
            onPressed: provider.isSubmitting
                ? null
                : () => _markAllRead(provider),
            icon: const Icon(LucideIcons.checkCheck, size: 18),
            label: const Text('قراءة الكل'),
          ),
      ],
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: _load,
        child: _body(provider, notifications: notifications),
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

    final groups = aarastTemporalGroups(
      notifications,
      _notificationTemporalSection,
    );

    return ListView(
      padding: const EdgeInsets.only(top: AarastV3Space.x2, bottom: 24),
      children: [
        for (final group in groups.entries) ...[
          _NotificationGroupHeader(
            section: group.key,
            count: group.value.length,
          ),
          const SizedBox(height: AarastV3Space.x2),
          AarastV3ContinuousSurface(
            children: [
              for (final notification in group.value)
                _NotificationRow(
                  notification: notification,
                  onTap: () => _openNotification(provider, notification),
                  onArchive: () => provider.archiveNotification(notification),
                ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x4),
        ],
        if (provider.hasMore) ...[
          const SizedBox(height: AarastV3Space.x4),
          AarastButton(
            label: 'عرض المزيد',
            icon: LucideIcons.chevronsDown,
            isLoading: provider.isLoadingMore,
            onPressed: () =>
                provider.loadMore(weddingPlanId: widget.weddingPlanId),
          ),
        ],
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

class _NotificationGroupHeader extends StatelessWidget {
  const _NotificationGroupHeader({required this.section, required this.count});

  final AarastTemporalSection section;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AarastSectionHeader(
      title: '${section.label} · $count',
      icon: switch (section) {
        AarastTemporalSection.now => LucideIcons.zap,
        AarastTemporalSection.today => LucideIcons.sun,
        AarastTemporalSection.week => LucideIcons.calendarDays,
        AarastTemporalSection.later => LucideIcons.history,
        AarastTemporalSection.completed => LucideIcons.checkCheck,
      },
    );
  }
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
    final isUrgent = notification.priority == 'URGENT';
    final hasPriority = isUrgent || notification.priority == 'HIGH';

    return AarastV3ListRow(
      title: copy.title,
      subtitle: copy.body,
      meta: _dateLabel(notification.createdAt),
      accent: tone.color,
      onTap: onTap,
      semanticLabel: '${copy.title}، ${copy.body}',
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tone.color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AarastV3Radius.control),
        ),
        child: Icon(tone.icon, color: tone.color, size: 17),
      ),
      status: _NotificationStatus(
        isUnread: notification.isUnread,
        label: hasPriority ? (isUrgent ? 'عاجل' : 'مهم') : null,
        color: isUrgent ? AarastV3Color.danger : AarastV3Color.amber,
      ),
      action: IconButton(
        onPressed: onArchive,
        icon: const Icon(LucideIcons.archive, size: 17),
        tooltip: 'أرشفة التنبيه',
        color: AarastV3Color.textMuted,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _NotificationStatus extends StatelessWidget {
  const _NotificationStatus({
    required this.isUnread,
    required this.label,
    required this.color,
  });

  final bool isUnread;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AarastV3Radius.pill),
            ),
            child: Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (isUnread) ...[
          if (label != null) const SizedBox(width: AarastV3Space.x2),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AarastV3Color.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationTone {
  const _NotificationTone({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

_NotificationTone _tone(String type) {
  final upperType = type.toUpperCase();
  if (upperType.contains('QUOTE')) {
    return const _NotificationTone(
      icon: LucideIcons.mailOpen,
      color: AppTheme.brand,
    );
  }
  // موعد الدفع المتأخر يبقى تنبيه خطر، لا تنبيه موعد عادي.
  if (upperType.contains('OVERDUE')) {
    return const _NotificationTone(
      icon: LucideIcons.alertTriangle,
      color: AppTheme.danger,
    );
  }
  // بند تجاوز ميزانيته المخططة.
  if (upperType.contains('EXCEEDED')) {
    return const _NotificationTone(
      icon: LucideIcons.alertTriangle,
      color: AppTheme.danger,
    );
  }
  if (upperType.contains('PAYMENT_SCHEDULE') ||
      upperType.contains('LOAN_REPAYMENT')) {
    return const _NotificationTone(
      icon: LucideIcons.calendarClock,
      color: AppTheme.focus,
    );
  }
  if (upperType == 'WEDDING_COUNTDOWN') {
    return const _NotificationTone(
      icon: LucideIcons.heart,
      color: AppTheme.brand,
    );
  }
  if (upperType == 'BOOKING_UPDATED') {
    return const _NotificationTone(
      icon: LucideIcons.calendarCheck,
      color: AppTheme.success,
    );
  }
  if (upperType.contains('SHARING')) {
    return const _NotificationTone(
      icon: LucideIcons.userPlus,
      color: AppTheme.success,
    );
  }
  return const _NotificationTone(
    icon: LucideIcons.listChecks,
    color: AppTheme.brand,
  );
}

String _dateLabel(DateTime date) {
  return formatArabicCompactDate(date);
}

AarastTemporalSection _notificationTemporalSection(
  AarastNotification notification,
) {
  final priority = notification.priority.toUpperCase();
  return aarastActivitySection(
    occurredAt: notification.createdAt,
    completed: !notification.isUnread,
    urgent: priority == 'URGENT' || priority == 'HIGH',
  );
}
