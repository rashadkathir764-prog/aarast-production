import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/widgets/aarast_progress_ring.dart';

/// نص رقمي يتصاعد من الصفر حتى قيمته — نبضة حياة للأرقام المهمة.
class AarastCountUpText extends StatelessWidget {
  const AarastCountUpText({
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 1400),
    this.curve = Curves.easeOutExpo,
    super.key,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    if (AarastMotion.reduceMotion(context) || value == 0) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animated, _) =>
          Text('${animated.round()}', style: style),
    );
  }
}

/// البطاقة الملكية: عدّاد الأيام + حلقة تقدم ذهبية تُرسم أمام العين.
///
/// حلقة واحدة تحمل رسالتين: القوس الذهبي = كم أنجزت،
/// والرقم في المركز = كم بقي من الوقت.
class AarastCountdownHero extends StatelessWidget {
  const AarastCountdownHero({
    required this.planTitle,
    required this.progressPercentage,
    this.kicker,
    this.weddingDate,
    this.city,
    this.daysRemaining,
    this.onTap,
    super.key,
  });

  final String planTitle;
  final int progressPercentage;
  final String? kicker;
  final DateTime? weddingDate;
  final String? city;
  final int? daysRemaining;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    final clampedProgress = progressPercentage.clamp(0, 100) / 100;

    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusXl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusXl),
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                AarastDesignTokens.burgundyLight,
                AarastDesignTokens.burgundy,
                AarastDesignTokens.burgundyDark,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AarastDesignTokens.burgundyDark.withValues(alpha: 0.32),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              // هالة ذهبية خافتة تمنح البطاقة عمقًا ملكيًا.
              PositionedDirectional(
                top: -46,
                start: -30,
                child: Container(
                  width: 170,
                  height: 170,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kicker ?? 'جاهز نرتب عرسك؟',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            planTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AarastDesignTokens.goldSoft,
                                  height: 1.25,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (weddingDate != null)
                            _HeroDetailRow(
                              icon: LucideIcons.calendarHeart,
                              label: formatArabicDate(weddingDate!),
                            ),
                          if (city != null && city!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _HeroDetailRow(
                              icon: LucideIcons.mapPin,
                              label: city!.trim(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _CountdownRing(
                      progress: clampedProgress.toDouble(),
                      daysRemaining: daysRemaining,
                      progressPercentage: progressPercentage.clamp(0, 100),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reduceMotion) return card;

    // لمعة ذهبية تعبر البطاقة مرة واحدة عند الدخول — لحظة "الافتتاح".
    return card
        .animate()
        .shimmer(
          delay: 650.ms,
          duration: 1200.ms,
          color: AarastDesignTokens.gold.withValues(alpha: 0.35),
          angle: math.pi / 8,
        );
  }
}

class _HeroDetailRow extends StatelessWidget {
  const _HeroDetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AarastDesignTokens.gold),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.progress,
    required this.daysRemaining,
    required this.progressPercentage,
  });

  final double progress;
  final int? daysRemaining;
  final int progressPercentage;

  @override
  Widget build(BuildContext context) {
    final ring = AarastProgressRing(
      progress: progress,
      size: 118,
      child: _buildCenter(context),
    );

    return Semantics(
      label: daysRemaining != null && daysRemaining! > 0
          ? 'متبقي $daysRemaining يوم، اكتمال التخطيط $progressPercentage بالمئة'
          : 'اكتمال التخطيط $progressPercentage بالمئة',
      child: ring,
    );
  }

  Widget _buildCenter(BuildContext context) {
    final days = daysRemaining;

    if (days == null) {
      // لا يوجد تاريخ زفاف بعد — الحلقة تحكي التقدم فقط.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AarastCountUpText(
            value: progressPercentage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '% اكتمال',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    if (days <= 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.partyPopper,
              color: AarastDesignTokens.gold, size: 26),
          const SizedBox(height: 4),
          Text(
            'اليوم الكبير',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AarastCountUpText(
          value: days,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'يوم متبقي',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AarastDesignTokens.gold.withValues(alpha: 0.18),
            borderRadius:
                BorderRadius.circular(AarastDesignTokens.radiusPill),
          ),
          child: Text(
            '$progressPercentage% إنجاز',
            style: const TextStyle(
              color: AarastDesignTokens.goldSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

