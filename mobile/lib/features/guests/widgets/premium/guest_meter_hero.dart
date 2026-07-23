import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../models/guest.dart';

/// ملخص الضيوف بنفس لغة بطل الداشبورد.
///
/// [Guest.seatsCount] يشمل صاحب الدعوة ومرافقيه، لذلك نعرض
/// [GuestSummary.expectedSeatsCount] مباشرة ولا نضيف عدد المرافقين مرة أخرى.
class GuestMeterHero extends StatelessWidget {
  const GuestMeterHero({
    required this.summary,
    this.isLocalPlan = false,
    this.footer,
    super.key,
  });

  final GuestSummary summary;
  final bool isLocalPlan;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isFresh = summary.totalGuests == 0;
    const radius = BorderRadius.all(
      Radius.circular(AarastDesignTokens.radiusXl),
    );

    return Container(
      key: const ValueKey('guests-dashboard-hero'),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AarastDesignTokens.burgundyDark.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                AarastDesignTokens.burgundyLight,
                AarastDesignTokens.burgundy,
                AarastDesignTokens.burgundyDark,
              ],
            ),
            borderRadius: radius,
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                end: -42,
                top: 12,
                child: ExcludeSemantics(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AarastDesignTokens.gold.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: isFresh ? _buildFresh(context) : _buildSummary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = AarastMotion.reduceMotion(context);
    final groomCount = summary.bySideForSuper['groom'] ?? 0;
    final brideCount = summary.bySideForSuper['bride'] ?? 0;
    final unknownCount = summary.bySideForSuper['unknown'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المقاعد المتوقعة',
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 7,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      _CountUp(
                        value: summary.expectedSeatsCount,
                        style: textTheme.displaySmall!.copyWith(
                          color: AarastDesignTokens.goldSoft,
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          height: 0.98,
                        ),
                      ),
                      if (summary.companionsExpectedCount > 0) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            _companionsLabel(summary.companionsExpectedCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _invitationCountLabel(summary.totalGuests),
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PeopleMark(invitationCount: summary.totalGuests),
                if (isLocalPlan) ...[
                  const SizedBox(height: 5),
                  _localBadge(context),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 17),
        _SegmentedBar(
          confirmed: summary.confirmed,
          pending: summary.pending,
          declined: summary.declined,
          reduceMotion: reduceMotion,
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            _ResponseStat(
              label: 'مؤكد',
              value: summary.confirmed,
              color: AarastDesignTokens.success,
            ),
            const _StatDivider(),
            _ResponseStat(
              label: 'بانتظار الرد',
              value: summary.pending,
              color: AarastDesignTokens.gold,
            ),
            const _StatDivider(),
            _ResponseStat(
              label: 'لن يحضر',
              value: summary.declined,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(top: 9),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
            ),
          ),
          child: Row(
            children: [
              Text(
                'توزيع الدعوات',
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _sideBreakdown(
                    groom: groomCount,
                    bride: brideCount,
                    unknown: unknownCount,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (footer != null) ...[const SizedBox(height: 13), footer!],
      ],
    );
  }

  Widget _buildFresh(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AarastDesignTokens.goldSoft,
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(18),
              topEnd: Radius.circular(18),
              bottomStart: Radius.circular(18),
              bottomEnd: Radius.circular(5),
            ),
          ),
          child: const Icon(
            LucideIcons.users,
            color: AarastDesignTokens.gold,
            size: 25,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'قائمة الضيوف',
                    style: textTheme.titleMedium?.copyWith(
                      color: AarastDesignTokens.goldSoft,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isLocalPlan) _localBadge(context),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'أضف أول ضيف، وسنحسب المقاعد المتوقعة من بيانات الدعوات.',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _localBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AarastDesignTokens.goldSoft,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.smartphone,
            size: 11,
            color: AarastDesignTokens.warning,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'تخطيط محلي',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AarastDesignTokens.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleMark extends StatelessWidget {
  const _PeopleMark({required this.invitationCount});

  final int invitationCount;

  @override
  Widget build(BuildContext context) {
    final visibleCount = invitationCount > 3 ? 3 : invitationCount;
    const colors = [
      AarastDesignTokens.burgundy,
      AarastDesignTokens.gold,
      AarastDesignTokens.ink,
    ];

    return Semantics(
      label: _invitationCountLabel(invitationCount),
      child: SizedBox(
        width: 88,
        height: 48,
        child: Stack(
          children: [
            for (var index = 0; index < visibleCount; index++)
              PositionedDirectional(
                start: index * 23,
                child: ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                        width: 4,
                      ),
                    ),
                    child: invitationCount > 3 && index == 2
                        ? Text(
                            '+${invitationCount - 2}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          )
                        : const Icon(
                            LucideIcons.user,
                            size: 15,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.confirmed,
    required this.pending,
    required this.declined,
    required this.reduceMotion,
  });

  final int confirmed;
  final int pending;
  final int declined;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final total = confirmed + pending + declined;
    if (total == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(height: 6, color: AarastDesignTokens.border),
      );
    }

    Widget bar = ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (confirmed > 0)
              Expanded(
                flex: confirmed,
                child: Container(color: AarastDesignTokens.success),
              ),
            if (pending > 0)
              Expanded(
                flex: pending,
                child: Container(color: AarastDesignTokens.gold),
              ),
            if (declined > 0)
              Expanded(
                flex: declined,
                child: Container(
                  color: AarastDesignTokens.muted.withValues(alpha: 0.36),
                ),
              ),
          ],
        ),
      ),
    );

    if (reduceMotion) return bar;
    return bar.animate().scaleX(
      begin: 0,
      end: 1,
      alignment: Alignment.centerRight,
      duration: 900.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class _ResponseStat extends StatelessWidget {
  const _ResponseStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withValues(alpha: 0.16),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (AarastMotion.reduceMotion(context) || value == 0) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutExpo,
      builder: (context, value, _) => Text('${value.round()}', style: style),
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
    'طرف العريس $groom',
    'طرف العروسة $bride',
    if (unknown > 0) 'غير محدد $unknown',
  ];
  return parts.join(' · ');
}
