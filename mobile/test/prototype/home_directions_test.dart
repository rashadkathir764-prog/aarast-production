// Throwaway design prototype: three visual directions for the groom's home.
// Not product code. Regenerate with:
//   flutter test test/prototype/home_directions_test.dart --update-goldens
@Tags(['golden'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../support/preview_fonts.dart';

const _plex = 'IBMPlexSansArabic';
const _taj = 'Tajawal';
const _amiri = 'Amiri';

// ---------------------------------------------------------------- shared data

class _Up {
  const _Up(this.when, this.title, this.sub, this.action, this.icon);
  final String when, title, sub, action;
  final IconData icon;
}

const _upcoming = [
  _Up(
    'السبت',
    'التصوير: وصلك عرضين',
    'قارن واختر قبل ما ترتفع الأسعار',
    'قارن',
    LucideIcons.camera,
  ),
  _Up(
    'الأحد',
    '20 ضيف ما ردّوا',
    'أرسل لهم تذكير على واتساب',
    'ذكّرهم',
    LucideIcons.users,
  ),
  _Up(
    'هذا الأسبوع',
    'الفرقة ما انحجزت',
    'العرس بعد 3 أشهر',
    'ابحث',
    LucideIcons.music,
  ),
];

const _steps = [
  ('ميزانيتك', 'رقم تقريبي لكل بند، دقيقتين وتخلص', LucideIcons.wallet),
  ('أهم الحجوزات', 'القاعة والتصوير والفرقة', LucideIcons.building2),
  ('قائمة الضيوف', 'من جهات الاتصال بضغطة', LucideIcons.users),
];

const _moments = [
  'البداية',
  'التجهيز',
  'أسبوع العرس',
  'يوم العرس',
  'بعد العرس',
];

const _tabs = [
  ('الرئيسية', LucideIcons.home),
  ('المال', LucideIcons.wallet),
  ('المهام', LucideIcons.listChecks),
  ('الضيوف', LucideIcons.users),
  ('المزودين', LucideIcons.store),
];

Widget _statusBar(Color c) => Padding(
  padding: const EdgeInsets.fromLTRB(28, 14, 28, 6),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      children: [
        Text(
          '9:41',
          style: TextStyle(
            fontFamily: _plex,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
        const Spacer(),
        Icon(LucideIcons.signal, size: 15, color: c),
        const SizedBox(width: 6),
        Icon(LucideIcons.wifi, size: 15, color: c),
        const SizedBox(width: 6),
        Icon(LucideIcons.batteryFull, size: 18, color: c),
      ],
    ),
  ),
);

// ============================================================ A · هدوء
class _A {
  static const bg = Color(0xFFF8F5F2);
  static const ink = Color(0xFF1C1416);
  static const muted = Color(0xFF7D7173);
  static const line = Color(0xFFE8E1DE);
  static const accent = Color(0xFF7A1630);
  static const warn = Color(0xFFC0712A);

  static TextStyle t(
    double s, {
    FontWeight w = FontWeight.w400,
    Color c = ink,
    double h = 1.4,
  }) => TextStyle(
    fontFamily: _plex,
    fontSize: s,
    fontWeight: w,
    color: c,
    height: h,
  );
}

Widget directionA({required bool fresh}) {
  final t = _A.t;
  Widget header() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _A.ink,
            shape: BoxShape.circle,
          ),
          child: Text(
            'م',
            style: t(17, w: FontWeight.w600, c: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('عرس محمد وسلمى', style: t(13, c: _A.muted)),
              Text('صباح الخير، محمد', style: t(19, w: FontWeight.w700)),
            ],
          ),
        ),
        Stack(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _A.line),
              ),
              child: const Icon(LucideIcons.bell, size: 19, color: _A.ink),
            ),
            Positioned(
              top: 9,
              left: 11,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _A.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget countdown() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('96', style: t(84, w: FontWeight.w700, h: 0.95)),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('يوم على عرسك', style: t(18, w: FontWeight.w600)),
              Text('الخميس 21 يناير · صنعاء', style: t(13, c: _A.muted)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget journey(int at) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
    child: Row(
      children: [
        for (var i = 0; i < _moments.length; i++)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsetsDirectional.only(end: 4),
                  decoration: BoxDecoration(
                    color: i < at
                        ? _A.ink
                        : i == at
                        ? _A.accent
                        : _A.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _moments[i],
                  style: t(
                    11,
                    w: i == at ? FontWeight.w700 : FontWeight.w400,
                    c: i == at ? _A.accent : _A.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget label(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 10),
    child: Text(
      s,
      style: t(13, w: FontWeight.w600, c: _A.muted),
    ),
  );

  Widget money() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('باقي تدفع', style: t(13, c: _A.muted)),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '5.4 مليون',
                          style: t(26, w: FontWeight.w700),
                        ),
                        TextSpan(
                          text: '  ر.ي',
                          style: t(13, c: _A.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ناقصك', style: t(13, c: _A.muted)),
                Text(
                  '1.3 مليون',
                  style: t(20, w: FontWeight.w700, c: _A.warn),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(flex: 46, child: Container(color: _A.ink)),
                SizedBox(width: 2),
                Expanded(flex: 41, child: Container(color: Color(0xFFC9A9B1))),
                SizedBox(width: 2),
                Expanded(flex: 13, child: Container(color: _A.warn)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _dot(_A.ink),
            Text(' دفعت 4.6', style: t(12, c: _A.muted)),
            const SizedBox(width: 14),
            _dot(const Color(0xFFC9A9B1)),
            Text(' معك 4.1', style: t(12, c: _A.muted)),
            const SizedBox(width: 14),
            _dot(_A.warn),
            Text(' ناقصك 1.3', style: t(12, c: _A.muted)),
            const Spacer(),
            Text('من 10 مليون', style: t(12, c: _A.muted)),
          ],
        ),
      ],
    ),
  );

  Widget next() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _A.ink,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _A.warn.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'بعد 5 أيام',
            style: t(12, w: FontWeight.w600, c: const Color(0xFFF2B77A)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'دفعة القاعة: 500,000 ر.ي',
          style: t(21, w: FontWeight.w700, c: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          'قاعة الماسة · الدفعة الثانية من ثلاث',
          style: t(14, c: Colors.white70),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text('سجّل الدفعة', style: t(15, w: FontWeight.w600)),
            ),
            const SizedBox(width: 18),
            Text('ذكّرني لاحقًا', style: t(14, c: Colors.white70)),
          ],
        ),
      ],
    ),
  );

  Widget upcoming() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        for (var i = 0; i < _upcoming.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 18, endIndent: 18, color: _A.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    _upcoming[i].when,
                    style: t(12, w: FontWeight.w600, c: _A.accent),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _upcoming[i].title,
                        style: t(15, w: FontWeight.w600),
                      ),
                      Text(_upcoming[i].sub, style: t(12.5, c: _A.muted)),
                    ],
                  ),
                ),
                Text(
                  _upcoming[i].action,
                  style: t(14, w: FontWeight.w600, c: _A.accent),
                ),
                const Icon(LucideIcons.chevronLeft, size: 16, color: _A.accent),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget pulse() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        for (final p in const [
          ('المهام', '12', 'من 30', 0.4),
          ('الضيوف أكدوا', '86', 'من 124', 0.69),
          ('محجوز', '3', 'من 7', 0.43),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.$1, style: t(12, c: _A.muted)),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: p.$2,
                          style: t(22, w: FontWeight.w700),
                        ),
                        TextSpan(
                          text: ' ${p.$3}',
                          style: t(12, c: _A.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: p.$4,
                      minHeight: 3,
                      backgroundColor: _A.line,
                      color: _A.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget steps() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 18, endIndent: 18, color: _A.line),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0 ? _A.ink : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == 0 ? _A.ink : _A.line,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: t(
                      14,
                      w: FontWeight.w700,
                      c: i == 0 ? Colors.white : _A.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i].$1,
                        style: t(
                          16,
                          w: FontWeight.w600,
                          c: i == 0 ? _A.ink : _A.muted,
                        ),
                      ),
                      Text(_steps[i].$2, style: t(13, c: _A.muted)),
                      if (i == 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _A.ink,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'ابدأ',
                            style: t(15, w: FontWeight.w600, c: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  return _Phone(
    bg: _A.bg,
    status: _A.ink,
    nav: _NavA(),
    children: fresh
        ? [
            header(),
            countdown(),
            journey(0),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 4),
              child: Text(
                'ثلاث خطوات وعرسك منظم',
                style: t(22, w: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Text(
                'خلصت 0 من 3 · كل خطوة تفتح لك قسمها',
                style: t(13, c: _A.muted),
              ),
            ),
            steps(),
          ]
        : [
            header(),
            countdown(),
            journey(1),
            label('فلوسك'),
            money(),
            label('الخطوة الجاية'),
            next(),
            label('بعدها'),
            upcoming(),
            label('عرسك بالأرقام'),
            pulse(),
          ],
  );
}

Widget _dot(Color c) => Container(
  width: 8,
  height: 8,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);

class _NavA extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 10, 8, 26),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _A.line)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Expanded(
            child: Column(
              children: [
                Icon(_tabs[i].$2, size: 22, color: i == 0 ? _A.ink : _A.muted),
                const SizedBox(height: 4),
                Text(
                  _tabs[i].$1,
                  style: _A.t(
                    11.5,
                    w: i == 0 ? FontWeight.w700 : FontWeight.w400,
                    c: i == 0 ? _A.ink : _A.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == 0 ? _A.accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ============================================================ B · ليل صنعاء
class _B {
  static const bgTop = Color(0xFF241018);
  static const bgBottom = Color(0xFF0E090C);
  static const gold = Color(0xFFDDB665);
  static const text = Color(0xFFF4EAE6);
  static const muted = Color(0xFFB4A3A2);
  static const glass = Color(0x0FFFFFFF);
  static const glassLine = Color(0x1AFFFFFF);
  static const amber = Color(0xFFF0B46C);

  static TextStyle t(
    double s, {
    FontWeight w = FontWeight.w400,
    Color c = text,
    double h = 1.4,
    String f = _plex,
  }) =>
      TextStyle(fontFamily: f, fontSize: s, fontWeight: w, color: c, height: h);
}

class _QamariyaPainter extends CustomPainter {
  _QamariyaPainter(this.lit);
  final int lit;

  static const panes = [
    Color(0xFF8E1F3E),
    Color(0xFFDDB665),
    Color(0xFF2E7C77),
    Color(0xFF3D5A9A),
    Color(0xFFB4506A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final archRect = Rect.fromCircle(center: center, radius: r);
    final inner = r * 0.56;

    // Outer frame glow.
    canvas.drawCircle(
      center,
      r + 6,
      Paint()
        ..shader = RadialGradient(
          colors: [_B.gold.withValues(alpha: 0.18), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: r + 40)),
    );

    final sweep = math.pi / panes.length;
    for (var i = 0; i < panes.length; i++) {
      // Panes run right-to-left (RTL): first moment on the right.
      final start = -sweep * (i + 1);
      final on = i <= lit;
      final path = Path()
        ..arcTo(archRect.deflate(4), start, sweep, true)
        ..arcTo(
          Rect.fromCircle(center: center, radius: inner),
          start + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = panes[i].withValues(
            alpha: i == lit
                ? 0.95
                : on
                ? 0.6
                : 0.13,
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF0E090C),
      );
    }
    // Plaster frame.
    canvas.drawArc(
      archRect.deflate(1),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _B.gold.withValues(alpha: 0.75),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: inner - 4),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _B.gold.withValues(alpha: 0.4),
    );
    canvas.drawLine(
      Offset(0, r),
      Offset(size.width, r),
      Paint()
        ..strokeWidth = 1.5
        ..color = _B.gold.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track);
  final double v;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(3), 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(
      rect.deflate(3),
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      p..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget directionB({required bool fresh}) {
  final t = _B.t;

  BoxDecoration glass([double r = 22]) => BoxDecoration(
    color: _B.glass,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: _B.glassLine),
  );

  Widget header() => Padding(
    padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _B.gold.withValues(alpha: 0.6)),
          ),
          child: Text(
            'م',
            style: t(17, w: FontWeight.w600, c: _B.gold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مساء الخير، محمد', style: t(18, w: FontWeight.w600)),
              Text('عرس محمد وسلمى', style: t(13, c: _B.muted)),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: glass(21),
          child: const Icon(LucideIcons.bellDot, size: 19, color: _B.text),
        ),
      ],
    ),
  );

  Widget arch(int lit) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 26, 40, 0),
    child: Column(
      children: [
        SizedBox(
          width: 300,
          height: 150,
          child: CustomPaint(
            painter: _QamariyaPainter(lit),
            child: Align(
              alignment: const Alignment(0, 1.05),
              child: Text(
                '96',
                style: t(64, w: FontWeight.w700, c: _B.gold, h: 1, f: _amiri),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'يومًا على زفافكم',
          style: t(20, f: _amiri, w: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('الخميس 21 يناير · صنعاء', style: t(13, c: _B.muted)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _B.gold.withValues(alpha: 0.35)),
          ),
          child: Text(
            'المرحلة ${lit + 1} من 5 · ${_moments[lit]}',
            style: t(12.5, w: FontWeight.w600, c: _B.gold),
          ),
        ),
      ],
    ),
  );

  Widget label(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 10),
    child: Row(
      children: [
        Container(width: 14, height: 1, color: _B.gold.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          s,
          style: t(13, w: FontWeight.w600, c: _B.gold),
        ),
      ],
    ),
  );

  Widget next() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF7A1A37), Color(0xFF3B0C1C)],
      ),
      border: Border.all(color: _B.gold.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.clock, size: 14, color: _B.amber),
            const SizedBox(width: 6),
            Text(
              'بعد 5 أيام',
              style: t(12.5, w: FontWeight.w600, c: _B.amber),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('دفعة القاعة: 500,000 ر.ي', style: t(21, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'قاعة الماسة · الدفعة الثانية من ثلاث',
          style: t(14, c: const Color(0xCCF4EAE6)),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: _B.gold,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'سجّل الدفعة',
                style: t(15, w: FontWeight.w700, c: const Color(0xFF2A1218)),
              ),
            ),
            const SizedBox(width: 18),
            Text('ذكّرني لاحقًا', style: t(14, c: const Color(0xB3F4EAE6))),
          ],
        ),
      ],
    ),
  );

  Widget money() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(18),
    decoration: glass(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'باقي تدفع ',
                style: t(15, c: _B.muted),
              ),
              TextSpan(
                text: '5.4 مليون',
                style: t(22, w: FontWeight.w700),
              ),
              TextSpan(
                text: '  ومعك ',
                style: t(15, c: _B.muted),
              ),
              TextSpan(
                text: '4.1',
                style: t(22, w: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 0.87,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: _B.gold,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'ناقصك 1.3 مليون',
              style: t(13, w: FontWeight.w600, c: _B.amber),
            ),
            const Spacer(),
            Text('شوف كيف تقفلها', style: t(13, c: _B.gold)),
            const Icon(LucideIcons.chevronLeft, size: 15, color: _B.gold),
          ],
        ),
      ],
    ),
  );

  Widget upcoming() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: glass(),
    child: Column(
      children: [
        for (var i = 0; i < _upcoming.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: _B.glassLine,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _B.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_upcoming[i].icon, size: 18, color: _B.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _upcoming[i].title,
                        style: t(15, w: FontWeight.w600),
                      ),
                      Text(
                        '${_upcoming[i].when} · ${_upcoming[i].sub}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(12.5, c: _B.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _upcoming[i].action,
                  style: t(14, w: FontWeight.w600, c: _B.gold),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget pulse() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final p in const [
          ('المهام', '12/30', 0.4),
          ('أكدوا', '86/124', 0.69),
          ('محجوز', '3/7', 0.43),
        ]) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: glass(18),
              child: Column(
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CustomPaint(
                      painter: _RingPainter(
                        p.$3,
                        _B.gold,
                        const Color(0x1FFFFFFF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(p.$2, style: t(15, w: FontWeight.w700)),
                  Text(p.$1, style: t(12, c: _B.muted)),
                ],
              ),
            ),
          ),
          if (p.$1 != 'محجوز') const SizedBox(width: 10),
        ],
      ],
    ),
  );

  Widget steps() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: glass(),
    child: Column(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: _B.glassLine,
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: i == 0 ? _B.gold : _B.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _steps[i].$3,
                    size: 19,
                    color: i == 0 ? const Color(0xFF2A1218) : _B.muted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. ${_steps[i].$1}',
                        style: t(
                          16,
                          w: FontWeight.w600,
                          c: i == 0 ? _B.text : _B.muted,
                        ),
                      ),
                      Text(_steps[i].$2, style: t(13, c: _B.muted)),
                      if (i == 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _B.gold,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'ابدأ',
                            style: t(
                              15,
                              w: FontWeight.w700,
                              c: const Color(0xFF2A1218),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  return _Phone(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_B.bgTop, _B.bgBottom],
      stops: [0, 0.55],
    ),
    status: _B.text,
    nav: _NavB(),
    children: fresh
        ? [
            header(),
            arch(0),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 4),
              child: Text(
                'ثلاث خطوات وعرسك منظم',
                style: t(22, w: FontWeight.w700, f: _amiri),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Text(
                'كل خطوة تضيء لك جزءًا من القمرية',
                style: t(13, c: _B.muted),
              ),
            ),
            steps(),
          ]
        : [
            header(),
            arch(1),
            label('الخطوة الجاية'),
            next(),
            label('فلوسك'),
            money(),
            label('بعدها'),
            upcoming(),
            const SizedBox(height: 16),
            pulse(),
          ],
  );
}

class _NavB extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 22),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1216),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _B.glassLine),
    ),
    child: Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Expanded(
            child: Column(
              children: [
                Icon(_tabs[i].$2, size: 21, color: i == 0 ? _B.gold : _B.muted),
                const SizedBox(height: 4),
                Text(
                  _tabs[i].$1,
                  style: _B.t(
                    11.5,
                    w: i == 0 ? FontWeight.w700 : FontWeight.w400,
                    c: i == 0 ? _B.gold : _B.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ============================================================ C · فيروز
class _C {
  static const bg = Color(0xFFF2F4F3);
  static const ink = Color(0xFF13211F);
  static const muted = Color(0xFF66736F);
  static const teal = Color(0xFF0B6E69);
  static const tealDark = Color(0xFF064B47);
  static const saffron = Color(0xFFF2A93B);
  static const tealSoft = Color(0xFFDCEFEC);
  static const saffronSoft = Color(0xFFFCEFD8);
  static const lilacSoft = Color(0xFFECE6F6);
  static const lilac = Color(0xFF6A4FA3);
  static const skySoft = Color(0xFFE0EEF8);
  static const sky = Color(0xFF2F6E9E);
  static const coral = Color(0xFFD9583B);

  static TextStyle t(
    double s, {
    FontWeight w = FontWeight.w400,
    Color c = ink,
    double h = 1.35,
  }) => TextStyle(
    fontFamily: _taj,
    fontSize: s,
    fontWeight: w,
    color: c,
    height: h,
  );
}

Widget directionC({required bool fresh}) {
  final t = _C.t;

  Widget header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أهلًا محمد', style: t(24, w: FontWeight.w700)),
              Text('عرس محمد وسلمى · صنعاء', style: t(14, c: _C.muted)),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.bell, size: 20, color: _C.ink),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _C.saffron,
            shape: BoxShape.circle,
          ),
          child: Text(
            'م',
            style: t(18, w: FontWeight.w700, c: _C.ink),
          ),
        ),
      ],
    ),
  );

  Widget hero(int at) => Container(
    margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [_C.teal, _C.tealDark],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '96',
              style: t(68, w: FontWeight.w700, c: Colors.white, h: 0.95),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'يوم على عرسك',
                    style: t(18, w: FontWeight.w700, c: Colors.white),
                  ),
                  Text(
                    'الخميس 21 يناير',
                    style: t(14, c: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _C.saffron,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_moments[at], style: t(13, w: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsetsDirectional.only(end: 5),
                  decoration: BoxDecoration(
                    color: i < at
                        ? Colors.white
                        : i == at
                        ? _C.saffron
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget next() => Container(
    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _C.saffronSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            LucideIcons.calendarDays,
            size: 22,
            color: Color(0xFFB4741A),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخطوة الجاية · بعد 5 أيام',
                style: t(13, w: FontWeight.w700, c: const Color(0xFFB4741A)),
              ),
              const SizedBox(height: 2),
              Text(
                'دفعة القاعة: 500,000 ر.ي',
                style: t(19, w: FontWeight.w700),
              ),
              Text('قاعة الماسة · الثانية من ثلاث', style: t(14, c: _C.muted)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _C.teal,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'سجّل الدفعة',
                      style: t(15, w: FontWeight.w700, c: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'ذكّرني',
                      style: t(15, w: FontWeight.w700, c: _C.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget tile({
    required Color bg,
    required Color fg,
    required IconData icon,
    required String title,
    required String big,
    required String small,
    double? value,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 6),
            Text(
              title,
              style: t(14, w: FontWeight.w700, c: fg),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(big, style: t(24, w: FontWeight.w700)),
        Text(small, style: t(13, c: _C.muted)),
        if (value != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              color: fg,
            ),
          ),
        ],
      ],
    ),
  );

  Widget bento() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _C.tealSoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.wallet, size: 17, color: _C.teal),
                  const SizedBox(width: 6),
                  Text(
                    'المال',
                    style: t(14, w: FontWeight.w700, c: _C.teal),
                  ),
                  const Spacer(),
                  Text('من 10 مليون', style: t(13, c: _C.muted)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ناقصك', style: t(14, c: _C.muted)),
                        Text(
                          '1.3 مليون ر.ي',
                          style: t(28, w: FontWeight.w700, c: _C.coral),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('باقي تدفع 5.4', style: t(14, w: FontWeight.w700)),
                      Text(
                        'معك 4.1',
                        style: t(14, w: FontWeight.w700, c: _C.teal),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(flex: 46, child: Container(color: _C.teal)),
                      SizedBox(width: 3),
                      Expanded(
                        flex: 41,
                        child: Container(color: Color(0xFF7FC3BC)),
                      ),
                      SizedBox(width: 3),
                      Expanded(flex: 13, child: Container(color: _C.coral)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: tile(
                bg: _C.saffronSoft,
                fg: const Color(0xFFB4741A),
                icon: LucideIcons.listChecks,
                title: 'المهام',
                big: '12',
                small: 'من 30 مهمة',
                value: 0.4,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                bg: _C.lilacSoft,
                fg: _C.lilac,
                icon: LucideIcons.users,
                title: 'الضيوف',
                big: '86',
                small: 'أكدوا من 124',
                value: 0.69,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: tile(
                bg: _C.skySoft,
                fg: _C.sky,
                icon: LucideIcons.store,
                title: 'المزودين',
                big: '3',
                small: 'محجوز من 7',
                value: 0.43,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget upcoming() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        for (final (i, u) in _upcoming.indexed)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: [_C.skySoft, _C.lilacSoft, _C.saffronSoft][i],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    u.icon,
                    size: 19,
                    color: [_C.sky, _C.lilac, const Color(0xFFB4741A)][i],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.title, style: t(15.5, w: FontWeight.w700)),
                      Text(
                        '${u.when} · ${u.sub}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t(13, c: _C.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _C.tealSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    u.action,
                    style: t(13.5, w: FontWeight.w700, c: _C.teal),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget label(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
    child: Text(s, style: t(17, w: FontWeight.w700)),
  );

  Widget steps() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: i == 0
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
              border: i == 0 ? Border.all(color: _C.teal, width: 2) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: [_C.tealSoft, _C.skySoft, _C.lilacSoft][i],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _steps[i].$3,
                    size: 22,
                    color: [_C.teal, _C.sky, _C.lilac][i],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الخطوة ${i + 1}',
                        style: t(12.5, w: FontWeight.w700, c: _C.muted),
                      ),
                      Text(_steps[i].$1, style: t(17, w: FontWeight.w700)),
                      Text(_steps[i].$2, style: t(13.5, c: _C.muted)),
                    ],
                  ),
                ),
                if (i == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _C.teal,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'ابدأ',
                      style: t(15, w: FontWeight.w700, c: Colors.white),
                    ),
                  )
                else
                  const Icon(
                    LucideIcons.chevronLeft,
                    color: _C.muted,
                    size: 20,
                  ),
              ],
            ),
          ),
      ],
    ),
  );

  return _Phone(
    bg: _C.bg,
    status: _C.ink,
    nav: _NavC(),
    children: fresh
        ? [
            header(),
            hero(0),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 2),
              child: Text(
                'ثلاث خطوات وعرسك منظم',
                style: t(22, w: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: Row(
                children: [
                  Text('خلصت 0 من 3', style: t(14, c: _C.muted)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: 0.04,
                        minHeight: 6,
                        backgroundColor: Colors.white,
                        color: _C.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            steps(),
          ]
        : [header(), hero(1), next(), bento(), label('بعدها'), upcoming()],
  );
}

class _NavC extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 22),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE2E7E5)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          if (i == 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _C.teal,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(_tabs[i].$2, size: 19, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    _tabs[i].$1,
                    style: _C.t(14, w: FontWeight.w700, c: Colors.white),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Icon(_tabs[i].$2, size: 21, color: _C.muted),
                  const SizedBox(height: 3),
                  Text(_tabs[i].$1, style: _C.t(11.5, c: _C.muted)),
                ],
              ),
            ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- frame

class _Phone extends StatelessWidget {
  const _Phone({
    this.bg,
    this.gradient,
    required this.status,
    required this.nav,
    required this.children,
  });
  final Color? bg;
  final Gradient? gradient;
  final Color status;
  final Widget nav;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      decoration: BoxDecoration(color: bg, gradient: gradient),
      child: Column(
        children: [
          _statusBar(status),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...children, const SizedBox(height: 18)],
              ),
            ),
          ),
          nav,
        ],
      ),
    ),
  );
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget screen, {
  double height = 844,
}) async {
  tester.view.physicalSize = Size(390 * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: _plex),
      home: Material(child: screen),
    ),
  );
  await tester.pump();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets(
    'A active',
    (t) => _shot(t, 'a_active', directionA(fresh: false), height: 1270),
  );
  testWidgets('A fresh', (t) => _shot(t, 'a_fresh', directionA(fresh: true)));
  testWidgets(
    'B active',
    (t) => _shot(t, 'b_active', directionB(fresh: false), height: 1290),
  );
  testWidgets(
    'B fresh',
    (t) => _shot(t, 'b_fresh', directionB(fresh: true), height: 900),
  );
  testWidgets(
    'C active',
    (t) => _shot(t, 'c_active', directionC(fresh: false), height: 1060),
  );
  testWidgets('C fresh', (t) => _shot(t, 'c_fresh', directionC(fresh: true)));
}
