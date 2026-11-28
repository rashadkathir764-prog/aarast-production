import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../experience_v3/aarast_v3.dart';
import '../network/server_reachability.dart';
import '../routing/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/app_clock.dart';
import '../utils/arabic_count.dart';
import '../widgets/aarast_loading_state.dart' show AarastInlineSpinner;
import 'local_database_contract.dart';
import 'offline_sync_service.dart';
import 'offline_tables.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

/// Who reads the banner: what the phone keeps differs by side.
enum OfflineAudience { couple, provider }

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({
    this.audience = OfflineAudience.couple,
    super.key,
  });

  final OfflineAudience audience;

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
      _ => context.accent.primary,
    };
    // D84: «بدون نت» only when the phone's own network refused; a slow or
    // down server is said as measured, and the line opens «فحص الاتصال».
    final failure = service.lastReachabilityFailure;
    final phoneOffline =
        failure == null || failure.cause == ReachabilityCause.noNetwork;
    // D87: the provider's phone keeps his offers. The couple's keeps every
    // change to the plan (D85): «المال والمهام» left the guests out, which
    // are kept too.
    final kept = audience == OfflineAudience.provider
        ? 'عروضك تنحفظ'
        : ReaderVoice.say('اللي تسوّيه ينحفظ', 'اللي تسوّينه ينحفظ');
    final label = switch (state) {
      SyncState.offline =>
        phoneOffline
            ? 'بدون نت. $kept في جوالك لين يرجع النت'
            : 'ما نقدر نوصل الحين. $kept في جوالك',
      SyncState.syncing => 'نرسل آخر تغييراتك',
      SyncState.syncError => 'ما قدرنا نرسل تغييراتك',
      _ => 'تغييراتك تنرسل لما يرجع النت',
    };
    // RA-MO-23: a cause that only repeats the line above («ما قدرنا نوصل
    // للخادم» under «ما نقدر نوصل للخادم الحين») is not said again.
    final lastSync = state == SyncState.offline && failure != null
        ? failure.cause == ReachabilityCause.unknown && !phoneOffline
              ? ReaderVoice.say('اضغط للفحص', 'اضغطي للفحص')
              : ReaderVoice.say(
                  '${reachabilityCauseLabel(failure.cause)} · اضغط للفحص',
                  '${reachabilityCauseLabel(failure.cause)} · اضغطي للفحص',
                )
        : service.lastSyncedAt == null
        ? 'آخر بيانات محفوظة'
        : 'آخر إرسال: ${_shortTime(service.lastSyncedAt!)}';
    final opensCheck = state == SyncState.offline;

    final hasBlockedIssues = service.blockedCount > 0;
    final canRetry = state == SyncState.syncError || hasBlockedIssues;
    final hasWaiting = service.unsyncedCount > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x5,
        AarastV3Space.half,
        AarastV3Space.x5,
        AarastV3Space.x1,
      ),
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AarastV3Density.readableWidth,
          ),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: '$label. $lastSync',
            child: GestureDetector(
              key: const ValueKey('aarast-sync-status-tap'),
              behavior: HitTestBehavior.opaque,
              onTap: opensCheck
                  ? () => GoRouter.maybeOf(
                      context,
                    )?.push(AppRouter.connectionCheck)
                  : null,
              child: Container(
                key: const ValueKey('aarast-sync-status'),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AarastV3Space.x2,
                  AarastV3Space.x2,
                  AarastV3Space.x2,
                  AarastV3Space.x2,
                ),
                decoration: BoxDecoration(
                  color: AarastV3Color.paper,
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                  border: Border.all(color: AarastV3Color.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: AarastV3Size.mark,
                      height: AarastV3Size.mark,
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
                        size: AarastV3Icon.sm,
                      ),
                    ),
                    const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // RA-MO-23: two lines, so the half that says what
                          // the phone keeps is never the half cut off.
                          Text(
                            label,
                            maxLines: 2,
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
                            ? ReaderVoice.say(
                                'شوف التغييرات اللي تنتظر',
                                'شوفي التغييرات اللي تنتظر',
                              )
                            : ReaderVoice.say(
                                'حاول ترسل مرة ثانية',
                                'حاولي ترسلين مرة ثانية',
                              ),
                        icon: Icon(
                          hasBlockedIssues
                              ? LucideIcons.alertCircle
                              : hasWaiting
                              ? LucideIcons.listChecks
                              : LucideIcons.refreshCw,
                          size: AarastV3Icon.sm,
                        ),
                      ),
                    ],
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x2,
        vertical: AarastV3Space.x1,
      ),
      decoration: BoxDecoration(
        color: context.accent.primarySoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
        border: Border.all(color: AarastV3Color.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.refreshCwOff,
            color: context.accent.primary,
            size: AarastV3Icon.sm,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Text(
            'ينتظر النت',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.accent.primary,
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
        width: AarastV3Size.mark,
        height: AarastV3Size.mark,
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
        service.blockedCount > 0
            ? 'تغييرات ما وصلت'
            : ReaderVoice.say('أرسل التغييرات الحين', 'أرسلي التغييرات الحين'),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        service.blockedCount > 0
            ? '${service.blockedCount} ما انقبلت، تحتاج مراجعة'
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
/// gives refused changes one more try; a change refused as changed
/// elsewhere gets none (RA-MO-344), and is only dropped.
Future<void> showPendingChangesSheet(
  BuildContext context,
  OfflineSyncService service,
) {
  return showJourneySheet<void>(
    context: context,
    builder: (sheetContext) => _PendingChangesSheet(service: service),
  );
}

class _PendingChangesSheet extends StatelessWidget {
  const _PendingChangesSheet({required this.service});

  final OfflineSyncService service;

  Future<(List<PendingChangeSummary>, Map<String, String>)> _load() async {
    final changes = await service.loadPendingChanges();
    final screens = await _refusedChangeScreens(service.database);
    return (changes, screens);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<PendingChangeSummary>, Map<String, String>)>(
      key: const Key('sync-issues-sheet'),
      future: _load(),
      builder: (context, snapshot) {
        final changes = snapshot.data?.$1 ?? const <PendingChangeSummary>[];
        final screens = snapshot.data?.$2 ?? const <String, String>{};
        final now = appNow();
        final canRetry = changes.any((change) => !change.changedElsewhere);
        // A refused change does not wait for the network (D86): it waits for
        // the person. The title said «ينتظر… تنرسل أول ما يرجع النت» of a
        // change the server had already refused.
        final refused = changes.where((change) => change.blocked).length;
        final waiting = changes.length - refused;
        return JourneySheetBody(
          title: changes.isEmpty
              ? 'كل تغييراتك وصلت'
              : refused > 0
              ? arabicCount(
                  refused,
                  one: 'تغيير واحد ما انقبل',
                  two: 'تغييرين ما انقبلوا',
                  few: 'تغييرات ما انقبلت',
                  many: 'تغيير ما انقبل',
                )
              : arabicCount(
                  changes.length,
                  one: 'تغيير واحد ينتظر',
                  two: 'تغييرين ينتظرون',
                  few: 'تغييرات تنتظر',
                  many: 'تغيير ينتظر',
                ),
          subtitle: refused == 0
              ? 'محفوظة على جوالك، وتنرسل أول ما يرجع النت'
              : waiting == 0
              ? 'السبب تحت كل واحد'
              : 'السبب تحت كل واحد. والباقي محفوظ على جوالك، وينرسل أول ما يرجع النت',
          // The list scrolls; the retry stays in reach under it.
          bottom: changes.isNotEmpty && !canRetry
              ? null
              : JourneyButton(
                  key: const Key('sync-issues-retry'),
                  label: ReaderVoice.say('حاول الحين', 'حاولي الحين'),
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
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              // Critique ط3: the kit's spinner, not Material's ring.
              const Padding(
                padding: EdgeInsets.all(AarastV3Space.x6),
                child: Center(
                  child: AarastInlineSpinner(
                    dimension: AarastV3Icon.xl,
                    color: AarastV3Color.primary,
                  ),
                ),
              )
            else if (snapshot.hasError)
              Text(
                'ما قدرنا نقرأ التغييرات.',
                style: JourneyType.of(JourneyType.body),
              )
            else if (changes.isNotEmpty)
              JourneyBox(
                padding: EdgeInsets.zero,
                child: JourneyList(
                  children: [
                    for (final change in changes)
                      _PendingChangeRow(
                        change: change,
                        now: now,
                        // D86: a refused change is the person's to drop,
                        // and dropping it cannot be undone: asked first.
                        onDiscard: change.blocked
                            ? () async {
                                final sure = await _confirmDiscard(
                                  context,
                                  change.title,
                                );
                                if (!sure) return;
                                await service.discardBlockedChange(change.id);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              }
                            : null,
                        // D127 (Q-70): where it has a screen, the thing
                        // itself opens, to be fixed and sent again.
                        onOpen: switch (screens[change.id]) {
                          final screen? when change.blocked => () {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.push(screen);
                          },
                          _ => null,
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Dropping a refused change deletes it from the phone for good: asked
/// first, with its name.
Future<bool> _confirmDiscard(BuildContext context, String title) async {
  final sure = await showJourneySheet<bool>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      key: const Key('sync-discard-confirm'),
      title: ReaderVoice.say(
        'تمسح «$title» من جوالك؟',
        'تمسحين «$title» من جوالك؟',
      ),
      subtitle: 'ما يرجع بعدها.',
      children: [
        JourneyButton(
          key: const Key('sync-discard-yes'),
          label: ReaderVoice.say('امسحه', 'امسحيه'),
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyButton.quiet(
          key: const Key('sync-discard-no'),
          label: 'رجوع',
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );
  return sure == true;
}

/// D127 (Q-70): the screen each refused change opens on, by its queue id:
/// a task, a guest and an agreement their own, a payment or a date to pay
/// its agreement. Only where the phone holds the thing (made offline and
/// never accepted, its copy is there); a delete, or a kind with no screen
/// of its own, opens nothing.
Future<Map<String, String>> _refusedChangeScreens(
  LocalDatabase database,
) async {
  Future<bool> held(String table, String id) async =>
      await database.readCachedItem(table: table, id: id) != null;
  Future<String?> costOf(List<String> tables, String id) async {
    for (final table in tables) {
      final costId = (await database.readCachedItem(
        table: table,
        id: id,
      ))?['costId']?.toString();
      if (costId != null && costId.isNotEmpty) return costId;
    }
    return null;
  }

  Future<String?> screenOf(SyncQueueItem item) async {
    final planId = item.planId;
    final id = item.localEntityId;
    if (planId == null || id == null || id.isEmpty) return null;
    if (item.operation == 'delete') return null;
    switch (item.entityType) {
      case 'task':
        return await held(OfflineTables.cachedTasks, id)
            ? AppRouter.taskDetails(planId, id)
            : null;
      case 'guest':
        return await held(OfflineTables.cachedGuests, id)
            ? AppRouter.guestDetails(planId, id)
            : null;
      case 'cost':
        return await held(OfflineTables.cachedCosts, id)
            ? AppRouter.moneyCostDetails(planId, id)
            : null;
      case 'cost_payment' || 'payment_schedule':
        final costId = await costOf(
          item.entityType == 'cost_payment'
              ? const [OfflineTables.cachedCostPayments]
              // Paying a date writes a payment under the date's own id.
              : const [
                  OfflineTables.cachedPaymentSchedules,
                  OfflineTables.cachedCostPayments,
                ],
          id,
        );
        return costId != null && await held(OfflineTables.cachedCosts, costId)
            ? AppRouter.moneyCostDetails(planId, costId)
            : null;
    }
    return null;
  }

  return {
    for (final item in await database.blockedSyncItems())
      item.id: ?await screenOf(item),
  };
}

class _PendingChangeRow extends StatelessWidget {
  const _PendingChangeRow({
    required this.change,
    required this.now,
    this.onDiscard,
    this.onOpen,
  });

  final Future<void> Function()? onDiscard;

  /// D127 (Q-70): opens the refused thing; null where it has no screen.
  final VoidCallback? onOpen;

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
        : 'قبل ${arabicDays(minutes ~/ (60 * 24))}';
    final (icon, color, soft) = change.blocked
        ? (
            LucideIcons.alertCircle,
            AarastV3Color.danger,
            AarastV3Color.dangerSoft,
          )
        : _changeTone(change.entityType, context.accent);
    return JourneyListRow(
      icon: icon,
      color: color,
      soft: soft,
      title: change.title,
      subtitle: change.reason != null ? '${change.reason} · $when' : when,
      // The reason is why it was refused: read whole, never cut at a line.
      subtitleMaxLines: change.reason != null ? 3 : 1,
      trailing: change.blocked
          ? (onDiscard == null && onOpen == null
                ? null
                // One over the other: side by side they squeezed the
                // reason at 320 wide.
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (onOpen != null)
                        JourneyTextAction(
                          key: ValueKey('sync-open-${change.id}'),
                          label: ReaderVoice.say('افتحه', 'افتحيه'),
                          color: context.accent.primary,
                          onPressed: onOpen,
                        ),
                      if (onDiscard != null)
                        JourneyTextAction(
                          key: ValueKey('sync-discard-${change.id}'),
                          label: ReaderVoice.say('احذفه', 'احذفيه'),
                          color: AarastV3Color.danger,
                          onPressed: onDiscard,
                        ),
                    ],
                  ))
          : const Icon(
              LucideIcons.clock,
              size: AarastV3Icon.md,
              color: AarastV3Color.textFaint,
            ),
    );
  }
}

(IconData, Color, Color) _changeTone(String entityType, JourneyAccent accent) {
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
    'wedding_plan' => (LucideIcons.heart, accent.primary, accent.primarySoft),
    _ => (LucideIcons.receipt, accent.primary, accent.primarySoft),
  };
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x2,
        vertical: AarastV3Space.x1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
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
