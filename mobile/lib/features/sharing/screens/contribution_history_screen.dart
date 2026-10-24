import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/contribution_history.dart';
import '../models/shared_member.dart';
import '../providers/contribution_history_provider.dart';
import '../providers/sharing_provider.dart';

/// x20 «وش سوّى المشاركين»: what each participant did in the plan, newest
/// first, by day, with «الكل / المال / المهام / الضيوف»
/// (`GET P/contributions?section=`). The owner's own actions are not
/// recorded, so they are not shown. A participant opening it reads only
/// their own history, «اللي سجّلته». Rows are frozen history: nothing here
/// opens or edits the live item.
class ContributionHistoryScreen extends StatefulWidget {
  const ContributionHistoryScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<ContributionHistoryScreen> createState() =>
      _ContributionHistoryScreenState();
}

const _filters = <(String label, String? section)>[
  ('الكل', null),
  ('المال', 'MONEY'),
  ('المهام', 'TASKS'),
  ('الضيوف', 'GUESTS'),
];

class _ContributionHistoryScreenState extends State<ContributionHistoryScreen> {
  /// Null until the plan's access is known.
  bool? _isOwner;
  List<ContributionActor> _actors = const [];
  String? _section;
  bool _accessFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ContributionHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      _isOwner = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  /// Who is reading decides whose history: the owner reads each current
  /// participant by id; a participant reads their own.
  Future<void> _load() async {
    if (!mounted) return;
    final planId = widget.weddingPlanId;
    final sharing = context.read<SharingProvider>();
    final history = context.read<ContributionHistoryProvider>();
    setState(() => _accessFailed = false);
    final accessLoaded = await sharing.loadAccess(planId);
    if (!mounted || planId != widget.weddingPlanId) return;
    if (!accessLoaded) {
      setState(() => _accessFailed = true);
      return;
    }
    final isOwner = sharing.access.isOwner;
    var actors = const <ContributionActor>[];
    if (isOwner) {
      await sharing.loadMembers(planId);
      if (!mounted || planId != widget.weddingPlanId) return;
      if (sharing.errorMessage != null || sharing.authGateKind != null) {
        setState(() => _accessFailed = true);
        return;
      }
      actors = [
        for (final member in sharing.members)
          if (!member.isOwner)
            ContributionActor(userId: member.userId, name: _memberName(member)),
      ];
    }
    setState(() {
      _isOwner = isOwner;
      _actors = actors;
    });
    await history.load(
      planId,
      section: _section,
      actors: isOwner ? actors : null,
    );
  }

  Future<void> _filter(String? section) async {
    if (_section == section || _isOwner == null) return;
    setState(() => _section = section);
    await context.read<ContributionHistoryProvider>().load(
      widget.weddingPlanId,
      section: section,
      actors: _isOwner! ? _actors : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<ContributionHistoryProvider>();
    final owner = _isOwner ?? true;
    return AarastScreenFrame(
      key: const Key('contribution-history-screen'),
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            JourneySubHeader(
              title: owner ? 'وش سوّى المشاركين' : 'اللي سجّلته',
              subtitle: owner
                  ? 'كل اللي سوّاه المشاركين في خطتك'
                  : 'كل اللي سوّيته في الخطة، يبقى باسمك',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go(AppRouter.home),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (label, section) in _filters) ...[
                    JourneyChip(
                      key: ValueKey('history-filter-${section ?? 'ALL'}'),
                      label: label,
                      selected: _section == section,
                      onTap: () => _filter(section),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            ..._body(history, owner),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(ContributionHistoryProvider history, bool owner) {
    if (_accessFailed) {
      return [
        const SizedBox(height: 12),
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.home,
          onRetry: _load,
        ),
      ];
    }
    final rows = history.activities;
    if (_isOwner == null || (history.isLoading && rows.isEmpty)) {
      return const [
        SizedBox(height: 12),
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.home,
        ),
      ];
    }
    if (history.errorMessage != null && rows.isEmpty) {
      return [
        const SizedBox(height: 12),
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.home,
          onRetry: _load,
        ),
      ];
    }
    if (rows.isEmpty) {
      return [
        const SizedBox(height: 12),
        JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.home,
          emptyIcon: LucideIcons.history,
          emptyTitle: owner ? 'ما سوّى أحد شي بعد' : 'ما سجّلت شي بعد',
          emptyMessage: owner
              ? 'لما يضيف مشارك مهمة أو ضيف أو دفعة، تشوفها هنا باسمه.'
              : 'لما تضيف مهمة أو ضيف أو دفعة، تبقى هنا باسمك.',
        ),
      ];
    }

    final colors = <String, Color>{
      for (var i = 0; i < _actors.length; i++)
        _actors[i].userId: JourneyAvatar.paletteAt(i),
    };
    final days = <DateTime, List<ContributionActivity>>{};
    for (final row in rows) {
      final at = _when(row.event);
      days.putIfAbsent(DateTime(at.year, at.month, at.day), () => []).add(row);
    }
    final coverage = history.coverageStartsAt;
    final showMore =
        history.hasMore ||
        history.isLoadingMore ||
        history.requiresReload ||
        history.loadMoreError != null;
    return [
      for (final entry in days.entries) ...[
        JourneySectionTitle(_dayLabel(entry.key)),
        JourneyList(
          children: [
            for (final row in entry.value)
              _ActivityRow(
                activity: row,
                color: colors[row.actor?.userId] ?? AarastV3Color.primary,
              ),
          ],
        ),
      ],
      if (history.loadMoreError != null) ...[
        const SizedBox(height: 12),
        JourneyNote(
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          text: history.loadMoreError!,
        ),
      ],
      if (showMore) ...[
        const SizedBox(height: 12),
        JourneyButton.quiet(
          key: const Key('contribution-history-load-more'),
          label: history.requiresReload ? 'حدّث من البداية' : 'اللي قبلها',
          icon: history.requiresReload
              ? LucideIcons.refreshCw
              : LucideIcons.chevronsDown,
          expand: true,
          loading: history.isLoadingMore,
          onPressed: history.requiresReload ? _load : history.loadMore,
        ),
      ],
      if (coverage != null) ...[
        const SizedBox(height: 14),
        Text(
          'السجل يبدأ من ${formatArabicCompactDate(coverage.toLocal())}',
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.caption,
            color: AarastV3Color.textFaint,
          ),
        ),
      ],
    ];
  }
}

String _memberName(SharedMember member) {
  final name = member.user?.name.trim();
  if (name != null && name.isNotEmpty) return name;
  return member.directionalDisplayName;
}

DateTime _when(ContributionHistoryEvent event) =>
    (event.occurredAt ?? event.capturedAt).toLocal();

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return 'اليوم';
  if (days == 1) return 'أمس';
  return formatArabicDayMonth(day);
}

/// «10:20 الصبح», «4:00 العصر», «7:45 مساءً».
String _clock(DateTime at) {
  final hour = at.hour;
  final part = switch (hour) {
    < 4 => 'الليل',
    < 12 => 'الصبح',
    < 15 => 'الظهر',
    < 18 => 'العصر',
    _ => 'مساءً',
  };
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '$twelve:$minute $part';
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.color});

  final ContributionActivity activity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final event = activity.event;
    final actor = activity.actor;
    final self = actor == null;
    final who = self ? 'أنت' : actor.name;
    final what = activityLine(event, self: self);
    final at = _when(event);
    return Semantics(
      container: true,
      label: '$who $what، ${_clock(at)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JourneyAvatar(
              letter: who.trim().isEmpty ? 'م' : who.trim().characters.first,
              color: color,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$who ',
                          style: JourneyType.of(
                            JourneyType.body,
                            weight: JourneyType.bold,
                          ),
                        ),
                        TextSpan(
                          text: what,
                          style: JourneyType.of(JourneyType.body),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _clock(at),
                    style: JourneyType.of(
                      JourneyType.caption,
                      color: AarastV3Color.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(_icon(event), size: 17, color: AarastV3Color.textFaint),
          ],
        ),
      ),
    );
  }
}

IconData _icon(ContributionHistoryEvent event) {
  return switch (event.action) {
    'PAYMENT_REVERSED' => LucideIcons.refreshCw,
    'COMPLETED' => LucideIcons.checkCircle2,
    'INVITED' => LucideIcons.userPlus,
    'MEMBER_LEFT' => LucideIcons.logOut,
    _ => switch (event.section) {
      'MONEY' => LucideIcons.wallet,
      'TASKS' => LucideIcons.listChecks,
      'GUESTS' => LucideIcons.users,
      'PROVIDERS' => LucideIcons.store,
      'MEMBERS' => LucideIcons.userCheck,
      _ => LucideIcons.clipboardList,
    },
  };
}

/// What a row says after the name, from the frozen snapshot: «سجّل دفعة
/// الغداء 200,000 ر.ي», «خلّص "استلم البدلة"». [self] speaks to the reader
/// («سجّلت»).
@visibleForTesting
String activityLine(ContributionHistoryEvent event, {required bool self}) {
  final s = event.snapshot;
  String? text(String key) {
    final value = s[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  final title =
      text('title') ??
      text('displayName') ??
      text('groupDisplayName') ??
      text('providerDisplayLabel') ??
      text('categoryLabel');
  final amountValue = s['amount'] ?? s['paidAmount'] ?? s['totalAmount'];
  final amount = amountValue is num
      ? stripMoneyDirectionalityMarks(
          formatCompactMoney(
            amountValue,
            currencyCode: text('currency') ?? defaultCurrencyCode,
          ),
        )
      : null;
  String verb(String he, String you) => self ? you : he;
  final noun = switch (event.entityType) {
    'TASK' => 'مهمة',
    'TASK_CHECKLIST_ITEM' => 'بند',
    'GUEST' => 'الضيف',
    'GUEST_GROUP' => 'مجموعة',
    'COST_PAYMENT' => 'دفعة',
    'PAYMENT_SCHEDULE' => 'موعد دفعة',
    'WEDDING_COST' || 'MONEY_ITEM' => 'تكلفة',
    'BUDGET_CATEGORY' => 'بند ميزانية',
    'QUOTE_REQUEST' => 'طلب عرض من',
    'PROVIDER_ITEM' || 'PLAN_PROVIDER_LINK' => 'المزود',
    'PLAN_INVITE' || 'MEMBER_ITEM' => 'مشارك',
    _ => null,
  };
  String withTitle(String action) {
    final parts = [
      action,
      ?noun,
      if (title != null)
        event.entityType.startsWith('TASK') ? '"$title"' : title,
      ?amount,
    ];
    return parts.join(' ');
  }

  return switch (event.action) {
    'COMPLETED' when title != null =>
      '${verb('خلّص', 'خلّصت')} ${event.entityType.startsWith('TASK') ? '"$title"' : title}',
    'COMPLETED' => withTitle(verb('خلّص', 'خلّصت')),
    'CREATED' => withTitle(verb('أضاف', 'أضفت')),
    'UPDATED' => withTitle(verb('عدّل', 'عدّلت')),
    'DELETED' => withTitle(verb('شال', 'شلت')),
    'ASSIGNED' => withTitle(verb('تكلّف بـ', 'تكلّفت بـ')),
    'UNASSIGNED' => withTitle(verb('ترك', 'تركت')),
    'REOPENED' => withTitle(verb('رجّع', 'رجّعت')),
    'STATUS_CHANGED' => withTitle(verb('غيّر حالة', 'غيّرت حالة')),
    'PAYMENT_RECORDED' => withTitle(verb('سجّل', 'سجّلت')),
    'PAYMENT_REVERSED' => withTitle(verb('عكس', 'عكست')),
    'INVITED' => withTitle(verb('دعا', 'دعيت')),
    'MEMBER_LEFT' => verb('طلع من الخطة', 'طلعت من الخطة'),
    _ => withTitle(verb('سجّل', 'سجّلت')),
  };
}
