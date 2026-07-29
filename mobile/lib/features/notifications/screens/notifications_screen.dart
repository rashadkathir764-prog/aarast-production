import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
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
                : () =>
                      provider.markAllRead(weddingPlanId: widget.weddingPlanId),
            icon: const Icon(LucideIcons.checkCheck, size: 18),
            label: const Text('قراءة الكل'),
          ),
      ],
      child: RefreshIndicator(
        color: AppTheme.burgundy,
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
            title: 'لا توجد تنبيهات مهمة الآن.',
            message: 'عند وصول عرض سعر أو اقتراب مهمة ستظهر هنا.',
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: notifications.length + (provider.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == notifications.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AarastButton(
              label: 'عرض المزيد',
              icon: LucideIcons.chevronsDown,
              isLoading: provider.isLoadingMore,
              onPressed: () =>
                  provider.loadMore(weddingPlanId: widget.weddingPlanId),
            ),
          );
        }
        final notification = notifications[index];
        return AarastStagger.item(
          context,
          _NotificationCard(
            notification: notification,
            onTap: () => _openNotification(provider, notification),
            onArchive: () => provider.archiveNotification(notification),
          ),
          index,
        );
      },
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
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
    final textTheme = Theme.of(context).textTheme;
    final isUrgent = notification.priority == 'URGENT';
    final hasPriority = isUrgent || notification.priority == 'HIGH';

    return AarastCard(
      color: notification.isUnread ? tone.background : AppTheme.ivory,
      border: Border.all(
        color: notification.isUnread
            ? tone.color.withValues(alpha: 0.1)
            : AppTheme.goldSoft.withAlpha(80),
      ),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(tone.icon, color: tone.color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (hasPriority) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? AppTheme.dangerSoft
                              : AppTheme.goldSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isUrgent ? 'عاجل' : 'مهم',
                          style: textTheme.labelSmall?.copyWith(
                            color: isUrgent
                                ? AppTheme.danger
                                : AppTheme.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (notification.isUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.burgundy,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  copy.body,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateLabel(notification.createdAt),
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onArchive,
            icon: const Icon(LucideIcons.archive, size: 17),
            tooltip: 'أرشفة التنبيه',
            color: AppTheme.muted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _NotificationTone {
  const _NotificationTone({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

_NotificationTone _tone(String type) {
  final upperType = type.toUpperCase();
  if (upperType.contains('QUOTE')) {
    return const _NotificationTone(
      icon: LucideIcons.mailOpen,
      color: AppTheme.burgundy,
      background: AppTheme.burgundySoft,
    );
  }
  // موعد الدفع المتأخر يبقى تنبيه خطر، لا تنبيه موعد عادي.
  if (upperType.contains('OVERDUE')) {
    return const _NotificationTone(
      icon: LucideIcons.alertTriangle,
      color: AppTheme.danger,
      background: AppTheme.burgundySoft,
    );
  }
  if (upperType.contains('PAYMENT_SCHEDULE')) {
    return const _NotificationTone(
      icon: LucideIcons.calendarClock,
      color: AppTheme.gold,
      background: AppTheme.ivory,
    );
  }
  if (upperType.contains('SHARING')) {
    return const _NotificationTone(
      icon: LucideIcons.userPlus,
      color: AppTheme.success,
      background: AppTheme.successSoft,
    );
  }
  return const _NotificationTone(
    icon: LucideIcons.listChecks,
    color: AppTheme.burgundy,
    background: AppTheme.burgundySoft,
  );
}

String _dateLabel(DateTime date) {
  return formatArabicCompactDate(date);
}
