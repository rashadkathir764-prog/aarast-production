import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../../../core/widgets/aarast_progress_ring.dart';
import '../../models/money_formatters.dart';
import '../../models/money_summary.dart';

double _money(String? raw) {
  if (raw == null) return 0;
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

/// نبض الميزانية — بطل تبويب المال.
///
/// الحلقة تتلون حسب الخطر: ذهبية وأنت آمن، كهرمانية قرب الحد،
/// حمراء عند التجاوز. الرقم الأهم (المتبقي) هو الأكبر في البطاقة.
class BudgetPulseHero extends StatelessWidget {
  const BudgetPulseHero({
    required this.summary,
    this.onSetupBudget,
    super.key,
  });

  final MoneySummary summary;

  /// يظهر زر تحديد الميزانية عندما لا توجد ميزانية (لمن يملك الصلاحية فقط).
  final VoidCallback? onSetupBudget;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    final total = _money(summary.totalBudget);
    final spent = _money(summary.totalSpent);
    final hasBudget = summary.hasUsableBudget;
    final ratio = summary.spendingRatio;
    final status = summary.budgetStatus;

    final isOver = status == 'OVER_BUDGET';
    final isWarning = status == 'WARNING' || status == 'DANGER';

    final ringColors = isOver
        ? const [
            AarastDesignTokens.danger,
            AarastDesignTokens.dangerLight,
            AarastDesignTokens.dangerSoft,
          ]
        : isWarning
            ? const [
                AarastDesignTokens.warning,
                AarastDesignTokens.warningLight,
                AarastDesignTokens.warningSoft,
              ]
            : const [
                AarastDesignTokens.goldDeep,
                AarastDesignTokens.gold,
                AarastDesignTokens.goldLight,
              ];

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
            child: hasBudget
                ? _buildBudgetBody(context, total, spent, ratio, ringColors)
                : _buildNoBudgetBody(context, spent),
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

  Widget _buildBudgetBody(
    BuildContext context,
    double total,
    double spent,
    double ratio,
    List<Color> ringColors,
  ) {
    final remaining = total - spent;
    final percentage = (ratio * 100).round();
    final status = summary.budgetStatus;

    final hint = switch (status) {
      'OVER_BUDGET' =>
        'تجاوزت الميزانية — راجع البنود وقرر وش يتأجل ووش يستمر.',
      'DANGER' || 'WARNING' =>
        'اقتربت من الحد — تابع البنود قبل إضافة دفعة جديدة.',
      _ => 'وضعك المالي مريح — سجّل كل دفعة أولًا بأول ليبقى كذلك.',
    };
    final hintIcon = switch (status) {
      'OVER_BUDGET' => LucideIcons.alertTriangle,
      'DANGER' || 'WARNING' => LucideIcons.eye,
      _ => LucideIcons.shieldCheck,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المتبقي معك',
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
                    child: YemeniMoneyHeroText(
                      value: remaining,
                      color: remaining < 0
                          ? AarastDesignTokens.dangerSoft
                          : AarastDesignTokens.goldSoft,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HeroMoneyRow(label: 'الميزانية', value: total),
                  const SizedBox(height: 6),
                  _HeroMoneyRow(label: 'المصروف', value: spent),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Semantics(
              label: 'تم صرف $percentage بالمئة من الميزانية',
              child: AarastProgressRing(
                progress: ratio.clamp(0.0, 1.0),
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
                      'تم صرفه',
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusSm),
          ),
          child: Row(
            children: [
              Icon(hintIcon, size: 15, color: AarastDesignTokens.goldSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
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
    );
  }

  Widget _buildNoBudgetBody(BuildContext context, double spent) {
    final hasLooseSpending = summary.hasSpendingWithoutBudget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ميزانية العرس',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLooseSpending
                        ? 'مصاريفك تمشي بلا سقف'
                        : 'لنحدد سقفك المالي',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          color: AarastDesignTokens.goldSoft,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasLooseSpending
                        ? 'سجلت ${formatCompactYemeniMoney(spent)} بدون ميزانية عامة — حدد السقف حتى نحسب لك المتبقي.'
                        : 'رقم تقريبي يكفي للبداية، ويمكن تعديله في أي وقت.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AarastProgressRing(
              progress: hasLooseSpending ? 1 : 0,
              size: 104,
              gradientColors: hasLooseSpending
                  ? const [
                      AarastDesignTokens.danger,
                      AarastDesignTokens.dangerLight,
                      AarastDesignTokens.dangerSoft,
                    ]
                  : const [
                      AarastDesignTokens.goldDeep,
                      AarastDesignTokens.gold,
                      AarastDesignTokens.goldLight,
                    ],
              child: Icon(
                hasLooseSpending
                    ? LucideIcons.alertTriangle
                    : LucideIcons.target,
                color: Colors.white.withValues(alpha: 0.9),
                size: 30,
              ),
            ),
          ],
        ),
        if (onSetupBudget != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSetupBudget,
              style: FilledButton.styleFrom(
                backgroundColor: AarastDesignTokens.gold,
                foregroundColor: AarastDesignTokens.burgundyDark,
                minimumSize:
                    const Size.fromHeight(AarastDesignTokens.minTapTarget),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AarastDesignTokens.radiusMd),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Tajawal',
                ),
              ),
              icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
              label: const Text('إعداد الميزانية'),
            ),
          ),
        ],
      ],
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
          child: Text(
            formatCompactYemeniMoney(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// الرقم البطل — يتصاعد من الصفر بعملة مثبتة الاتجاه.
class YemeniMoneyHeroText extends StatelessWidget {
  const YemeniMoneyHeroText({
    required this.value,
    required this.color,
    super.key,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 1400),
      curve: Curves.easeOutExpo,
      builder: (context, animated, _) {
        return Text(
          formatCompactYemeniMoney(animated),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.1,
            fontFamily: 'IBMPlexSansArabic',
          ),
        );
      },
    );
  }
}
