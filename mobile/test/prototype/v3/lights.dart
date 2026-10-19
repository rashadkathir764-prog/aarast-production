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

/// A wedding dress on a hanger, cropped like a boutique photo.
class _Dress extends CustomPainter {
  const _Dress();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3EEE6), Color(0xFFE7DFD2)],
        ).createShader(Offset.zero & size),
    );
    final cx = w * 0.55;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFB9AE9B);
    // Hanger.
    canvas.drawLine(Offset(cx, -2), Offset(cx, h * 0.06), ink..strokeWidth = 1.6);
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.22, h * 0.15)
        ..lineTo(cx, h * 0.06)
        ..lineTo(cx + w * 0.22, h * 0.15),
      ink,
    );
    ink.strokeWidth = 1;
    // Skirt: a full ball gown flowing past the card.
    final skirt = Path()
      ..moveTo(cx - w * 0.15, h * 0.52)
      ..cubicTo(cx - w * 0.28, h * 0.70, cx - w * 0.55, h * 0.95, cx - w * 0.70, h * 1.15)
      ..lineTo(cx + w * 0.70, h * 1.15)
      ..cubicTo(cx + w * 0.55, h * 0.95, cx + w * 0.28, h * 0.70, cx + w * 0.15, h * 0.52)
      ..close();
    canvas.drawShadow(skirt, const Color(0xFF8C7F6A), 6, false);
    canvas.drawPath(skirt, Paint()..color = Colors.white);
    final fold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFE4DDD0);
    for (final f in [-0.45, -0.25, -0.08, 0.08, 0.25, 0.45]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx + w * f * 0.25, h * 0.55)
          ..quadraticBezierTo(cx + w * f * 0.7, h * 0.8, cx + w * f * 1.3, h * 1.15),
        fold,
      );
    }
    // Lace flowers scattered on the skirt.
    final lace = Paint()..color = const Color(0xFFDCD3C4);
    final rnd = math.Random(5);
    for (var i = 0; i < 26; i++) {
      final t = rnd.nextDouble();
      final y = h * (0.6 + t * 0.5);
      final half = w * (0.15 + t * 0.5);
      final x = cx + (rnd.nextDouble() * 2 - 1) * half * 0.9;
      for (var p = 0; p < 5; p++) {
        final ang = p * 2 * math.pi / 5;
        canvas.drawCircle(Offset(x + math.cos(ang) * 2.6, y + math.sin(ang) * 2.6), 1.3, lace);
      }
    }
    // Bodice with a sweetheart neckline.
    final bodice = Path()
      ..moveTo(cx - w * 0.14, h * 0.24)
      ..quadraticBezierTo(cx - w * 0.07, h * 0.20, cx, h * 0.26)
      ..quadraticBezierTo(cx + w * 0.07, h * 0.20, cx + w * 0.14, h * 0.24)
      ..lineTo(cx + w * 0.15, h * 0.52)
      ..lineTo(cx - w * 0.15, h * 0.52)
      ..close();
    canvas.drawShadow(bodice, const Color(0xFF8C7F6A), 3, false);
    canvas.drawPath(bodice, Paint()..color = Colors.white);
    // Lace straps to the hanger.
    canvas.drawLine(Offset(cx - w * 0.13, h * 0.24), Offset(cx - w * 0.17, h * 0.14), ink);
    canvas.drawLine(Offset(cx + w * 0.13, h * 0.24), Offset(cx + w * 0.17, h * 0.14), ink);
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(Offset(cx - w * 0.1 + i * w * 0.025, h * (0.33 + (i % 3) * 0.04)), 1.2, lace);
    }
    // Pearl waistband.
    for (var x = cx - w * 0.15; x <= cx + w * 0.15; x += 5) {
      canvas.drawCircle(Offset(x, h * 0.52), 2.1, Paint()..color = const Color(0xFFFDFBF6));
      canvas.drawCircle(Offset(x, h * 0.52), 2.1, ink..strokeWidth = 0.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _groomPhoto() => Image.memory(
  File('test/prototype/v3/assets/groom.jpg').readAsBytesSync(),
  fit: BoxFit.cover,
  alignment: const Alignment(0.2, 0.1),
);

Widget _servicesArt() => Container(
  color: K.skySoft,
  child: Wrap(
    alignment: WrapAlignment.center,
    runAlignment: WrapAlignment.center,
    spacing: 14,
    runSpacing: 14,
    children: [
      for (final i in const [
        LucideIcons.building2,
        LucideIcons.music,
        LucideIcons.camera,
        LucideIcons.lightbulb,
        LucideIcons.utensils,
        LucideIcons.car,
      ])
        Icon(i, size: 24, color: K.sky.withValues(alpha: 0.75)),
    ],
  ),
);

/// First choice after the splash: plan a wedding, or offer a service.
Widget vStart() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: btn('التالي', wide: true, v: 16, fs: 17),
  ),
  children: [
    gap(14),
    Center(child: wordmark(s: 28)),
    gap(26),
    Text('أهلًا فيك', style: tx(30, w: bold)),
    gap(4),
    Text('وش تبغى تسوي؟', style: tx(16, c: K.muted)),
    gap(22),
    _roleCard(
      'أنشئ خطتك',
      'لعرسك أنت، عريس\nأو عروسة',
      weddingSky(strands: 7, lit: 7, bursts: const [(Offset(0.3, 0.3), K.saffron, 26.0)]),
      on: true,
    ),
    _roleCard(
      'مزود خدمة',
      'قاعة، فرقة، تصوير،\nزينة، ضيافة',
      _servicesArt(),
    ),
    gap(14),
    Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: K.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.link, size: 18, color: K.teal),
            const SizedBox(width: 10),
            Text('عندي رابط دعوة', style: tx(15.5, w: bold, c: K.teal)),
          ],
        ),
      ),
    ),
    gap(8),
    Center(
      child: Text('أحد ضافك في خطته؟ ادخل منه', style: tx(13, c: K.muted)),
    ),
  ],
);

/// Second step of creating a plan: whose wedding is this?
Widget vWhose() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: btn('التالي', wide: true, v: 16, fs: 17),
  ),
  children: [
    subHeader(''),
    gap(4),
    Text('خطة مين؟', style: tx(30, w: bold)),
    gap(4),
    Text('كل واحد له مساره، ويقدر يضيف الثاني مشارك', style: tx(15.5, c: K.muted)),
    gap(22),
    _roleCard('العريس', 'عرس الرجال، والمهر،\nوضيوفك ومزودينك', _groomPhoto(), on: true),
    _roleCard('العروسة', 'تجهيزك وعرس النساء،\nفي مسارك الخاص', const CustomPaint(painter: _Dress())),
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
      homeHeader(hello: 'باقي يومين يا محمد'),
      gap(14),
      bigHero(day: false),
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
        child: const CustomPaint(painter: Fireworks()),
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

/// Fireworks bursts: (centre as a fraction of the size, colour, radius).
class Fireworks extends CustomPainter {
  const Fireworks([this.bursts = _defaultBursts, this.alpha = 0.8]);
  final List<(Offset, Color, double)> bursts;
  final double alpha;

  static const _defaultBursts = [
    (Offset(0.28, 0.45), K.saffron, 44.0),
    (Offset(0.66, 0.38), _warm, 52.0),
    (Offset(0.86, 0.62), K.tealMid, 30.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(3);
    for (final b in bursts) {
      final c = Offset(b.$1.dx * size.width, b.$1.dy * size.height);
      canvas.drawCircle(c, b.$3 * 0.5, Paint()
        ..color = b.$2.withValues(alpha: alpha * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
      for (var i = 0; i < 28; i++) {
        final a = i * 2 * math.pi / 28 + rnd.nextDouble() * 0.1;
        final r = b.$3 * (0.75 + rnd.nextDouble() * 0.25);
        final p = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = b.$2.withValues(alpha: alpha);
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * r * 0.35, c + dir * r, p);
        canvas.drawCircle(c + dir * r, 1.6, Paint()..color = b.$2.withValues(alpha: alpha));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The wedding sky: night, fireworks behind, the lights tent in front.
Widget weddingSky({int strands = 11, int lit = 11, List<(Offset, Color, double)>? bursts, double fireAlpha = 0.8}) =>
    DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071C24), _night, K.tealDark],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: Fireworks(bursts ?? Fireworks._defaultBursts, fireAlpha)),
          CustomPaint(painter: Lights(strands: strands, lit: lit, apexY: 0.03)),
        ],
      ),
    );

Widget vSplash2() => Phone(
  statusLight: true,
  pad: false,
  bg: K.tealDark,
  children: [
    SizedBox(
      height: 790,
      child: Stack(
        fit: StackFit.expand,
        children: [
          weddingSky(
            strands: 13,
            bursts: const [
              (Offset(0.18, 0.13), K.saffron, 58.0),
              (Offset(0.82, 0.10), _warm, 64.0),
              (Offset(0.55, 0.30), K.tealMid, 40.0),
              (Offset(0.12, 0.42), _warm, 34.0),
              (Offset(0.88, 0.40), K.saffron, 38.0),
            ],
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00064B47), K.tealDark, K.tealDark],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 150,
            child: Column(
              children: [
                wordmark(s: 64, c: Colors.white),
                gap(12),
                Text('عرسك من أول ريال إلى آخر قسط',
                    style: tx(17, c: Colors.white.withValues(alpha: 0.82))),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 70,
            child: Center(
              child: SizedBox(
                width: 120,
                child: segments(3, 1, on: Colors.white, now: K.saffron,
                    off: Colors.white.withValues(alpha: 0.25), h: 4),
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);

/// The big hero for wedding mode: the whole sky behind the countdown.
Widget bigHero({required bool day}) => Container(
  height: 330,
  margin: const EdgeInsets.only(top: 16),
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
  child: Stack(
    fit: StackFit.expand,
    children: [
      weddingSky(
        strands: 7,
        lit: day ? 7 : 5,
        fireAlpha: day ? 0.9 : 0.45,
        bursts: day
            ? const [
                (Offset(0.15, 0.14), K.saffron, 46.0),
                (Offset(0.85, 0.12), _warm, 52.0),
                (Offset(0.50, 0.34), K.tealMid, 34.0),
                (Offset(0.88, 0.45), K.saffron, 30.0),
              ]
            : const [
                (Offset(0.16, 0.16), K.saffron, 34.0),
                (Offset(0.84, 0.13), _warm, 38.0),
              ],
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 170,
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
        left: 20,
        right: 20,
        bottom: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(day ? 'اليوم' : '2', style: tx(day ? 50 : 64, w: bold, c: Colors.white, h: 0.95)),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day ? 'يوم عرسك' : 'يوم على عرسك', style: tx(18, w: bold, c: Colors.white)),
                        Text(day ? '13 شعبان · الخميس' : 'كل ليلة تنوّر حبل · 5 من 7',
                            style: tx(13.5, c: _warm)),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: K.saffron, borderRadius: BorderRadius.circular(20)),
                  child: Text(day ? 'يوم العرس' : 'أسبوع العرس', style: tx(13, w: bold)),
                ),
              ],
            ),
            gap(14),
            segments(5, day ? 3 : 2, on: Colors.white, now: K.saffron,
                off: Colors.white.withValues(alpha: 0.22)),
          ],
        ),
      ),
    ],
  ),
);
