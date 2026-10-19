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
const _night = bride ? Color(0xFF2E1624) : Color(0xFF0E2A33);

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

/// A ball-gown wedding dress on a gold-capped mannequin, studio light:
/// beaded corset, pleated skirt full of sparkle, crystal drops and a veil.
class Dress extends CustomPainter {
  const Dress({this.veil = true});
  final bool veil;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(11);
    // Studio backdrop.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.1,
          colors: const [Color(0xFFF4F4F2), Color(0xFFDADAD6)],
        ).createShader(Offset.zero & size),
    );
    final cx = w * 0.5;
    final waistY = h * 0.47;
    final topY = h * 0.20;
    final bw = w * 0.17; // half bodice width at the bust
    final ww = w * 0.12; // half waist

    // Mannequin neck and gold cap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, h * 0.09), width: w * 0.09, height: h * 0.10), const Radius.circular(4)),
      Paint()..color = const Color(0xFFEDE7DC),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, h * 0.015), width: w * 0.11, height: h * 0.05), const Radius.circular(6)),
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFB8862E), Color(0xFFF1D489), Color(0xFFB8862E)])
            .createShader(Rect.fromLTWH(cx - w * 0.06, 0, w * 0.12, h * 0.05)),
    );
    // Shoulders of the form, just peeking above the bodice.
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.045, h * 0.13)
        ..quadraticBezierTo(cx - w * 0.06, topY - h * 0.01, cx - bw * 0.85, topY + h * 0.025)
        ..lineTo(cx + bw * 0.85, topY + h * 0.025)
        ..quadraticBezierTo(cx + w * 0.06, topY - h * 0.01, cx + w * 0.045, h * 0.13)
        ..close(),
      Paint()..color = const Color(0xFFEDE7DC),
    );

    // Skirt: wide ball gown, shaded like a cylinder, then pleats.
    final hemY = h * 1.25;
    final skirt = Path()
      ..moveTo(cx - ww, waistY)
      ..cubicTo(cx - w * 0.35, h * 0.62, cx - w * 0.75, h * 0.95, cx - w * 0.95, hemY)
      ..lineTo(cx + w * 0.95, hemY)
      ..cubicTo(cx + w * 0.75, h * 0.95, cx + w * 0.35, h * 0.62, cx + ww, waistY)
      ..close();
    canvas.drawShadow(skirt, Colors.black, 8, false);
    final skirtRect = Rect.fromLTRB(cx - w * 0.95, waistY, cx + w * 0.95, hemY);
    canvas.drawPath(
      skirt,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFCFCFD4), Colors.white, Color(0xFFFDFDFE), Color(0xFFC9C9CF)],
          stops: [0, 0.38, 0.6, 1],
        ).createShader(skirtRect),
    );
    canvas.save();
    canvas.clipPath(skirt);
    for (var i = -8; i <= 8; i++) {
      final f = i / 8;
      final end = Offset(cx + f * w * 1.0, hemY);
      final ctrl = Offset(cx + f * w * 0.35, h * 0.75);
      final from = Offset(cx + f * ww * 0.9, waistY);
      final pleat = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      canvas.drawPath(pleat, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = const Color(0xFF9EA0AA).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawPath(pleat.shift(Offset(w * 0.012, 0)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.9));
    }
    // Crystal drops hanging from the waist.
    for (var i = -6; i <= 6; i++) {
      final x0 = cx + i * w * 0.045;
      final len = h * (0.10 + rnd.nextDouble() * 0.16);
      for (var y = waistY + h * 0.02; y < waistY + len; y += h * 0.022) {
        final x = x0 + (x0 - cx) * (y - waistY) / h * 1.2;
        canvas.drawCircle(Offset(x, y), 1.3, Paint()..color = const Color(0xFFB9BCC6));
      }
      final tip = Offset(x0 + (x0 - cx) * len / h * 1.2, waistY + len);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy - 3)
          ..lineTo(tip.dx + 2.2, tip.dy + 1)
          ..lineTo(tip.dx, tip.dy + 5)
          ..lineTo(tip.dx - 2.2, tip.dy + 1)
          ..close(),
        Paint()..color = const Color(0xFFA9ADB9),
      );
    }
    // Sparkle across the skirt, denser near the waist.
    for (var i = 0; i < 260; i++) {
      final t = math.pow(rnd.nextDouble(), 0.8).toDouble();
      final y = waistY + t * (hemY - waistY);
      final half = ww + (w * 0.95 - ww) * math.pow(t, 0.7);
      final x = cx + (rnd.nextDouble() * 2 - 1) * half;
      final r = 0.5 + rnd.nextDouble() * 1.1;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFF9FA3AE).withValues(alpha: 0.75));
    }
    canvas.restore();

    // Bodice: strapless sweetheart corset.
    final bodice = Path()
      ..moveTo(cx - bw, topY + h * 0.03)
      ..quadraticBezierTo(cx - bw * 0.5, topY - h * 0.025, cx, topY + h * 0.04)
      ..quadraticBezierTo(cx + bw * 0.5, topY - h * 0.025, cx + bw, topY + h * 0.03)
      ..quadraticBezierTo(cx + bw * 0.92, h * 0.36, cx + ww, waistY)
      ..lineTo(cx, waistY + h * 0.03)
      ..lineTo(cx - ww, waistY)
      ..quadraticBezierTo(cx - bw * 0.92, h * 0.36, cx - bw, topY + h * 0.03)
      ..close();
    canvas.drawShadow(bodice, Colors.black, 4, false);
    canvas.drawPath(
      bodice,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFD3D3D8), Colors.white, Color(0xFFD0D0D6)],
        ).createShader(Rect.fromLTRB(cx - bw, topY, cx + bw, waistY)),
    );
    canvas.save();
    canvas.clipPath(bodice);
    // Boning seams lined with beads, and a beaded V to the waist.
    for (final f in [-0.62, -0.25, 0.25, 0.62]) {
      for (var y = topY + h * 0.03; y < waistY; y += h * 0.016) {
        final k = (y - topY) / (waistY - topY);
        canvas.drawCircle(Offset(cx + f * (bw + (ww - bw) * k), y), 0.9, Paint()..color = const Color(0xFF9EA2AD));
      }
    }
    for (var i = 0; i < 70; i++) {
      final k = rnd.nextDouble();
      final y = topY + h * 0.04 + k * (waistY - topY - h * 0.04);
      final spread = (bw * (1 - k) + ww * k) * 0.9;
      canvas.drawCircle(
        Offset(cx + (rnd.nextDouble() * 2 - 1) * spread, y),
        0.6 + rnd.nextDouble() * 0.8,
        Paint()..color = const Color(0xFFA6AAB5),
      );
    }
    canvas.restore();
    // Highlights: a few glints with soft glow.
    for (var i = 0; i < 16; i++) {
      final k = rnd.nextDouble();
      final y = waistY - h * 0.2 + k * h * 0.7;
      final half = y < waistY ? bw * 0.8 : ww + (y - waistY) * 1.1;
      final p = Offset(cx + (rnd.nextDouble() * 2 - 1) * half, y);
      canvas.drawCircle(p, 3.2, Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      final g = Paint()
        ..color = Colors.white
        ..strokeWidth = 0.8;
      canvas.drawLine(p - const Offset(4, 0), p + const Offset(4, 0), g);
      canvas.drawLine(p - const Offset(0, 4), p + const Offset(0, 4), g);
    }

    // Veil: sheer tulle falling from the crown to one side.
    if (veil) {
      final v = Path()
        ..moveTo(cx - w * 0.03, h * 0.02)
        ..cubicTo(cx - w * 0.30, h * 0.15, cx - w * 0.42, h * 0.55, cx - w * 0.62, h * 1.1)
        ..lineTo(cx - w * 0.20, h * 1.1)
        ..cubicTo(cx - w * 0.28, h * 0.6, cx - w * 0.18, h * 0.25, cx + w * 0.02, h * 0.04)
        ..close();
      canvas.drawPath(v, Paint()..color = Colors.white.withValues(alpha: 0.38));
      canvas.drawPath(v, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFFBFC2CA).withValues(alpha: 0.6));
      canvas.save();
      canvas.clipPath(v);
      for (var i = 0; i < 40; i++) {
        canvas.drawCircle(
          Offset(cx - w * (0.05 + rnd.nextDouble() * 0.5), h * (0.1 + rnd.nextDouble() * 0.95)),
          0.7,
          Paint()..color = const Color(0xFFB0B4BE),
        );
      }
      canvas.restore();
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
    child: btn('أنشئ حسابي', wide: true, v: 16, fs: 17),
  ),
  children: [
    gap(14),
    Center(child: wordmark(s: 28)),
    gap(26),
    Text('أهلًا فيك', style: tx(30, w: bold)),
    gap(4),
    Text('جديد في اعّرست؟ اختر وش تبغى', style: tx(16, c: K.muted)),
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
    gap(6),
    // One account for everyone: the phone number finds the plan or the
    // provider page, whichever it already has.
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: K.line),
      ),
      child: Row(
        children: [
          iconTile(LucideIcons.logIn, K.teal, K.tealSoft, s: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عندي حساب', style: tx(17, w: bold)),
                Text('ادخل برقم جوالك: عريس، عروسة، أو مزود', style: tx(13, c: K.muted)),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronLeft, size: 18, color: K.faint),
        ],
      ),
    ),
    gap(16),
    Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.link, size: 17, color: K.teal),
          const SizedBox(width: 8),
          Text('عندي رابط دعوة', style: tx(15, w: bold, c: K.teal)),
          Text('  ·  أحد ضافك في خطته', style: tx(13, c: K.muted)),
        ],
      ),
    ),
  ],
);

/// Second step of creating a plan: whose wedding is this?
/// [brideChosen] is the screen's own state: which card is ticked.
Widget vWhose({bool brideChosen = false}) => Phone(
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
    _roleCard('العريس', 'عرس الرجال، والمهر،\nوضيوفك ومزودينك', _groomPhoto(), on: !brideChosen),
    // Temporary stand-in until the brother's own dress photo arrives.
    _roleCard(
      'العروسة',
      'تجهيزك وعرس النساء،\nفي مسارك الخاص',
      Image.memory(
        File('test/prototype/v3/assets/bride_placeholder.jpg').readAsBytesSync(),
        fit: BoxFit.cover,
        alignment: const Alignment(-0.4, 0),
      ),
      on: brideChosen,
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
          colors: [(bride ? Color(0xFF1E0E18) : Color(0xFF071C24)), _night, K.tealDark],
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
