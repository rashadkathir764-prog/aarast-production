import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../models/dashboard_summary.dart';

/// يحوّل نصًا ماليًا قادمًا من الخادم ("10,000,000") إلى رقم.
double? parseAmount(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String formatAmount(num value) {
  final text = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// الخطوة الذكية — إجابة واحدة دائمًا على سؤال: "ماذا أفعل الآن؟"
// ---------------------------------------------------------------------------

enum SmartActionTone { urgent, attention, celebrate, calm }

class SmartAction {
  const SmartAction({
    required this.title,
    required this.reason,
    required this.icon,
    required this.tone,
    this.item,
  });

  final String title;
  final String reason;
  final IconData icon;
  final SmartActionTone tone;
  final DashboardImportantItem? item;
}

/// يحسب أهم خطوة الآن بأولوية: مال مستحق ← مهام متأخرة ← عروض وصلت ← مهام اليوم.
SmartAction? resolveSmartAction(DashboardSummary summary) {
  final backendItem =
      summary.importantItems.isNotEmpty ? summary.importantItems.first : null;
  if (backendItem != null) {
    return SmartAction(
      title: backendItem.title,
      reason: backendItem.subtitle,
      icon: _iconForType(backendItem.type),
      tone: _toneForPriority(backendItem.priority, backendItem.tone),
      item: backendItem,
    );
  }

  if ((summary.dueInstallmentsCount ?? 0) > 0) {
    return SmartAction(
      title: 'قسط مستحق ينتظرك',
      reason: 'لديك ${summary.dueInstallmentsCount} قسط حان موعده — سدّده قبل ما يتراكم.',
      icon: LucideIcons.calendarClock,
      tone: SmartActionTone.urgent,
    );
  }
  if (summary.overdueTasks > 0) {
    return SmartAction(
      title: 'مهام متأخرة تحتاجك',
      reason: '${summary.overdueTasks} مهمة تجاوزت موعدها — رتبها اليوم يرتاح بالك.',
      icon: LucideIcons.alarmClock,
      tone: SmartActionTone.urgent,
    );
  }
  if (summary.receivedQuotes > 0) {
    return SmartAction(
      title: 'وصلك عرض سعر جديد',
      reason: '${summary.receivedQuotes} عرض بانتظار قرارك — قارن واختر براحتك.',
      icon: LucideIcons.mailOpen,
      tone: SmartActionTone.celebrate,
    );
  }
  if (summary.todayTasks > 0) {
    return SmartAction(
      title: 'مهام اليوم جاهزة',
      reason: '${summary.todayTasks} مهمة مجدولة لليوم — خطوة خطوة نوصل.',
      icon: LucideIcons.listChecks,
      tone: SmartActionTone.attention,
    );
  }
  if (summary.pendingInvites > 0) {
    return SmartAction(
      title: 'دعوة مشاركة معلقة',
      reason: '${summary.pendingInvites} دعوة لم يُرد عليها بعد — تابعها من المشاركة.',
      icon: LucideIcons.userPlus,
      tone: SmartActionTone.attention,
    );
  }
  return null;
}

IconData _iconForType(String type) {
  final upper = type.toUpperCase();
  if (upper.contains('INSTALLMENT') || upper.contains('MONEY') ||
      upper.contains('BUDGET') || upper.contains('EXPENSE')) {
    return LucideIcons.wallet;
  }
  if (upper.contains('TASK')) return LucideIcons.listChecks;
  if (upper.contains('QUOTE') || upper.contains('PROVIDER')) {
    return LucideIcons.store;
  }
  if (upper.contains('GUEST')) return LucideIcons.users;
  if (upper.contains('INVITE') || upper.contains('MEMBER')) {
    return LucideIcons.userPlus;
  }
  return LucideIcons.sparkles;
}

SmartActionTone _toneForPriority(String priority, String tone) {
  final p = priority.toUpperCase();
  final t = tone.toUpperCase();
  if (p.contains('HIGH') || p.contains('URGENT') || t.contains('DANGER')) {
    return SmartActionTone.urgent;
  }
  if (t.contains('SUCCESS') || t.contains('CELEBRAT')) {
    return SmartActionTone.celebrate;
  }
  return SmartActionTone.attention;
}

class AarastNextActionCard extends StatelessWidget {
  const AarastNextActionCard({
    required this.action,
    required this.onTap,
    super.key,
  });

  final SmartAction action;
  final VoidCallback onTap;

  Color get _accent => switch (action.tone) {
        SmartActionTone.urgent => AarastDesignTokens.danger,
        SmartActionTone.attention => AarastDesignTokens.gold,
        SmartActionTone.celebrate => AarastDesignTokens.success,
        SmartActionTone.calm => AarastDesignTokens.info,
      };

  Color get _accentSoft => switch (action.tone) {
        SmartActionTone.urgent => AarastDesignTokens.dangerSoft,
        SmartActionTone.attention => AarastDesignTokens.goldSoft,
        SmartActionTone.celebrate => AarastDesignTokens.successSoft,
        SmartActionTone.calm => AarastDesignTokens.infoSoft,
      };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);

    Widget iconBadge = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
      child: Icon(action.icon, color: _accent, size: 22),
    );

    if (!reduceMotion && action.tone == SmartActionTone.urgent) {
      iconBadge = iconBadge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.07, 1.07),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(color: AarastDesignTokens.border),
            boxShadow: [
              BoxShadow(
                color: AarastDesignTokens.ink.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            child: Stack(
              children: [
                // العمود اللوني — الأولوية تُقرأ قبل أي كلمة.
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: _accent),
                ),
                Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 12, 14),
                    child: Row(
                      children: [
                        iconBadge,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'الخطوة الذكية',
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                action.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AarastDesignTokens.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                action.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AarastDesignTokens.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.chevronLeft,
                          size: 20,
                          color: AarastDesignTokens.muted.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// رحلة الإعداد — بديل الأصفار للمستخدم الجديد: ٣ خطوات تُبنى أمامه.
// ---------------------------------------------------------------------------

class SetupStep {
  const SetupStep({
    required this.label,
    required this.hint,
    required this.icon,
    required this.done,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool done;
  final VoidCallback onTap;
}

class AarastSetupJourneyCard extends StatelessWidget {
  const AarastSetupJourneyCard({required this.steps, super.key});

  final List<SetupStep> steps;

  @override
  Widget build(BuildContext context) {
    final doneCount = steps.where((s) => s.done).length;
    final reduceMotion = AarastMotion.reduceMotion(context);

    return Container(
      decoration: BoxDecoration(
        color: AarastDesignTokens.surface,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        border: Border.all(color: AarastDesignTokens.gold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AarastDesignTokens.gold.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles,
                  color: AarastDesignTokens.gold, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'لنجهّز خطتك في ٣ خطوات',
                  style: TextStyle(
                    color: AarastDesignTokens.title,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$doneCount/${steps.length}',
                style: const TextStyle(
                  color: AarastDesignTokens.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'كل خطوة تفتح لك صورة أوضح ليومك الكبير.',
            style: TextStyle(
              color: AarastDesignTokens.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            _SetupStepRow(
              step: steps[i],
              index: i,
              isLast: i == steps.length - 1,
              reduceMotion: reduceMotion,
            ),
        ],
      ),
    );
  }
}

class _SetupStepRow extends StatelessWidget {
  const _SetupStepRow({
    required this.step,
    required this.index,
    required this.isLast,
    required this.reduceMotion,
  });

  final SetupStep step;
  final int index;
  final bool isLast;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    Widget marker = step.done
        ? Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AarastDesignTokens.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 18),
          )
        : Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AarastDesignTokens.goldSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AarastDesignTokens.gold.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(step.icon, color: AarastDesignTokens.gold, size: 15),
          );

    if (step.done && !reduceMotion) {
      marker = marker
          .animate()
          .scale(
            begin: const Offset(0.4, 0.4),
            end: const Offset(1, 1),
            duration: 450.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 200.ms);
    }

    return InkWell(
      onTap: step.done ? null : step.onTap,
      borderRadius: BorderRadius.circular(AarastDesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Column(
              children: [
                marker,
                if (!isLast)
                  Container(
                    width: 2,
                    height: 18,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.done
                        ? AarastDesignTokens.success.withValues(alpha: 0.4)
                        : AarastDesignTokens.border,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 8 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: TextStyle(
                        color: step.done
                            ? AarastDesignTokens.muted
                            : AarastDesignTokens.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        decoration:
                            step.done ? TextDecoration.lineThrough : null,
                        decorationColor: AarastDesignTokens.muted,
                      ),
                    ),
                    if (!step.done) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.hint,
                        style: const TextStyle(
                          color: AarastDesignTokens.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!step.done)
              const Padding(
                padding: EdgeInsetsDirectional.only(bottom: 12),
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: 18,
                  color: AarastDesignTokens.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// نبض الخطة — ثلاث نوافذ حية بعرض كامل، بلا قصّ وبلا أصفار ميتة.
// ---------------------------------------------------------------------------

class PulseTileData {
  const PulseTileData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;
}

class AarastPulseRow extends StatelessWidget {
  const AarastPulseRow({required this.tiles, super.key});

  final List<PulseTileData> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _PulseTile(data: tiles[i])),
        ],
      ],
    );
  }
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({required this.data});

  final PulseTileData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusMd),
            border: Border.all(color: AarastDesignTokens.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, size: 15, color: AarastDesignTokens.gold),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AarastDesignTokens.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AarastDesignTokens.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AarastDesignTokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// لمحة المال — بطاقة واحدة هادئة: ٣ أرقام وشريط حي، أو دعوة لتحديد الميزانية.
// ---------------------------------------------------------------------------

class AarastMoneyGlanceCard extends StatelessWidget {
  const AarastMoneyGlanceCard({
    required this.summary,
    required this.onOpenMoney,
    required this.onAddExpense,
    super.key,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final total = parseAmount(summary.totalBudgetForDisplay);
    final spent = parseAmount(summary.spentTotalForDisplay) ?? 0;
    final hasBudget = total != null && total > 0;
    final usedRatio = hasBudget ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final nearLimit = usedRatio >= 0.85;
    final reduceMotion = AarastMotion.reduceMotion(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenMoney,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AarastDesignTokens.goldSoft,
                      borderRadius:
                          BorderRadius.circular(AarastDesignTokens.radiusSm),
                    ),
                    child: const Icon(LucideIcons.wallet,
                        color: AarastDesignTokens.gold, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'الميزانية',
                      style: TextStyle(
                        color: AarastDesignTokens.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onAddExpense,
                    tooltip: 'إضافة مصروف',
                    icon: const Icon(Icons.add_circle_rounded,
                        color: AarastDesignTokens.burgundy, size: 26),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AarastDesignTokens.minTapTarget,
                      minHeight: AarastDesignTokens.minTapTarget,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasBudget)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AarastDesignTokens.goldSoft.withValues(alpha: 0.6),
                    borderRadius:
                        BorderRadius.circular(AarastDesignTokens.radiusSm),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.flag,
                          size: 16, color: AarastDesignTokens.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'حدد ميزانيتك العامة حتى نتابع معك كل ريال بهدوء.',
                          style: TextStyle(
                            color: AarastDesignTokens.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    _MoneyFigure(
                      label: 'المخصص',
                      value: formatAmount(total),
                      color: AarastDesignTokens.ink,
                    ),
                    _MoneyFigure(
                      label: 'المصروف',
                      value: formatAmount(spent),
                      color: AarastDesignTokens.burgundy,
                    ),
                    _MoneyFigure(
                      label: 'المتبقي',
                      value: formatAmount((total - spent).clamp(0, total)),
                      color: AarastDesignTokens.success,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: usedRatio),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: AarastDesignTokens.border
                          .withValues(alpha: 0.6),
                      valueColor: AlwaysStoppedAnimation(
                        nearLimit
                            ? AarastDesignTokens.warning
                            : AarastDesignTokens.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nearLimit
                      ? 'اقتربت من حد الميزانية — راجع البنود قبل أي دفعة جديدة.'
                      : 'مستخدم ${(usedRatio * 100).round()}% من الميزانية',
                  style: TextStyle(
                    color: nearLimit
                        ? AarastDesignTokens.warning
                        : AarastDesignTokens.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyFigure extends StatelessWidget {
  const _MoneyFigure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AarastDesignTokens.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
                children: const [
                  TextSpan(
                    text: ' ر.ي',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
