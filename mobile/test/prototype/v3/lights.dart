// Journey prototype v3: the wedding lights. Strings of warm bulbs hung from
// one high point in front of the groom's house become aarast's second
// signature beside the qamariya, plus the groom/bride choice with the real
// Yemeni groom's outfit and a lace detail for the bride.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import '../c_journey/screens_home.dart' show homeHeader;

const _warm = Color(0xFFFFE3A3);
const _night = Color(0xFF0E2A33);

/// Bulb strings fanning down from one apex, the shape hung over Sanaa
/// streets for a wedding. The first [lit] strands glow; the rest wait.
class Lights extends CustomPainter {
  const Lights({this.strands = 9, this.lit = 9, this.apexY = 0.04, this.cross = true});
  final int strands;
  final int lit;
  final double apexY;
  final bool cross;

  void _bulb(Canvas c, Offset o, bool on) {
    if (on) {
      c.drawCircle(o, 6, Paint()
        ..color = _warm.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      c.drawCircle(o, 2.4, Paint()..color = _warm);
    } else {
      c.drawCircle(o, 2, Paint()..color = Colors.white.withValues(alpha: 0.18));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final apex = Offset(size.width * 0.5, size.height * apexY);
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.16);
    // Order strands from the middle outwards so lighting fills symmetrically.
    final order = List<int>.generate(strands, (i) => i)
      ..sort((a, b) => (a - (strands - 1) / 2).abs().compareTo((b - (strands - 1) / 2).abs()));
    for (var k = 0; k < strands; k++) {
      final i = order[k];
      final end = Offset(size.width * (-0.08 + 1.16 * i / (strands - 1)), size.height);
      final ctrl = Offset((apex.dx + end.dx) / 2, (apex.dy + end.dy) / 2 + size.height * 0.10);
      canvas.drawPath(
        Path()
          ..moveTo(apex.dx, apex.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
        wire,
      );
      for (var t = 0.06; t <= 1.0; t += 0.075) {
        final p = Offset(
          math.pow(1 - t, 2) * apex.dx + 2 * (1 - t) * t * ctrl.dx + t * t * end.dx,
          math.pow(1 - t, 2) * apex.dy + 2 * (1 - t) * t * ctrl.dy + t * t * end.dy,
        );
        _bulb(canvas, p, k < lit);
      }
    }
    if (cross) {
      // Two sagging strings across the street.
      for (final y in [0.30, 0.52]) {
        final a = Offset(0, size.height * y);
        final b = Offset(size.width, size.height * (y - 0.06));
        final m = Offset(size.width / 2, size.height * (y + 0.07));
        canvas.drawPath(Path()..moveTo(a.dx, a.dy)..quadraticBezierTo(m.dx, m.dy, b.dx, b.dy), wire);
        for (var t = 0.04; t < 1; t += 0.09) {
          final p = Offset(
            math.pow(1 - t, 2) * a.dx + 2 * (1 - t) * t * m.dx + t * t * b.dx,
            math.pow(1 - t, 2) * a.dy + 2 * (1 - t) * t * m.dy + t * t * b.dy,
          );
          _bulb(canvas, p, lit > 0);
        }
      }
    }
    canvas.drawCircle(apex, 4, Paint()..color = _warm);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lace for the bride's card: scallops, little flowers and dotted ribs.
class _Lace extends CustomPainter {
  const _Lace();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F3EC));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFBFB6A6);
    final soft = Paint()..color = const Color(0xFFD9D1C2);
    for (var row = 0; row < 7; row++) {
      final y = row * 26.0 + 8;
      for (var x = (row.isEven ? 0.0 : 13.0); x < size.width + 26; x += 26) {
        canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: 13), 0, math.pi, false, line);
        final f = Offset(x + 13, y + 9);
        for (var p = 0; p < 5; p++) {
          final a = p * 2 * math.pi / 5;
          canvas.drawCircle(f + Offset(math.cos(a) * 3.2, math.sin(a) * 3.2), 1.6, soft);
        }
        canvas.drawCircle(f, 1.2, line..style = PaintingStyle.fill);
        line.style = PaintingStyle.stroke;
      }
    }
    // A pearl edge, like the hem of the veil.
    for (var x = 4.0; x < size.width; x += 9) {
      canvas.drawCircle(Offset(x, size.height - 6), 2.4, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, size.height - 6), 2.4, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFFCFC6B6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Picture on the card's far edge that fades into the white card.
Widget _fadePicture(Widget picture) => SizedBox(
  width: 150,
  child: Stack(
    fit: StackFit.expand,
    children: [
      picture,
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Colors.white, Color(0x00FFFFFF)],
            stops: [0.0, 0.7],
          ),
        ),
      ),
    ],
  ),
);

Widget _roleCard(String t, String sub, Widget picture, {bool on = false}) => Container(
  height: 132,
  margin: const EdgeInsets.only(bottom: 12),
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: on ? K.teal : K.line, width: on ? 2 : 1),
    boxShadow: on
        ? [BoxShadow(color: K.teal.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6))]
        : null,
  ),
  child: Row(
    children: [
      const SizedBox(width: 18),
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: on ? K.teal : K.line, width: on ? 7 : 2),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: tx(24, w: bold)),
            gap(2),
            Text(sub, style: tx(13, c: K.muted, h: 1.4)),
          ],
        ),
      ),
      _fadePicture(picture),
    ],
  ),
);

Widget vWho2() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: btn('التالي', wide: true, v: 16, fs: 17),
  ),
  children: [
    gap(14),
    Center(child: wordmark(s: 28)),
    gap(26),
    Text('مين أنت؟', style: tx(30, w: bold)),
    gap(4),
    Text('نرتب لك خطة على قدك', style: tx(16, c: K.muted)),
    gap(22),
    _roleCard(
      'العريس',
      'عرس الرجال، والمهر،\nوضيوفك ومزودينك',
      Image.memory(
        File('test/prototype/v3/assets/groom.jpg').readAsBytesSync(),
        fit: BoxFit.cover,
        alignment: const Alignment(0.2, 0.1),
      ),
      on: true,
    ),
    _roleCard(
      'العروسة',
      'تجهيزك وعرس النساء،\nفي مسارك الخاص',
      const CustomPaint(painter: _Lace()),
    ),
    gap(6),
    for (final r in const [
      (LucideIcons.users, 'من الأهل', 'عندي رابط دعوة'),
      (LucideIcons.store, 'مزود خدمة', 'قاعة، فرقة، تصوير، زينة'),
    ])
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          children: [
            Icon(r.$1, size: 19, color: K.muted),
            const SizedBox(width: 12),
            Text(r.$2, style: tx(15.5, w: bold)),
            const SizedBox(width: 8),
            Text(r.$3, style: tx(13, c: K.muted)),
            const Spacer(),
            const Icon(LucideIcons.chevronLeft, size: 17, color: K.faint),
          ],
        ),
      ),
  ],
);

// ============================================================ الأنوار

/// Night hero for the wedding week: one strand lights up per night.
Widget lightsHero({int lit = 4, int nights = 7, String big = '3', String unit = 'ليالي على زفافك'}) =>
    Container(
      height: 214,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_night, K.tealDark],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: Lights(strands: nights, lit: lit, cross: false)),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00064B47), K.tealDark],
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(big, style: tx(52, w: bold, c: Colors.white, h: 1)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(unit, style: tx(17, w: bold, c: Colors.white)),
                    ),
                  ],
                ),
                Text('كل ليلة تنوّر حبل · $lit من $nights', style: tx(13, c: _warm)),
              ],
            ),
          ),
        ],
      ),
    );

Widget vLightsHome() {
  Widget night(String day, String n, String name, String where, {bool done = false, bool today = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: today ? _night : (done ? K.bg : K.tealSoft),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(day, style: tx(11, c: today ? _warm : K.muted)),
              Text(n, style: tx(18, w: bold, c: today ? Colors.white : (done ? K.faint : K.teal))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(16, w: bold, c: done ? K.faint : K.ink)),
              Text(where, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        if (today) tag('الليلة', K.saffronInk, K.saffronSoft),
        if (done) const Icon(LucideIcons.checkCircle2, size: 18, color: K.green),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(hello: 'أسبوع عرسك يا محمد'),
      gap(14),
      lightsHero(),
      gap(12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.saffronSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(LucideIcons.lightbulb, color: K.saffronInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text('زينة البيت اتركّبت، وتشتغل الليلة من المغرب',
                  style: tx(14, w: bold, c: K.saffronInk)),
            ),
          ],
        ),
      ),
      sectionTitle('ليالي العرس', action: 'البرنامج'),
      whiteList([
        night('الأحد', '17', 'تركيب الزينة', 'قدام البيت · زينة الأنوار', done: true),
        night('الثلاثاء', '19', 'السمرة', 'الديوان · بعد العشاء', today: true),
        night('الأربعاء', '20', 'المقيل', 'بيت الوالد · بعد الظهر'),
        night('الخميس', '21', 'الزفاف والألعاب النارية', 'قاعة سبأ · ثم قدام البيت'),
      ]),
    ],
  );
}

Widget vDecorProviders() {
  Widget card(String name, String what, String price, double rating, int lit) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    decoration: card2(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 120,
          color: _night,
          child: CustomPaint(painter: Lights(strands: 9, lit: lit, apexY: 0.06)),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: tx(16.5, w: bold)),
                    Text(what, style: tx(13, c: K.muted)),
                    gap(4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: K.saffron),
                        Text(' $rating', style: tx(13.5, w: bold)),
                        Text(' · فاضي يوم 17', style: tx(13, c: K.green)),
                      ],
                    ),
                  ],
                ),
              ),
              Text(price, style: tx(15, w: bold, c: K.sky)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader('المزودين', 'محجوز 3 من 6', actions: [LucideIcons.search]),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final c in const ['الكل', 'زينة البيت', 'الألعاب النارية', 'القاعات', 'الفرق'])
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: chip(c, on: c == 'زينة البيت', onBg: K.sky, bg: Colors.white),
              ),
          ],
        ),
      ),
      gap(10),
      Text('تركيب قبل السمرة وفك بعد العرس · يغطون صنعاء', style: tx(13, c: K.muted)),
      gap(12),
      card('زينة الأنوار', 'حبال لمبات للعمارة والشارع · تركيب وفك', '80 - 150 ألف', 4.8, 9),
      card('نجمة الأفراح', 'خيمة لمبات من السطح · ألوان', '120 - 200 ألف', 4.6, 6),
    ],
  );
}

BoxDecoration card2() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22));

Widget vFireworksTask() {
  Widget step(String s, bool done) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(done ? LucideIcons.checkCircle2 : LucideIcons.circle, size: 20, color: done ? K.green : K.faint),
        const SizedBox(width: 10),
        Expanded(child: Text(s, style: tx(15, c: done ? K.muted : K.ink))),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('خلصت', wide: true, v: 16, fs: 17, bg: K.green, icon: LucideIcons.check),
    ),
    children: [
      subHeader('الألعاب النارية', sub: 'ليلة الزفاف · قدام البيت'),
      Container(
        height: 120,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: _night, borderRadius: BorderRadius.circular(22)),
        child: const CustomPaint(painter: _Burst()),
      ),
      gap(12),
      Box(
        child: Column(
          children: [
            for (final r in const [
              (LucideIcons.user, 'مسؤول عنها', 'صالح بس'),
              (LucideIcons.clock, 'متى', 'الخميس بعد العشاء'),
              (LucideIcons.wallet, 'البند', 'الألعاب النارية · 150 ألف'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(r.$1, size: 18, color: K.saffronInk),
                    const SizedBox(width: 10),
                    SizedBox(width: 82, child: Text(r.$2, style: tx(14, c: K.muted))),
                    Expanded(child: Text(r.$3, style: tx(15, w: bold))),
                  ],
                ),
              ),
          ],
        ),
      ),
      sectionTitle('خطوات صغيرة'),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            step('اتفق مع المحل على الكمية', true),
            step('حدد مكان بعيد عن الضيوف والسيارات', false),
            step('بعيد عن حبال الزينة', false),
          ],
        ),
      ),
      gap(12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.coralSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.shieldAlert, size: 19, color: K.coral),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'واحد بس يشعّلها، والأطفال بعيد. انتبهوا للعيون والأيدي، فرحتك ما تستاهل إصابة.',
                style: tx(13.5, w: bold, c: K.coral, h: 1.5),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Burst extends CustomPainter {
  const _Burst();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    for (final b in [
      (Offset(size.width * 0.28, size.height * 0.45), K.saffron, 44.0),
      (Offset(size.width * 0.66, size.height * 0.38), _warm, 52.0),
      (Offset(size.width * 0.86, size.height * 0.62), K.tealMid, 30.0),
    ]) {
      for (var i = 0; i < 26; i++) {
        final a = i * 2 * math.pi / 26 + rnd.nextDouble() * 0.1;
        final r = b.$3 * (0.75 + rnd.nextDouble() * 0.25);
        final p = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = b.$2.withValues(alpha: 0.8);
        final from = b.$1 + Offset(math.cos(a), math.sin(a)) * r * 0.35;
        final to = b.$1 + Offset(math.cos(a), math.sin(a)) * r;
        canvas.drawLine(from, to, p);
        canvas.drawCircle(to, 1.6, Paint()..color = b.$2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
