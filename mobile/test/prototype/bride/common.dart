// Bride journey prototype: shared look. Same Firuz identity and the same five
// tabs as the groom, with a rose-and-pearl mood for the bride's own plan.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import '../v3/lights.dart' show Lights;

class B {
  static const rose = Color(0xFFB4536A);
  static const roseDark = Color(0xFF7A2E45);
  static const roseSoft = Color(0xFFF8E4EA);
  static const pearl = Color(0xFFF7F2EA);
  static const gold = Color(0xFFB8862E);
  static const goldSoft = Color(0xFFF6EBD3);
  static const plum = Color(0xFF2E1624);
  static const plumMid = Color(0xFF5A2840);
}

/// Bride home header: her name, the wedding, and a private-plan lock.
Widget brideHeader({String hello = 'أهلًا سلمى'}) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hello, style: tx(24, w: bold)),
            Row(
              children: [
                const Icon(LucideIcons.lock, size: 13, color: K.muted),
                const SizedBox(width: 4),
                Text('خطتك خاصة · صنعاء', style: tx(14, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
      Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(LucideIcons.bell, size: 20, color: K.ink),
          ),
          Positioned(top: 10, left: 12, child: dot(B.rose)),
        ],
      ),
      const SizedBox(width: 8),
      avatar('س', B.rose, s: 44),
    ],
  ),
);

/// Countdown hero. Normal days: rose dawn with the qamariya. Wedding week:
/// a plum night over the women's hall, one strand lit per day.
Widget brideHero({
  required String big,
  required String unit,
  required String sub,
  required String moment,
  required int at,
  bool night = false,
  int lit = 0,
  double h = 200,
}) => Container(
  height: h,
  margin: const EdgeInsets.only(top: 16),
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(28),
    gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: night ? const [B.plum, B.plumMid] : const [B.rose, B.roseDark],
    ),
  ),
  child: Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(
        painter: night
            ? Lights(strands: 7, lit: lit, apexY: 0.04)
            : const QamariyaMark(alpha: 0.12),
      ),
      if (night)
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x002E1624), B.plum],
              ),
            ),
          ),
        ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(big, style: tx(big.length > 3 ? 44 : 60, w: bold, c: Colors.white, h: 0.95)),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit, style: tx(18, w: bold, c: Colors.white)),
                        Text(sub, style: tx(13.5, c: Colors.white70)),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: B.goldSoft, borderRadius: BorderRadius.circular(20)),
                  child: Text(moment, style: tx(13, w: bold, c: B.gold)),
                ),
              ],
            ),
            gap(14),
            segments(5, at, on: Colors.white, now: B.goldSoft, off: Colors.white.withValues(alpha: 0.22)),
          ],
        ),
      ),
    ],
  ),
);

/// The bride's next step: same anatomy as the groom's, in rose.
Widget brideNext({
  required String when,
  required String title,
  required String sub,
  required String why,
  required String action,
  String? second,
  IconData icon = LucideIcons.calendarDays,
  Color fg = B.rose,
  Color soft = B.roseSoft,
}) => Box(
  pad: const EdgeInsets.all(18),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      iconTile(icon, fg, soft, s: 48, r: 16),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخطوة الجاية · $when', style: tx(13, w: bold, c: fg)),
            gap(4),
            Text(title, style: tx(18.5, w: bold)),
            Text(sub, style: tx(14, c: K.muted)),
            gap(8),
            Row(
              children: [
                const Icon(LucideIcons.sparkles, size: 14, color: B.rose),
                const SizedBox(width: 5),
                Expanded(child: Text(why, style: tx(12.5, w: bold, c: B.rose))),
              ],
            ),
            gap(14),
            Row(
              children: [
                btn(action, bg: B.rose),
                if (second != null) ...[
                  const SizedBox(width: 10),
                  btn(second, bg: K.bg, fg: K.muted),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);

Widget note(String s, {Color c = B.rose, Color bg = B.roseSoft, IconData i = LucideIcons.info}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(i, size: 18, color: c),
      const SizedBox(width: 10),
      Expanded(child: Text(s, style: tx(13.5, w: bold, c: c, h: 1.45))),
    ],
  ),
);

Widget kv(IconData i, String a, String b, {Color c = B.rose}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      Icon(i, size: 18, color: c),
      const SizedBox(width: 10),
      SizedBox(width: 78, child: Text(a, style: tx(14, c: K.muted))),
      Expanded(child: Text(b, style: tx(15, w: bold))),
    ],
  ),
);

Widget check(String s, {String? sub, bool done = false, Color c = B.rose, Widget? end}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  child: Row(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: done ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: done ? c : K.line, width: 2),
        ),
        child: done ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s, style: tx(15, w: bold, c: done ? K.muted : K.ink)),
            if (sub != null) Text(sub, style: tx(12.5, c: K.muted)),
          ],
        ),
      ),
      ?end,
    ],
  ),
);

/// Gold value with its weight, the way gold is actually counted.
Widget grams(String g, {Color c = B.gold}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
  decoration: BoxDecoration(color: B.goldSoft, borderRadius: BorderRadius.circular(9)),
  child: Text(g, style: tx(12.5, w: bold, c: c)),
);
