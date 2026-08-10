import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/guest.dart';

/// Compact, truthful guest summary that keeps the guest list above the fold.
class GuestAttendanceBrief extends StatelessWidget {
  const GuestAttendanceBrief({
    required this.summary,
    this.isLocalPlan = false,
    this.footer,
    this.heroTag,
    super.key,
  });

  final GuestSummary summary;
  final bool isLocalPlan;
  final Widget? footer;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final isFresh = summary.totalGuests == 0;
    final groomCount = summary.bySideForSuper['groom'] ?? 0;
    final brideCount = summary.bySideForSuper['bride'] ?? 0;
    final unknownCount = summary.bySideForSuper['unknown'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('guests-attendance-brief'),
          padding: const EdgeInsets.all(AarastV3Space.x4),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.surface),
            border: Border.all(color: AarastV3Color.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (heroTag == null)
                    const Icon(
                      LucideIcons.users,
                      size: 19,
                      color: AarastV3Color.primary,
                    )
                  else
                    AarastV3HeroIcon(
                      heroTag: heroTag,
                      icon: LucideIcons.users,
                      size: 19,
                      color: AarastV3Color.primary,
                    ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Text(
                      'الضيوف',
                      style: AarastV3Type.label(
                        context,
                      ).copyWith(color: AarastV3Color.primary),
                    ),
                  ),
                  if (isLocalPlan) const _LocalPlanningBadge(),
                ],
              ),
              const SizedBox(height: AarastV3Space.x2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFresh ? '—' : '${summary.expectedSeatsCount}',
                        style: AarastV3Type.display(
                          context,
                        ).copyWith(color: AarastV3Color.primary, fontSize: 32),
                      ),
                      Text('مقعد متوقع', style: AarastV3Type.label(context)),
                    ],
                  ),
                  const SizedBox(width: AarastV3Space.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFresh
                              ? 'ابدأ بقائمة صغيرة'
                              : _invitationCountLabel(summary.totalGuests),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AarastV3Type.section(
                            context,
                          ).copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AarastV3Space.x1),
                        if (isFresh)
                          Text(
                            'سنحسب المقاعد والردود تلقائيًا.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AarastV3Color.textMuted),
                          )
                        else
                          Row(
                            children: [
                              if (summary.companionsExpectedCount > 0) ...[
                                Expanded(
                                  child: Text(
                                    _companionsLabel(
                                      summary.companionsExpectedCount,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AarastV3Color.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: AarastV3Space.x2),
                              ],
                              Expanded(
                                child: Text(
                                  _sideBreakdown(
                                    groom: groomCount,
                                    bride: brideCount,
                                    unknown: unknownCount,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AarastV3Color.textMuted,
                                      ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x3),
              Row(
                children: [
                  _GuestMetric(
                    label: 'مؤكد',
                    value: '${summary.confirmed}',
                    accent: AarastV3Color.mint,
                  ),
                  _GuestMetric(label: 'بانتظار', value: '${summary.pending}'),
                  _GuestMetric(
                    label: 'لن يحضر',
                    value: '${summary.declined}',
                    accent: AarastV3Color.rose,
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x2),
              AarastV3PlanPath(
                value: summary.totalGuests == 0
                    ? 0
                    : (summary.confirmed + summary.declined) /
                          summary.totalGuests,
                semanticsLabel: 'مسار اكتمال ردود الضيوف',
              ),
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          footer!,
        ],
      ],
    );
  }
}

class _GuestMetric extends StatelessWidget {
  const _GuestMetric({
    required this.label,
    required this.value,
    this.accent = AarastV3Color.primary,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: AarastV3Space.x1),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AarastV3Color.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalPlanningBadge extends StatelessWidget {
  const _LocalPlanningBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AarastV3Color.primarySoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.smartphone,
            size: 12,
            color: AarastV3Color.primary,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Text(
            'تخطيط محلي',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AarastV3Color.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _companionsLabel(int count) {
  return switch (count) {
    1 => 'منهم مرافق واحد',
    2 => 'منهم مرافقان',
    >= 3 && <= 10 => 'منهم $count مرافقين',
    _ => 'منهم $count مرافقًا',
  };
}

String _invitationCountLabel(int count) {
  return switch (count) {
    0 => 'لا توجد دعوات بعد',
    1 => 'دعوة واحدة',
    2 => 'دعوتان',
    >= 3 && <= 10 => '$count دعوات',
    _ => '$count دعوة',
  };
}

String _sideBreakdown({
  required int groom,
  required int bride,
  required int unknown,
}) {
  final parts = <String>[
    'العريس $groom',
    'العروسة $bride',
    if (unknown > 0) 'غير محدد $unknown',
  ];
  return parts.join(' · ');
}
