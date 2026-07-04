import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/widgets/aarast_progress_ring.dart';
import '../../../finance/widgets/yemeni_money_text.dart';
import '../../models/debt_summary.dart';

double _money(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

/// نبض الباقي — بطل شاشة الديون والدفعات.
///
/// يجيب على السؤال الأول للمستخدم: «كم باقي عليّ ومتى أقرب دفعة؟».
/// الحلقة تعرض نسبة المسدَّد، والرقم البطل هو المتبقي، والتلميح السفلي
/// ينبّه على التأخير أو يذكّر بأقرب موعد.
class DebtPulseHero extends StatelessWidget {
  const DebtPulseHero({
    required this.summary,
    this.nextDueDate,
    this.hasOverdue = false,
    super.key,
  });

  final DebtSummary summary;
  final DateTime? nextDueDate;
  final bool hasOverdue;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    final total = _money(summary.totalDebt);
    final paid = _money(summary.totalPaid);
    final remaining = _money(summary.remainingDebt);
    final settled = remaining <= 0 && total > 0;
    final ratio = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final percentage = (ratio * 100).round();

    final ringColors = hasOverdue
        ? const [
            AarastDesignTokens.danger,
            AarastDesignTokens.dangerLight,
            AarastDesignTokens.dangerSoft,
          ]
        : settled
            ? const [
                AarastDesignTokens.success,
                AarastDesignTokens.gold,
                AarastDesignTokens.goldLight,
              ]
            : const [
                AarastDesignTokens.goldDeep,
                AarastDesignTokens.gold,
                AarastDesignTokens.goldLight,
              ];

    final (hintIcon, hintText, hintDanger) = _hint(remaining, settled);

    Widget card = Container(
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
                    AarastDesignTokens.gold.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settled ? 'كل شي مسدَّد' : 'المتبقي عليك',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: YemeniMoneyText(
                              settled ? 0 : remaining,
                              color: hasOverdue
                                  ? AarastDesignTokens.dangerSoft
                                  : AarastDesignTokens.goldSoft,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                fontFamily: 'IBMPlexSansArabic',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _HeroMoneyRow(label: 'الإجمالي', value: total),
                          const SizedBox(height: 6),
                          _HeroMoneyRow(label: 'المدفوع', value: paid),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Semantics(
                      label: 'تم سداد $percentage بالمئة من المبالغ',
                      child: AarastProgressRing(
                        progress: ratio,
                        size: 112,
                        gradientColors: ringColors,
                        tipColor: AarastDesignTokens.goldGlow,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentage%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'مسدَّد',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: hintDanger
                        ? AarastDesignTokens.danger.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(AarastDesignTokens.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hintIcon,
                        size: 15,
                        color: hintDanger
                            ? AarastDesignTokens.dangerSoft
                            : AarastDesignTokens.goldSoft,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hintText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) return card;

    return card.animate().shimmer(
          delay: 650.ms,
          duration: 1200.ms,
          color: AarastDesignTokens.gold.withValues(alpha: 0.30),
          angle: math.pi / 8,
        );
  }

  (IconData, String, bool) _hint(double remaining, bool settled) {
    if (hasOverdue) {
      return (
        LucideIcons.alertTriangle,
        'لديك دفعة متأخرة — سددها لتفادي تراكم الباقي.',
        true,
      );
    }
    if (settled || remaining <= 0) {
      return (
        LucideIcons.shieldCheck,
        'سددت كل شي — ما عليك باقي. مبروك!',
        false,
      );
    }
    if (nextDueDate != null) {
      return (
        LucideIcons.calendarClock,
        'أقرب دفعة: ${formatArabicCompactDate(nextDueDate!)}',
        false,
      );
    }
    return (
      LucideIcons.wallet,
      'سجّل كل دفعة أول بأول ليبقى الباقي واضحاً أمامك.',
      false,
    );
  }
}

class _HeroMoneyRow extends StatelessWidget {
  const _HeroMoneyRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AarastDesignTokens.gold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: YemeniMoneyText(
            value,
            color: Colors.white,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
