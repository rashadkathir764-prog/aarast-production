import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../experience_v3/aarast_v3.dart';
import '../theme/app_theme.dart';
import '../utils/arabic_count.dart';
import '../widgets/aarast_bottom_sheet.dart';
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
      SyncState.offline => 'بدون نت، واللي تضيفه ينحفظ في جوالك',
      SyncState.syncing => 'نرسل آخر تغييراتك',
      SyncState.syncError => 'ما قدرنا نرسل تغييراتك الحين',
      _ => 'تغييراتك تنرسل لما يرجع النت',
    };
    final lastSync = service.lastSyncedAt == null
        ? 'آخر بيانات محفوظة'
        : 'آخر إرسال: ${_shortTime(service.lastSyncedAt!)}';

    final hasBlockedIssues = service.blockedCount > 0;
    final canRetry = state == SyncState.syncError || hasBlockedIssues;
    final hasWaiting = service.unsyncedCount > 0;
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
                  if (canRetry || hasWaiting) ...[
                    const SizedBox(width: AarastV3Space.x1),
                    IconButton(
                      onPressed: service.isSyncing
                          ? null
                          : hasWaiting
                          ? () => showPendingChangesSheet(context, service)
                          : service.syncPendingChanges,
                      tooltip: hasWaiting
                          ? 'شوف التغييرات اللي تنتظر'
                          : 'حاول ترسل مرة ثانية',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        hasBlockedIssues
                            ? LucideIcons.alertCircle
                            : hasWaiting
                            ? LucideIcons.listChecks
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
            'ينتظر النت',
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
          : service.unsyncedCount > 0
          ? () => showPendingChangesSheet(context, service)
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
        service.blockedCount > 0 ? 'تغييرات ما وصلت' : 'أرسل التغييرات الحين',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        service.blockedCount > 0
            ? 'السيرفر رفض ${service.blockedCount}، راجعها'
            : service.pendingCount > 0
            ? '${service.pendingCount} تنتظر النت'
            : 'كل تغييراتك وصلت',
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

/// w41: every change still on the phone, in one sheet. Refused changes say
/// why; the rest wait for the network. «حاول الآن» sends what waits and
/// gives refused changes one more try.
Future<void> showPendingChangesSheet(
  BuildContext context,
  OfflineSyncService service,
) {
  return showAarastBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _PendingChangesSheet(service: service),
  );
}

class _PendingChangesSheet extends StatelessWidget {
  const _PendingChangesSheet({required this.service});

  final OfflineSyncService service;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PendingChangeSummary>>(
      key: const Key('sync-issues-sheet'),
      future: service.loadPendingChanges(),
      builder: (context, snapshot) {
        final changes = snapshot.data ?? const <PendingChangeSummary>[];
        final now = DateTime.now();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  changes.isEmpty
                      ? 'كل تغييراتك وصلت'
                      : arabicCount(
                          changes.length,
                          one: 'تغيير واحد ينتظر',
                          two: 'تغييرين ينتظرون',
                          few: 'تغييرات تنتظر',
                          many: 'تغيير ينتظر',
                        ),
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'محفوظة على جوالك، وتنرسل أول ما يرجع النت',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Text(
                  'ما قدرنا نقرأ التغييرات الحين.',
                  style: JourneyType.of(JourneyType.body),
                )
              else if (changes.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    child: JourneyBox(
                      padding: EdgeInsets.zero,
                      child: JourneyList(
                        children: [
                          for (final change in changes)
                            _PendingChangeRow(change: change, now: now),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              JourneyButton(
                key: const Key('sync-issues-retry'),
                label: 'حاول الآن',
                icon: LucideIcons.refreshCw,
                expand: true,
                large: true,
                onPressed: service.isSyncing || changes.isEmpty
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        if (service.blockedCount > 0) {
                          await service.retryBlockedChanges();
                        } else {
                          await service.syncPendingChanges();
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingChangeRow extends StatelessWidget {
  const _PendingChangeRow({required this.change, required this.now});

  final PendingChangeSummary change;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final minutes = now.difference(change.createdAt.toLocal()).inMinutes;
    final when = minutes < 1
        ? 'الحين'
        : minutes < 60
        ? 'قبل ${arabicCount(minutes, one: 'دقيقة', two: 'دقيقتين', few: 'دقائق', many: 'دقيقة')}'
        : minutes < 60 * 24
        ? 'قبل ${arabicCount(minutes ~/ 60, one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة')}'
        : 'قبل ${arabicCount(minutes ~/ (60 * 24), one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
    final (icon, color, soft) = change.blocked
        ? (
            LucideIcons.alertCircle,
            AarastV3Color.danger,
            AarastV3Color.dangerSoft,
          )
        : _changeTone(change.entityType);
    return JourneyListRow(
      icon: icon,
      color: color,
      soft: soft,
      title: change.title,
      subtitle: change.blocked ? '${change.reason} · $when' : when,
      trailing: change.blocked
          ? null
          : const Icon(
              LucideIcons.clock,
              size: 18,
              color: AarastV3Color.textFaint,
            ),
    );
  }
}

(IconData, Color, Color) _changeTone(String entityType) {
  return switch (entityType) {
    'task' => (
      LucideIcons.checkCircle2,
      AarastV3Color.brandAccentStrong,
      AarastV3Color.brandAccentSoft,
    ),
    'favorite_provider' => (
      LucideIcons.store,
      AarastV3Color.cobalt,
      AarastV3Color.cobaltSoft,
    ),
    'wedding_plan' => (
      LucideIcons.heart,
      AarastV3Color.primary,
      AarastV3Color.primarySoft,
    ),
    _ => (
      LucideIcons.receipt,
      AarastV3Color.primary,
      AarastV3Color.primarySoft,
    ),
  };
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
