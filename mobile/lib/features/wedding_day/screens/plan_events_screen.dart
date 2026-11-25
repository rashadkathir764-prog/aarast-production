import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_plans/wedding_plans_api.dart' show showPostponeSheet;
import '../models/plan_event.dart';
import '../providers/plan_events_provider.dart';
import '../widgets/plan_event_sheet.dart';

/// b12 «مناسبات عرسك»: the wedding's events, from which the wedding week
/// (b04) and the wedding day (b05) are built (D65). Every member reads
/// them (D52); the owner or a member who may edit the plan changes them.
class PlanEventsScreen extends StatefulWidget {
  const PlanEventsScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<PlanEventsScreen> createState() => _PlanEventsScreenState();
}

class _PlanEventsScreenState extends State<PlanEventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlanEventsProvider>().load(widget.weddingPlanId);
    });
  }

  Future<void> _open({PlanEvent? event, PlanEventType? type}) async {
    final provider = context.read<PlanEventsProvider>();
    final day = event?.date;
    await showPlanEventSheet(
      context,
      weddingPlanId: widget.weddingPlanId,
      provider: provider,
      event: event,
      type: type,
      onMoveDay: event?.isMain != true
          ? null
          : day != null
          ? () => _postpone(day)
          // RA-MO-196: no day yet: its first is set in «بيانات الخطة»,
          // the plan's own page (D11 of the closing round: this opened the
          // list of plans, «خططك»).
          : () => context.push(AppRouter.planCenter(widget.weddingPlanId)),
    );
  }

  /// The wedding's day is the plan's: g03 moves it with the tasks.
  Future<void> _postpone(DateTime day) async {
    final provider = context.read<PlanEventsProvider>();
    final moved = await showPostponeSheet(
      context,
      planId: widget.weddingPlanId,
      weddingDate: day,
    );
    if (moved) await provider.load(widget.weddingPlanId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanEventsProvider>();
    final view = provider.viewOf(widget.weddingPlanId);
    final profile = context.journeyProfile;

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        key: const ValueKey('plan-events'),
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: 'مناسبات عرسك',
            // RA-MO-209: only the last week's events make its program; an
            // earlier one (a ملكة a month before) is kept here alone.
            subtitle: 'اللي في آخر أسبوع قبل العرس تطلع في برنامجه',
            onBack: () => context.popOrGo(
              AppRouter.weddingPlanDashboard(widget.weddingPlanId),
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          if (view == null)
            JourneyListState(
              phase: provider.errorMessage == null
                  ? JourneyListPhase.loading
                  : JourneyListPhase.error,
              section: JourneySection.home,
              onRetry: () => provider.load(widget.weddingPlanId),
            )
          else ...[
            if (provider.isStale) ...[
              // D87: the copy is old; events queue on the phone (D85).
              // D24 of the closing round: an offline notice draws no retry,
              // as on every tab; the callback given here never showed.
              const JourneyListNotice(offline: true, keepsChanges: true),
              const SizedBox(height: AarastV3Space.x3),
            ],
            for (final event in view.items) ...[
              _EventCard(
                event: event,
                name: event.nameIn(profile, view.items),
                onEdit: view.canEdit ? () => _open(event: event) : null,
              ),
              const SizedBox(height: AarastV3Space.x3),
            ],
            if (view.canEdit && view.suggestions.isNotEmpty) ...[
              const SizedBox(height: AarastV3Space.x1),
              Text(
                'اقتراحات',
                style: JourneyType.of(
                  JourneyType.small,
                  weight: JourneyType.bold,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const SizedBox(height: AarastV3Space.x2),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in view.suggestions)
                    JourneyChip(
                      key: ValueKey('plan-event-suggest-${type.wire}'),
                      label: type.label(profile),
                      icon: LucideIcons.plus,
                      onTap: () => _open(type: type),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One event: its icon, name, «الثلاثاء 19 يناير · بعد العشاء», the place,
/// and its tag (the main event's, else the couple's note).
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.name,
    required this.onEdit,
  });

  final PlanEvent event;

  /// Its name among the plan's events (PlanEvent.nameIn).
  final String name;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final (color, soft) = event.type.colors(context.accent);
    final date = event.date;
    final when = [
      date == null ? 'اليوم ما تحدد' : formatArabicWeekdayDayMonth(date),
      ?event.timeLabel,
    ].join(' · ');
    final tag = event.isMain ? 'المناسبة الرئيسية' : event.note;
    return JourneyBox(
      key: ValueKey('plan-event-${event.type.wire}-${event.id ?? 'main'}'),
      radius: 28,
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x4,
        AarastV3Space.x3,
        AarastV3Space.x2,
        AarastV3Space.x3,
      ),
      child: Row(
        children: [
          JourneyIconTile(
            icon: event.type.icon,
            color: color,
            soft: soft,
            size: AarastV3Size.mark,
            radius: 18,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  when,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                if (event.placeLabel case final place?)
                  Text(
                    place,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                if (tag != null) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  JourneyTag(
                    label: tag,
                    color: AarastV3Color.brandAccentStrong,
                    soft: AarastV3Color.brandAccentSoft,
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'تعديل $name',
              onPressed: onEdit,
              icon: const Icon(
                LucideIcons.pencil,
                size: AarastV3Icon.md,
                color: AarastV3Color.textFaint,
              ),
            ),
        ],
      ),
    );
  }
}
