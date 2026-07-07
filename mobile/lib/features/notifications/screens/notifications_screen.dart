import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
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
      subtitle: widget.weddingPlanId == null
          ? 'كل تنبيهات الحساب المحفوظة'
          : 'تنبيهات الخطة المحفوظة',
      actions: [
        if (unreadInList > 0)
          TextButton.icon(
            onPressed: provider.isSubmitting
                ? null
                : () =>
                      provider.markAllRead(weddingPlanId: widget.weddingPlanId),
            icon: const Icon(Icons.done_all_rounded),
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
        rows: 5,
        rowHeight: 108,
        withHeader: false,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      );
    }

    if (!_isLocalPlanNotifications && _showLoginGate) {
      return const AuthGatePanel(
        title: 'سجّل الدخول لعرض التنبيهات',
        body:
            'التنبيهات مرتبطة بحسابك وخططك المحفوظة، لذلك نعرضها بعد تسجيل الدخول.',
        icon: Icons.notifications_none_rounded,
      );
    }

    if (!suppressData && provider.isLoading && notifications.isEmpty) {
      return AarastSkeleton.list(
        rows: 5,
        rowHeight: 108,
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
            icon: Icons.notifications_none_rounded,
            title: 'لا توجد تنبيهات مهمة الآن.',
            message: 'عند وصول عرض سعر أو اقتراب مهمة ستظهر هنا.',
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
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
    final marked = await provider.markRead(notification);
    if (!mounted || !marked) return;
    final target = notification.routeTarget?.trim();
    if (target == null || !isSafeNotificationRouteTarget(target)) return;
    if (_isPlanShellRouteTarget(target)) {
      context.go(target);
      return;
    }
    await context.push(target);
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
    return AarastCard(
      color: notification.isUnread ? tone.background : AppTheme.ivory,
      border: Border.all(
        color: notification.isUnread
            ? tone.color.withValues(alpha: 0.1)
            : AppTheme.goldSoft.withAlpha(80),
      ),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(tone.icon, color: tone.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: tone.color,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    if (notification.isUnread)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppTheme.burgundy,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  copy.body,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _dateLabel(notification.createdAt),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (notification.priority == 'HIGH' ||
                        notification.priority == 'URGENT') ...[
                      const SizedBox(width: 8),
                      Text(
                        notification.priority == 'URGENT' ? 'عاجل' : 'مهم',
                        style: const TextStyle(
                          color: AppTheme.burgundy,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'أرشفة التنبيه',
            color: AppTheme.muted,
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
  if (type.contains('QUOTE')) {
    return const _NotificationTone(
      icon: Icons.request_quote_outlined,
      color: AppTheme.burgundy,
      background: AppTheme.burgundySoft,
    );
  }
  if (type.contains('INSTALLMENT')) {
    return const _NotificationTone(
      icon: Icons.credit_card_rounded,
      color: AppTheme.gold,
      background: AppTheme.ivory,
    );
  }
  if (type.contains('SHARING')) {
    return const _NotificationTone(
      icon: Icons.group_add_outlined,
      color: AppTheme.success,
      background: AppTheme.successSoft,
    );
  }
  if (type.contains('OVERDUE')) {
    return const _NotificationTone(
      icon: Icons.warning_amber_rounded,
      color: AppTheme.danger,
      background: AppTheme.burgundySoft,
    );
  }
  return const _NotificationTone(
    icon: Icons.assignment_turned_in_outlined,
    color: AppTheme.burgundy,
    background: AppTheme.burgundySoft,
  );
}

bool _isPlanShellRouteTarget(String target) {
  final uri = Uri.tryParse(target);
  final segments = uri?.pathSegments;
  if (segments == null ||
      segments.length < 3 ||
      segments[0] != 'wedding-plans') {
    return false;
  }

  final area = segments[2];
  if (segments.length == 3) {
    return area == 'dashboard' ||
        area == 'finance' ||
        area == 'tasks' ||
        area == 'guests' ||
        area == 'providers';
  }
  return area == 'guests' && segments.length == 4 && segments[3] == 'add';
}

String _dateLabel(DateTime date) {
  return formatArabicCompactDate(date);
}
