import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'offline_sync_service.dart';
import 'sync_status.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = _maybeSyncService(context);
    if (service == null) return const SizedBox.shrink();

    final state = service.state;
    final shouldShow =
        state == SyncState.offline ||
        state == SyncState.syncing ||
        state == SyncState.syncError ||
        service.pendingCount > 0;
    if (!shouldShow) return const SizedBox.shrink();

    final color = switch (state) {
      SyncState.offline => AppTheme.danger,
      SyncState.syncError => AppTheme.danger,
      SyncState.syncing => AppTheme.ink,
      _ => AppTheme.gold,
    };
    final label = switch (state) {
      SyncState.offline => 'بدون اتصال',
      SyncState.syncing => 'جار المزامنة',
      SyncState.syncError => 'تعذر مزامنة البيانات الآن',
      _ => 'بانتظار المزامنة',
    };
    final lastSync = service.lastSyncedAt == null
        ? 'آخر بيانات محفوظة'
        : 'آخر مزامنة: ${_shortTime(service.lastSyncedAt!)}';

    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          elevation: 3,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  state == SyncState.syncing
                      ? LucideIcons.refreshCw
                      : LucideIcons.cloudOff,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label • $lastSync',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (service.unsyncedCount > 0) ...[
                  const SizedBox(width: 8),
                  _CountPill(count: service.unsyncedCount, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OfflinePendingBadge extends StatelessWidget {
  const OfflinePendingBadge({
    required this.entityType,
    required this.entityId,
    super.key,
  });

  final String entityType;
  final String entityId;

  @override
  Widget build(BuildContext context) {
    final service = _maybeSyncService(context);
    if (service == null || !service.hasPendingEntity(entityType, entityId)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.goldSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.refreshCwOff, color: AppTheme.gold, size: 14),
          const SizedBox(width: 4),
          Text(
            'بانتظار المزامنة',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class OfflineSyncNowTile extends StatelessWidget {
  const OfflineSyncNowTile({super.key});

  @override
  Widget build(BuildContext context) {
    final service = _maybeSyncService(context);
    if (service == null) return const SizedBox.shrink();

    return ListTile(
      onTap: service.isSyncing
          ? null
          : service.blockedCount > 0
          ? service.retryBlockedChanges
          : service.syncPendingChanges,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.ivory,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(
          service.isSyncing ? LucideIcons.refreshCw : LucideIcons.cloudCog,
          color: AppTheme.ink,
        ),
      ),
      title: Text(
        service.blockedCount > 0 ? 'إعادة محاولة المزامنة' : 'مزامنة الآن',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        service.blockedCount > 0
            ? 'توجد تغييرات لم يقبلها الخادم: ${service.blockedCount}'
            : service.pendingCount > 0
            ? 'بانتظار المزامنة: ${service.pendingCount}'
            : 'تمت المزامنة بنجاح',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textDirection: TextDirection.ltr,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

OfflineSyncService? _maybeSyncService(BuildContext context) {
  try {
    return context.watch<OfflineSyncService>();
  } on ProviderNotFoundException {
    return null;
  }
}

String _shortTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
