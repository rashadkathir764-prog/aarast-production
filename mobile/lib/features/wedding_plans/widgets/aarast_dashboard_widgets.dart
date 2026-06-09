import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

// ============================================================================
// Aarast Dashboard — faithful Flutter recreation of the Claude Design handoff
// (RTL, maroon/gold/cream palette, completion donut, budget donut, quick
// actions, alerts, participants, shared plans, custom bottom nav).
// ============================================================================

const _arMonths = <String>[
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

String dashFormatArDate(DateTime date) {
  return '${date.day} ${_arMonths[date.month - 1]} ${date.year}';
}

double dashParseAmount(String? raw) {
  if (raw == null) return 0;
  return double.tryParse(raw.replaceAll(',', '').trim()) ?? 0;
}

String dashFormatMoney(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

/// LTR-rendered numeric/currency text so digits + currency keep their order
/// inside the surrounding RTL layout (mirrors the `.num` rule in the design).
class _Num extends StatelessWidget {
  const _Num(this.text, {this.style, this.align = TextAlign.right});

  final String text;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textDirection: TextDirection.ltr,
      textAlign: align,
      style: style,
    );
  }
}

// ============================================================================
// TOP BAR
// ============================================================================

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    required this.userName,
    this.onProfile,
    this.onNotifications,
    this.hasNotificationDot = true,
    super.key,
  });

  final String userName;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final bool hasNotificationDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting (start / right in RTL)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً ${userName.split(' ').first} 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.dMaroon,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'هذه لمحة سريعة عن تجهيزات زفافك',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Action icons (end / left in RTL)
              _IconButton(
                icon: Icons.notifications_none_rounded,
                onTap: onNotifications,
                showDot: hasNotificationDot,
              ),
              const SizedBox(width: 10),
              _IconButton(icon: Icons.person_outline_rounded, onTap: onProfile),
            ],
          ),
          // Centered Brand Mark
          const Positioned(
            child: _BrandMark(),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'اعرست',
          style: isTest
              ? const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dMaroon,
                  letterSpacing: 1,
                  height: 1,
                )
              : GoogleFonts.amiri(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dMaroon,
                  letterSpacing: 1,
                  height: 1,
                ),
        ),
        const SizedBox(height: 2),
        CustomPaint(size: const Size(46, 30), painter: _RingsPainter()),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap, this.showDot = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.dMaroonDeep.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: AppTheme.dInkSoft),
            if (showDot)
              Positioned(
                top: 12,
                left: 13,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.dMaroon,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.dCard, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The interlocking wedding rings + star from the brand logo.
class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // design coordinates are based on a 58x42 viewbox
    final scale = size.width / 58;
    canvas.save();
    canvas.scale(scale);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    stroke.color = AppTheme.dGold;
    canvas.drawCircle(const Offset(22, 22), 13, stroke);
    stroke.color = AppTheme.dMaroon;
    canvas.drawCircle(const Offset(37, 20), 12, stroke);

    // small sparkle/star in gold
    final star = Paint()..color = AppTheme.dGold;
    canvas.drawPath(_starPath(const Offset(37, 9), 4.5), star);
    canvas.restore();
  }

  Path _starPath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outer = i * 2 * math.pi / 5 - math.pi / 2;
      final inner = outer + math.pi / 5;
      final ox = c.dx + r * math.cos(outer);
      final oy = c.dy + r * math.sin(outer);
      final ix = c.dx + (r * 0.45) * math.cos(inner);
      final iy = c.dy + (r * 0.45) * math.sin(inner);
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// HERO CARD (completion donut + plan meta + countdown)
// ============================================================================

class DashboardHeroCard extends StatefulWidget {
  const DashboardHeroCard({
    required this.title,
    required this.statusLabel,
    required this.tasksDone,
    required this.tasksTotal,
    this.city,
    this.weddingDate,
    super.key,
  });

  final String title;
  final String statusLabel;
  final int tasksDone;
  final int tasksTotal;
  final String? city;
  final DateTime? weddingDate;

  @override
  State<DashboardHeroCard> createState() => _DashboardHeroCardState();
}

class _DashboardHeroCardState extends State<DashboardHeroCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.weddingDate != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? get _countdownText {
    final date = widget.weddingDate;
    if (date == null) return null;
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return 'تم الزفاف';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    return '$days يوم، $hours ساعات، $minutes دقيقة المتبقية';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.tasksTotal > 0
        ? widget.tasksDone / widget.tasksTotal
        : 0.0;
    final pct = (progress * 100).round();
    final completionText = '$pct% مكتمل';
    final subText = '${widget.tasksDone} من ${widget.tasksTotal} مهام مكتملة';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [
            AppTheme.dMaroonBright,
            AppTheme.dMaroon,
            AppTheme.dMaroon2,
          ],
          stops: [0, 0.45, 1],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeroPatternPainter()),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // text column (start / right)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.city != null)
                      _metaRow(icon: Icons.place_outlined, value: widget.city!),
                    if (widget.weddingDate != null)
                      _metaRow(
                        icon: Icons.calendar_today_outlined,
                        value: dashFormatArDate(widget.weddingDate!),
                        label: 'تاريخ الزفاف',
                      ),
                    if (_countdownText != null)
                      _metaRow(
                        icon: Icons.hourglass_bottom_rounded,
                        value: _countdownText!,
                      ),
                    const SizedBox(height: 4),
                    _statusLine(),
                    const SizedBox(height: 10),
                    _progressBar(progress),
                    const SizedBox(height: 10),
                    Text(
                      completionText,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // completion donut (end / left)
              Column(
                children: [
                  SizedBox(
                    width: 116,
                    height: 116,
                    child: CustomPaint(
                      painter: _ProgressDonutPainter(progress: progress),
                      child: Center(
                        child: Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    completionText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dGold2,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      subText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaRow({required IconData icon, required String value, String? label}) {
    // RTL: icon on the right, then label, then value flowing left.
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppTheme.dGold2),
          const SizedBox(width: 8),
          if (label != null) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine() {
    // RTL: dim label on the right, gold status pill to its left.
    return Row(
      children: [
        Text(
          'حالة الخطة',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.dGold.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.dGold.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.dGold2),
              const SizedBox(width: 6),
              Text(
                widget.statusLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dGold2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressBar(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 9,
        color: Colors.white.withValues(alpha: 0.16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.dGold, AppTheme.dGold2],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const gap = 14.0;
    // fade the hatch towards the right (start) edge only
    final rect = Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.55, size.height);
    canvas.save();
    canvas.clipRect(rect);
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(
        Offset(x + size.height, 0),
        Offset(x, size.height),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressDonutPainter extends CustomPainter {
  _ProgressDonutPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 13.0;
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.dGold;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressDonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================================
// BUDGET SUMMARY CARD (segmented donut + breakdown)
// ============================================================================

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    required this.total,
    required this.spent,
    required this.obligations,
    required this.debtsTotal,
    required this.upcomingInstallments,
    required this.currency,
    super.key,
  });

  final double total;
  final double spent;
  final double obligations;
  final double debtsTotal;
  final double upcomingInstallments;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(0.0, total - spent - obligations);
    final denom = spent + remaining + obligations;
    double frac(double v) => denom > 0 ? v / denom : 0;

    return _DashCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + icon on the right, total on the left (RTL).
          Row(
            children: [
              const _SectionIcon(
                icon: Icons.savings_outlined,
                color: AppTheme.dGoldDeep,
                bg: AppTheme.dCreamBg,
              ),
              const SizedBox(width: 10),
              const Text(
                'ملخص الميزانية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dInk,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _Num(
                    '${dashFormatMoney(total)} $currency',
                    align: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Body: stat list (right) · donut (center) · legend (left) — RTL order.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _budgetStat(
                      'الديون',
                      '${dashFormatMoney(debtsTotal)} $currency',
                    ),
                    _budgetStat(
                      'الأقساط القادمة',
                      '${dashFormatMoney(upcomingInstallments)} $currency',
                    ),
                    _budgetStat(
                      'الميزانية الكلية',
                      dashFormatMoney(total),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 126,
                height: 126,
                child: CustomPaint(
                  painter: _SegmentDonutPainter(
                    segments: [
                      _Segment(frac(spent), AppTheme.dMaroon),
                      _Segment(frac(remaining), AppTheme.dTrack),
                      _Segment(frac(obligations), AppTheme.dGold),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _budgetLine(
                      'المصروف',
                      AppTheme.dMaroon,
                      '${dashFormatMoney(spent)} $currency',
                      frac(spent),
                    ),
                    _budgetLine(
                      'المتبقي',
                      AppTheme.dTrack,
                      '${dashFormatMoney(remaining)} $currency',
                      frac(remaining),
                    ),
                    _budgetLine(
                      'الالتزامات القادمة',
                      AppTheme.dGold,
                      '${dashFormatMoney(obligations)} $currency',
                      frac(obligations),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Right-hand stat: dim label above an LTR value (debts / installments / total).
  Widget _budgetStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.dInkSoft,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: _Num(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.dInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetLine(String label, Color color, String value, double frac) {
    // RTL: content right-aligned (toward the donut); dot sits left of the label.
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dInk,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _Num(
            '$value  (${(frac * 100).round()}%)',
            style: const TextStyle(fontSize: 12, color: AppTheme.dInkSoft),
          ),
        ],
      ),
    );
  }
}

class _Segment {
  const _Segment(this.fraction, this.color);
  final double fraction;
  final Color color;
}

class _SegmentDonutPainter extends CustomPainter {
  _SegmentDonutPainter({required this.segments});

  final List<_Segment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 22.0;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = segments.fold<double>(0, (s, e) => s + e.fraction);
    if (total <= 0) {
      final empty = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppTheme.dTrack.withValues(alpha: 0.5);
      canvas.drawCircle(center, radius, empty);
      return;
    }

    var start = -math.pi / 2;
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweep = 2 * math.pi * (seg.fraction / total);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = seg.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentDonutPainter oldDelegate) => true;
}

// ============================================================================
// MINI STAT CARDS (upcoming tasks / installments / debts)
// ============================================================================

class MiniStatCard extends StatelessWidget {
  const MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.bigValue,
    required this.unit,
    this.subLabel,
    this.subValue,
    this.subValueColor,
    this.subSecondary,
    this.locked = false,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String bigValue;
  final String unit;
  final String? subLabel;
  final String? subValue;
  final Color? subValueColor;
  final String? subSecondary;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      borderRadius: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 23, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.dInkSoft,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _Num(
              locked ? '—' : bigValue,
              align: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: AppTheme.dInk,
                height: 1.1,
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 12, color: AppTheme.dMuted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(height: 1, color: AppTheme.dLine),
          ),
          if (locked)
            const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.dMuted)
          else ...[
            if (subLabel != null)
              Text(
                subLabel!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.dMuted),
              ),
            if (subValue != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _Num(
                  subValue!,
                  align: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: subValueColor ?? AppTheme.dInk,
                  ),
                ),
              ),
            if (subSecondary != null)
              _Num(
                subSecondary!,
                align: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppTheme.dMuted),
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// QUICK ACTIONS
// ============================================================================

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;
}

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'إجراءات سريعة',
            icon: Icons.bolt_rounded,
            iconColor: Colors.white,
            iconBg: AppTheme.dMaroon,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _QuickActionItem(action: actions[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.dLine),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon, size: 22, color: action.color),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dInk,
                        height: 1.15,
                      ),
                    ),
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

// ============================================================================
// ALERTS
// ============================================================================

enum AlertTone { pink, cream, green }

class DashboardAlert {
  const DashboardAlert({
    required this.title,
    required this.body,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String body;
  final IconData icon;
  final AlertTone tone;
}

class AlertsCard extends StatelessWidget {
  const AlertsCard({required this.alerts, this.onViewAll, super.key});

  final List<DashboardAlert> alerts;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'تنبيهات مهمة',
            icon: Icons.notifications_none_rounded,
            iconColor: AppTheme.dMaroon,
            iconBg: AppTheme.dPinkBg,
            trailing: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.dPinkBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.dMaroon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'لا توجد تنبيهات حالياً',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.dMuted, fontSize: 13),
              ),
            )
          else
            for (final alert in alerts) ...[
              _AlertTile(alert: alert),
              const SizedBox(height: 11),
            ],
          if (onViewAll != null)
            _FootLink(label: 'عرض كل التنبيهات', onTap: onViewAll!),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    final (bg, accent) = switch (alert.tone) {
      AlertTone.pink => (AppTheme.dPinkBg, AppTheme.dMaroon),
      AlertTone.cream => (AppTheme.dCreamBg, AppTheme.dGoldDeep),
      AlertTone.green => (AppTheme.dGreenBg, AppTheme.dGreen),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RTL: white icon tile on the right, text to its left (right-aligned).
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(alert.icon, size: 19, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alert.body,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppTheme.dInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PARTICIPANTS
// ============================================================================

class ParticipantInfo {
  const ParticipantInfo({
    required this.name,
    required this.roleLabel,
    required this.isManager,
    this.phone,
  });

  final String name;
  final String roleLabel;
  final bool isManager;
  final String? phone;
}

class ParticipantsCard extends StatelessWidget {
  const ParticipantsCard({
    required this.participants,
    required this.count,
    this.onAddMember,
    super.key,
  });

  final List<ParticipantInfo> participants;
  final int count;
  final VoidCallback? onAddMember;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'المشاركون في الخطة',
            icon: Icons.groups_rounded,
            iconColor: Colors.white,
            iconBg: AppTheme.dMaroon,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.dMaroon,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '$count عضو',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'لا يوجد مشاركون بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.dMuted, fontSize: 13),
              ),
            )
          else
            for (var i = 0; i < participants.length; i++)
              _ParticipantTile(
                info: participants[i],
                showDivider: i < participants.length - 1,
              ),
          if (onAddMember != null)
            _FootLink(label: 'إضافة عضو', onTap: onAddMember!),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.info, required this.showDivider});

  final ParticipantInfo info;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppTheme.dLine))
            : null,
      ),
      child: Row(
        children: [
          _Avatar(name: info.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dInk,
                  ),
                ),
                if (info.phone != null)
                  _Num(
                    info.phone!,
                    style: const TextStyle(fontSize: 13, color: AppTheme.dMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
            decoration: BoxDecoration(
              color: info.isManager ? AppTheme.dCreamBg : AppTheme.dGreenBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              info.roleLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: info.isManager ? AppTheme.dGoldDeep : AppTheme.dGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  static const _palette = [
    Color(0xFFB6432F),
    Color(0xFF3A3A3A),
    Color(0xFF4F6D7A),
    Color(0xFF8A5A44),
    Color(0xFF5B6E4F),
  ];

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim().characters.first : '؟';
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED PLANS
// ============================================================================

class SharedPlansCard extends StatelessWidget {
  const SharedPlansCard({required this.onOpen, this.subtitle, super.key});

  final VoidCallback onOpen;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'الخطط المشتركة معي',
            icon: Icons.groups_rounded,
            iconColor: Colors.white,
            iconBg: AppTheme.dMaroon,
            trailing: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Material(
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppTheme.dMaroonBright, AppTheme.dMaroon],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.dMaroon.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        size: 22,
                        color: AppTheme.dGold2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'عرض الخطط المشتركة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAV
// ============================================================================

class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    this.onMore,
    this.onTasks,
    this.onAdd,
    this.onPlans,
    this.onHome,
    this.activeIndex = 4,
    super.key,
  });

  final VoidCallback? onMore;
  final VoidCallback? onTasks;
  final VoidCallback? onAdd;
  final VoidCallback? onPlans;
  final VoidCallback? onHome;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        border: const Border(top: BorderSide(color: Color(0xFFF1ECE6))),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: 'الرئيسية',
                      active: activeIndex == 4,
                      onTap: onHome,
                      spark: true,
                    ),
                    _NavItem(
                      icon: Icons.event_note_rounded,
                      label: 'الخطط',
                      active: activeIndex == 3,
                      onTap: onPlans,
                    ),
                    const SizedBox(width: 90),
                    _NavItem(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'المهام',
                      active: activeIndex == 1,
                      onTap: onTasks,
                    ),
                    _NavItem(
                      icon: Icons.grid_view_rounded,
                      label: 'المزيد',
                      active: activeIndex == 0,
                      onTap: onMore,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -24,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.dMaroonBright, AppTheme.dMaroon],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.dMaroon.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
    this.spark = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final bool spark;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.dMaroon : AppTheme.dMuted;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: SizedBox(
        width: 60,
        child: spark
            ? Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  content,
                  const Positioned(
                    top: -8,
                    left: 2,
                    child: Text('✦', style: TextStyle(fontSize: 12, color: AppTheme.dGold)),
                  ),
                  const Positioned(
                    top: 4,
                    left: -6,
                    child: Text('✦', style: TextStyle(fontSize: 8, color: AppTheme.dGold2)),
                  ),
                ],
              )
            : content,
      ),
    );
  }
}

// ============================================================================
// ACCOUNT SHEET (profile + logout)
// ============================================================================

Future<void> showAccountSheet(
  BuildContext context, {
  required String name,
  String? phone,
  required VoidCallback onLogout,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.dCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppTheme.dPinkBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.dMaroon,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.dInk,
                            ),
                          ),
                          if (phone != null)
                            _Num(
                              phone,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.dMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================================
// LOCKED SECTION + LOADING SKELETON
// ============================================================================

class LockedSectionCard extends StatelessWidget {
  const LockedSectionCard({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppTheme.dMuted),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dMuted,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'غير متاح حسب صلاحياتك',
                style: TextStyle(fontSize: 12, color: AppTheme.dMuted),
              ),
            ],
          ),
          const SizedBox(width: 10),
          _SectionIcon(
            icon: icon,
            color: AppTheme.dMuted,
            bg: AppTheme.dLine,
          ),
        ],
      ),
    );
  }
}

class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({super.key});

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.75).animate(_controller),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            _box(180),
            const SizedBox(height: 16),
            _box(150),
            const SizedBox(height: 16),
            _box(120),
            const SizedBox(height: 16),
            _box(160),
          ],
        ),
      ),
    );
  }

  Widget _box(double height) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.dTrack.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(22),
        ),
      );
}

// ============================================================================
// SHARED PRIMITIVES
// ============================================================================

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.child,
    required this.padding,
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // RTL: leading icon on the right, optional trailing widget on the left.
    return Row(
      children: [
        _SectionIcon(icon: icon, color: iconColor, bg: iconBg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.dInk,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, required this.color, required this.bg});

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _FootLink extends StatelessWidget {
  const _FootLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          // RTL: label on the right, forward chevron to its left.
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.dMaroon,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_left_rounded, size: 18, color: AppTheme.dMaroon),
          ],
        ),
      ),
    );
  }
}
