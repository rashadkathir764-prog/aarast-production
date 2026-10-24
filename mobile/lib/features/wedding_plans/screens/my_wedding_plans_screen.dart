import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../models/wedding_plan.dart';
import '../providers/wedding_plans_provider.dart';

/// w11 «خططك» as a page, for the routes that land on the plans list (no
/// open plan, after an archive). «حسابي» opens the same list as a sheet
/// with [showPlanSwitcherSheet].
class MyWeddingPlansScreen extends StatelessWidget {
  const MyWeddingPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          JourneySubHeader(
            title: 'خططك',
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRouter.home),
          ),
          const _PlanSwitcher(),
        ],
      ),
    );
  }
}

/// w11 over «حسابي»: every plan of yours and every plan you help in, the
/// open one marked, archived ones listed but closed (`set-active` refuses
/// them), and «خطة جديدة» (D28).
Future<void> showPlanSwitcherSheet(BuildContext context) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => JourneySheetBody(
      title: 'خططك',
      children: [const _PlanSwitcher(inSheet: true)],
    ),
  );
}

/// One row of w11: an owned plan or a plan you help in.
class _PlanEntry {
  const _PlanEntry.owned(WeddingPlan this.plan)
    : contextKey = null,
      title = null;

  const _PlanEntry.helped({
    required String this.contextKey,
    required String this.title,
  }) : plan = null;

  final WeddingPlan? plan;
  final String? contextKey;
  final String? title;

  String get name => plan?.title ?? title ?? '';
  bool get archived => plan?.status == 'ARCHIVED';
}

class _PlanSwitcher extends StatefulWidget {
  const _PlanSwitcher({this.inSheet = false});

  final bool inSheet;

  @override
  State<_PlanSwitcher> createState() => _PlanSwitcherState();
}

class _PlanSwitcherState extends State<_PlanSwitcher> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WeddingPlansProvider>().loadMyWeddingPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<WeddingPlansProvider>();
    final accounts = context.watch<AccountContextController?>();
    final selected = accounts?.selectedContext;
    final openPlanId = selected?.isPlan == true
        ? selected?.weddingPlanId
        : null;
    final entries = <_PlanEntry>[
      for (final plan in plans.plans.where((plan) => !_isArchived(plan)))
        _PlanEntry.owned(plan),
      for (final helped in accounts?.contexts ?? const [])
        if (helped.isPlan &&
            helped.isAvailable &&
            helped.role == AccountContextRole.contributor)
          _PlanEntry.helped(
            contextKey: helped.contextKey,
            title: helped.displayName,
          ),
      for (final plan in plans.plans.where(_isArchived)) _PlanEntry.owned(plan),
    ];

    if (plans.isLoading && plans.plans.isEmpty) {
      return const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.home,
      );
    }
    if (plans.errorMessage != null && plans.plans.isEmpty) {
      return JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.home,
        onRetry: plans.loadMyWeddingPlans,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) ...[
          _PlanCard(
            key: ValueKey(
              'plan-switcher-${entry.plan?.id ?? entry.contextKey}',
            ),
            entry: entry,
            open: entry.plan != null
                ? entry.plan!.id == openPlanId
                : entry.contextKey == selected?.contextKey,
            onTap: entry.archived || _opening ? null : () => _open(entry),
          ),
          const SizedBox(height: 10),
        ],
        AarastPressable(
          key: const ValueKey('plan-switcher-new'),
          onTap: () {
            if (widget.inSheet) Navigator.of(context).pop();
            GoRouter.of(context).push(AppRouter.createWeddingPlan);
          },
          borderRadius: BorderRadius.circular(22),
          semanticLabel: 'خطة جديدة',
          child: JourneyBox(
            color: AarastV3Color.primarySoft,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.plus, color: AarastV3Color.primary),
                const SizedBox(width: 8),
                Text(
                  'خطة جديدة',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                    color: AarastV3Color.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const JourneyNote(
          text:
              'تقدر تفتح أكثر من خطة، مثلًا لعرس أخوك. وكل خطة بمشاركينها '
              'وفلوسها.',
        ),
      ],
    );
  }

  static bool _isArchived(WeddingPlan plan) => plan.status == 'ARCHIVED';

  Future<void> _open(_PlanEntry entry) async {
    final accounts = context.read<AccountContextController>();
    final router = GoRouter.of(context);
    final plan = entry.plan;
    final current = accounts.selectedContext;
    if (plan != null && current?.weddingPlanId == plan.id) {
      if (widget.inSheet) Navigator.of(context).pop();
      router.go(AppRouter.weddingPlanDashboard(plan.id));
      return;
    }
    final helpedPlanId = current?.weddingPlanId;
    if (plan == null &&
        current?.contextKey == entry.contextKey &&
        helpedPlanId != null) {
      if (widget.inSheet) Navigator.of(context).pop();
      // A plan helped in opens on the participant's tabs (x06).
      router.go(AppRouter.home);
      return;
    }
    setState(() => _opening = true);
    var key = entry.contextKey;
    if (plan != null) {
      await accounts.refresh();
      if (!mounted) return;
      for (final candidate in accounts.contexts) {
        if (candidate.isPlan &&
            candidate.isAvailable &&
            candidate.role == AccountContextRole.owner &&
            candidate.weddingPlanId == plan.id) {
          key = candidate.contextKey;
          break;
        }
      }
    }
    final opened = key != null && await accounts.select(key);
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      AarastToast.showError(
        context,
        accounts.errorMessage ?? 'ما قدرنا نفتح الخطة. جرّب مرة ثانية.',
      );
      return;
    }
    final planId = accounts.selectedContext?.weddingPlanId;
    if (widget.inSheet) Navigator.of(context).pop();
    if (planId == null) return;
    router.go(
      plan != null ? AppRouter.weddingPlanDashboard(planId) : AppRouter.home,
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.entry,
    required this.open,
    required this.onTap,
    super.key,
  });

  final _PlanEntry entry;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final plan = entry.plan;
    final archived = entry.archived;
    final helped = plan == null;
    final color = archived
        ? AarastV3Color.textFaint
        : helped
        ? AarastV3Color.brandAccentStrong
        : AarastV3Color.primary;
    final (String? tag, Color tagColor, Color tagSoft) = archived
        ? ('مؤرشفة', AarastV3Color.textMuted, AarastV3Color.line)
        : helped
        ? ('مشارك', AarastV3Color.amber, AarastV3Color.amberSoft)
        : open
        ? ('مفتوحة', AarastV3Color.primary, AarastV3Color.primarySoft)
        : (null, AarastV3Color.primary, AarastV3Color.primarySoft);
    final name = entry.name.trim();
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: open ? AarastV3Color.primary : AarastV3Color.line,
          width: open ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          JourneyAvatar(
            letter: name.isEmpty ? 'ع' : _firstLetter(name),
            color: color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  _subtitle(entry),
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (tag != null)
            JourneyTag(label: tag, color: tagColor, soft: tagSoft),
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(label: '$name، ${_subtitle(entry)}', child: card);
    }
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      semanticLabel: '$name، ${_subtitle(entry)}',
      child: card,
    );
  }

  /// «عرس محمد» opens on «م», skipping the word «عرس».
  static String _firstLetter(String name) {
    final words = name.split(RegExp(r'\s+'));
    final word = words.length > 1 && words.first == 'عرس' ? words[1] : name;
    return word.characters.first;
  }

  /// «خطتك · 96 يوم», «أنت مشارك», «في الذكريات · 2025».
  static String _subtitle(_PlanEntry entry) {
    final plan = entry.plan;
    if (plan == null) return 'أنت مشارك';
    final day = plan.weddingDate;
    if (entry.archived) {
      return 'في الذكريات · ${(day ?? plan.updatedAt).year}';
    }
    if (day == null) return 'خطتك';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final left = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(today).inDays;
    if (left < 0) return 'خطتك · مرّ العرس';
    if (left == 0) return 'خطتك · اليوم';
    return 'خطتك · ${arabicDays(left)}';
  }
}
