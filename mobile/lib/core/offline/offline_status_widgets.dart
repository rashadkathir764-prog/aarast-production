import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../experience_v3/aarast_v3.dart';
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
      SyncState.offline => AarastV3Color.amber,
      SyncState.syncError => AarastV3Color.danger,
      SyncState.syncing => AarastV3Color.cobalt,
      _ => AarastV3Color.primary,
    };
    final label = switch (state) {
      SyncState.offline => 'دون اتصال — عملك محفوظ على الجهاز',
      SyncState.syncing => 'جارٍ حفظ آخر التغييرات',
      SyncState.syncError => 'تعذر مزامنة البيانات الآن',
      _ => 'سيُحفظ عند عودة الاتصال',
    };
    final lastSync = service.lastSyncedAt == null
        ? 'آخر بيانات محفوظة'
        : 'آخر مزامنة: ${_shortTime(service.lastSyncedAt!)}';

    final hasBlockedIssues = service.blockedCount > 0;
    final canRetry = state == SyncState.syncError || hasBlockedIssues;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: '$label. $lastSync',
            child: Container(
              key: const ValueKey('aarast-sync-status'),
              padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
              decoration: BoxDecoration(
                color: AarastV3Color.paper,
                borderRadius: BorderRadius.circular(AarastV3Radius.control),
                border: Border.all(color: AarastV3Color.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      state == SyncState.syncing
                          ? LucideIcons.refreshCw
                          : canRetry
                          ? LucideIcons.cloudCog
                          : LucideIcons.cloudOff,
                      color: color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AarastV3Color.ink,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          lastSync,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AarastV3Color.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (service.unsyncedCount > 0) ...[
                    const SizedBox(width: AarastV3Space.x2),
                    _CountPill(count: service.unsyncedCount, color: color),
                  ],
                  if (canRetry) ...[
                    const SizedBox(width: AarastV3Space.x1),
                    IconButton(
                      onPressed: service.isSyncing
                          ? null
                          : hasBlockedIssues
                          ? () => _showSyncIssues(context, service)
                          : service.syncPendingChanges,
                      tooltip: hasBlockedIssues
                          ? 'عرض تفاصيل المزامنة'
                          : 'إعادة محاولة المزامنة',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        hasBlockedIssues
                            ? LucideIcons.alertCircle
                            : LucideIcons.refreshCw,
                        size: 17,
                      ),
                    ),
                  ],
                ],
              ),
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
        color: AarastV3Color.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AarastV3Color.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.refreshCwOff,
            color: AarastV3Color.primary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'بانتظار المزامنة',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AarastV3Color.primary,
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
          ? () => _showSyncIssues(context, service)
          : service.syncPendingChanges,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(
          service.isSyncing ? LucideIcons.refreshCw : LucideIcons.cloudCog,
          color: AppTheme.textPrimary,
        ),
      ),
      title: Text(
        service.blockedCount > 0 ? 'مراجعة مشاكل المزامنة' : 'مزامنة الآن',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.textPrimary,
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
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(
        LucideIcons.chevronLeft,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

Future<void> _showSyncIssues(BuildContext context, OfflineSyncService service) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _SyncIssuesSheet(service: service),
  );
}

class _SyncIssuesSheet extends StatelessWidget {
  const _SyncIssuesSheet({required this.service});

  final OfflineSyncService service;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      key: const Key('sync-issues-sheet'),
      heightFactor: 0.82,
      child: FutureBuilder<List<SyncIssueSummary>>(
        future: service.loadBlockedIssues(),
        builder: (context, snapshot) {
          final issues = snapshot.data ?? const <SyncIssueSummary>[];
          final retryableCount = issues.where((issue) => issue.canRetry).length;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تفاصيل المزامنة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'إغلاق',
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
                Text(
                  'هذه التغييرات ما زالت محفوظة على جهازك ولم يقبلها الخادم بعد.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: switch (snapshot.connectionState) {
                    ConnectionState.waiting => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    _ when snapshot.hasError => Center(
                      child: Text(
                        'تعذر تحميل تفاصيل المزامنة الآن.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    _ when issues.isEmpty => Center(
                      child: Text(
                        'لا توجد تغييرات محجوبة حاليًا.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    _ => ListView.separated(
                      itemCount: issues.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final issue = issues[index];
                        return Semantics(
                          container: true,
                          label:
                              '${issue.entityLabel}. ${issue.operationLabel}. ${issue.message}',
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                LucideIcons.alertCircle,
                                color: AarastV3Color.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      issue.entityLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    Text(
                                      issue.operationLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      issue.message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  },
                ),
                if (snapshot.hasData && retryableCount > 0) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('sync-issues-retry'),
                    onPressed: service.isSyncing
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await service.retryBlockedChanges();
                          },
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: Text(
                      retryableCount == 1
                          ? 'إعادة محاولة هذا التغيير'
                          : 'إعادة محاولة $retryableCount تغييرات',
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
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
