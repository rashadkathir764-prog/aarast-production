import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../models/guest.dart';

/// عدّاد الضيوف — بطل تبويب الضيوف.
///
/// بدل "اكتمال البيانات 0%" المجرّد، نعرض الرقم الذي يهم اليمني فعلًا:
/// **الحضور المتوقع** — عليه تُقاس تكلفة العرس. تحته شريط مقسّم
/// (مؤكد/بانتظار/معتذر) وتقسيم الطرفين، و`footer` فتحة تضع فيها
/// الشاشة شرائح الفلترة الحية — نفس عقد بطل المهام.
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
    final total = summary.totalGuests;
    final isFresh = total == 0;
    final expectedAttendance =
        summary.expectedSeatsCount + summary.companionsExpectedCount;
    final reduceMotion = AarastMotion.reduceMotion(context);

    final groomCount = summary.bySideForSuper['groom'] ?? 0;
    final brideCount = summary.bySideForSuper['bride'] ?? 0;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AarastDesignTokens.surface,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusXl),
        border: Border.all(color: AarastDesignTokens.border),
        boxShadow: [
          BoxShadow(
            color: AarastDesignTokens.ink.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: isFresh
          ? _buildFresh(context)
          : Column(
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
                            'الحضور المتوقع',
                            style: textTheme.labelMedium?.copyWith(
                              color: AarastDesignTokens.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              _CountUp(
                                value: expectedAttendance,
                                style: textTheme.displaySmall!.copyWith(
                                  color: AarastDesignTokens.title,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'شخص',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: AarastDesignTokens.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$total ${total == 1 ? 'دعوة' : 'دعوة'}'
                            '${summary.companionsExpectedCount > 0 ? ' + ${summary.companionsExpectedCount} مرافق' : ''}',
                            style: textTheme.labelSmall?.copyWith(
                              color: AarastDesignTokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLocalPlan) _localBadge(context),
                  ],
                ),
                const SizedBox(height: 16),
                _SegmentedBar(
                  confirmed: summary.confirmed,
                  pending: summary.pending,
                  declined: summary.declined,
                  reduceMotion: reduceMotion,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Legend(
                      color: AarastDesignTokens.success,
                      label: 'مؤكد',
                      value: summary.confirmed,
                    ),
                    _Legend(
                      color: AarastDesignTokens.gold,
                      label: 'بانتظار',
                      value: summary.pending,
                    ),
                    _Legend(
                      color: AarastDesignTokens.muted,
                      label: 'معتذر',
                      value: summary.declined,
                    ),
                  ],
                ),
                if (groomCount > 0 || brideCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AarastDesignTokens.ivory,
                      borderRadius: BorderRadius.circular(
                        AarastDesignTokens.radiusMd,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SideChip(
                            icon: LucideIcons.user,
                            label: 'طرف العريس',
                            value: groomCount,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: AarastDesignTokens.border,
                        ),
                        Expanded(
                          child: _SideChip(
                            icon: LucideIcons.user,
                            label: 'طرف العروسة',
                            value: brideCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 14), footer!],
              ],
            ),
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
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
          ),
          child: const Icon(
            LucideIcons.users,
            color: AarastDesignTokens.gold,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'قائمة الضيوف',
                      style: textTheme.titleMedium?.copyWith(
                        color: AarastDesignTokens.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isLocalPlan) _localBadge(context),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'أضف أول ضيف، وسنحسب لك الحضور المتوقع لتقدّر التكلفة بدقة.',
                style: textTheme.bodySmall?.copyWith(
                  color: AarastDesignTokens.muted,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
          Text(
            'تخطيط محلي',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AarastDesignTokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        child: Container(height: 10, color: AarastDesignTokens.border),
      );
    }

    Widget bar = ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
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
                  color: AarastDesignTokens.muted.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );

    if (reduceMotion) return bar;
    // RTL: يبدأ الشريط من جهة البداية (اليمين).
    return bar.animate().scaleX(
      begin: 0,
      end: 1,
      alignment: Alignment.centerRight,
      duration: 900.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AarastDesignTokens.ink,
            ),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AarastDesignTokens.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideChip extends StatelessWidget {
  const _SideChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: AarastDesignTokens.burgundy),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AarastDesignTokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AarastDesignTokens.ink,
          ),
        ),
      ],
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
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
