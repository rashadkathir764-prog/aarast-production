import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../models/money_formatters.dart';
import '../../models/money_summary.dart';

double _money(String? raw) {
  if (raw == null) return 0;
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

/// سكة الدفعات — خط زمني عمودي هادئ بدل صناديق الجداول:
/// المتأخرات أولًا (تنبض)، ثم القسط القادم (يتوهج)، ثم إجمالي الباقي عليك.
class PaymentTimelineRail extends StatelessWidget {
  const PaymentTimelineRail({
    required this.summary,
    required this.onViewDebts,
    this.onAddDebt,
    this.now,
    super.key,
  });

  final MoneySummary summary;
  final VoidCallback onViewDebts;

  /// يظهر زر تسجيل "باقي عليك" في الحالة الفارغة لمن يملك الصلاحية.
  final VoidCallback? onAddDebt;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final overdue =
        (summary.overdueInstallmentsCount ?? 0) +
        (summary.financialOverdueInstallmentsCount ?? 0);
    final next = summary.nextFinancialInstallment ?? summary.nextInstallment;
    final debtRemaining = _money(summary.outstandingTotal) > 0
        ? _money(summary.outstandingTotal)
        : _money(summary.debtRemaining);
    final debtsCount =
        (summary.debtsCount ?? 0) + (summary.commitmentsCount ?? 0);
    final reduceMotion = AarastMotion.reduceMotion(context);

    final nodes = <Widget>[];

    if (overdue > 0) {
      nodes.add(
        _RailNode(
          dot: _PulsingDot(
            color: AarastDesignTokens.danger,
            reduceMotion: reduceMotion,
          ),
          title: overdue == 1 ? 'قسط متأخر' : '$overdue أقساط متأخرة',
          subtitle: 'عالجها أولًا حتى لا تتراكم عليك.',
          titleColor: AarastDesignTokens.danger,
          onTap: onViewDebts,
        ),
      );
    }

    if (next != null) {
      final dueAt = next.dueAt;
      final who = (next.creditorName ?? next.debtTitle ?? '').trim();
      nodes.add(
        _RailNode(
          dot: const _GlowDot(color: AarastDesignTokens.gold),
          title: 'القسط القادم${who.isEmpty ? '' : ' — $who'}',
          subtitle: dueAt == null
              ? 'بدون موعد محدد'
              : '${formatArabicCompactDate(dueAt)} · ${_relativeDue(dueAt, now)}',
          trailing: _AmountText(value: _money(next.amount)),
          onTap: onViewDebts,
        ),
      );
    }

    if (debtRemaining > 0 || debtsCount > 0) {
      nodes.add(
        _RailNode(
          dot: const _SolidDot(color: AarastDesignTokens.ink),
          title: 'إجمالي الباقي عليك',
          subtitle: debtsCount == 0
              ? 'كل المبالغ المسجلة'
              : '$debtsCount ${debtsCount == 1 ? 'مبلغ مسجل' : 'مبالغ مسجلة'}',
          trailing: _AmountText(
            value: debtRemaining,
            color: AarastDesignTokens.danger,
          ),
          onTap: onViewDebts,
        ),
      );
    }

    return Container(
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AarastDesignTokens.burgundySoft,
                  borderRadius: BorderRadius.circular(
                    AarastDesignTokens.radiusSm,
                  ),
                ),
                child: const Icon(
                  LucideIcons.calendarClock,
                  color: AarastDesignTokens.burgundy,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'سجل الديون القديم',
                  style: TextStyle(
                    color: AarastDesignTokens.title,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewDebts,
                style: TextButton.styleFrom(
                  foregroundColor: AarastDesignTokens.burgundy,
                  minimumSize: const Size(48, 40),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Tajawal',
                  ),
                ),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (nodes.isEmpty)
            _EmptyRail(onAddDebt: onAddDebt)
          else
            Column(
              children: [
                for (var i = 0; i < nodes.length; i++)
                  _withConnector(
                    nodes[i],
                    isLast: i == nodes.length - 1,
                    index: i,
                    reduceMotion: reduceMotion,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _withConnector(
    Widget node, {
    required bool isLast,
    required int index,
    required bool reduceMotion,
  }) {
    final wrapped = _ConnectedNode(node: node, isLast: isLast);
    if (reduceMotion) return wrapped;
    return wrapped
        .animate()
        .fadeIn(delay: (120 * index).ms, duration: 380.ms)
        .slideY(
          begin: 0.10,
          end: 0,
          delay: (120 * index).ms,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }

  static String _relativeDue(DateTime dueAt, DateTime? referenceDate) {
    final today = referenceDate ?? DateTime.now();
    final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final now = DateTime(today.year, today.month, today.day);
    final days = due.difference(now).inDays;
    if (days < 0) return 'متأخر ${-days} ${-days == 1 ? 'يوم' : 'يوم'}';
    if (days == 0) return 'اليوم';
    if (days == 1) return 'غدًا';
    return 'بعد $days يوم';
  }
}

class _ConnectedNode extends StatelessWidget {
  const _ConnectedNode({required this.node, required this.isLast});

  final Widget node;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                const SizedBox(height: 14),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Center(child: (node as _RailNode).dot),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AarastDesignTokens.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: node),
        ],
      ),
    );
  }
}

class _RailNode extends StatelessWidget {
  const _RailNode({
    required this.dot,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.titleColor,
    this.onTap,
  });

  final Widget dot;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AarastDesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor ?? AarastDesignTokens.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AarastDesignTokens.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText({required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatCompactYemeniMoney(value),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        color: color ?? AarastDesignTokens.ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        fontFamily: 'IBMPlexSansArabic',
      ),
    );
  }
}

class _EmptyRail extends StatelessWidget {
  const _EmptyRail({this.onAddDebt});

  final VoidCallback? onAddDebt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      child: Row(
        children: [
          const Icon(
            LucideIcons.badgeCheck,
            color: AarastDesignTokens.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'لا يوجد باقي عليك حاليًا — وضعك سليم.',
              style: TextStyle(
                color: AarastDesignTokens.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          if (onAddDebt != null)
            TextButton.icon(
              onPressed: onAddDebt,
              style: TextButton.styleFrom(
                foregroundColor: AarastDesignTokens.burgundy,
                minimumSize: const Size(48, 40),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Tajawal',
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('سجّل باقي'),
            ),
        ],
      ),
    );
  }
}

// --- Dots -------------------------------------------------------------------

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.color, required this.reduceMotion});

  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
        ],
      ),
    );
    if (reduceMotion) return dot;
    return dot
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.25, 1.25),
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _GlowDot extends StatelessWidget {
  const _GlowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AarastDesignTokens.goldGlow, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 7),
        ],
      ),
    );
  }
}

class _SolidDot extends StatelessWidget {
  const _SolidDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        shape: BoxShape.circle,
      ),
    );
  }
}
