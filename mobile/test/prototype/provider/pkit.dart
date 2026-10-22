// Provider journey prototype: shared parts. The provider's app uses the
// groom journey's teal, whether the provider serves men, women or both. The
// status colours (green, saffron, coral) keep their meaning from the plan side.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

class P {
  static const c = Color(0xFF0B6E69); // the groom's teal
  static const dark = Color(0xFF064B47);
  static const soft = Color(0xFFDCEFEC);
  static const mid = Color(0xFF7FC3BC);
}

enum PTab {
  home('الرئيسية', LucideIcons.home),
  requests('الطلبات', LucideIcons.inbox),
  calendar('التقويم', LucideIcons.calendarDays),
  chats('الرسائل', LucideIcons.messageCircle),
  me('ملفي', LucideIcons.store);

  const PTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

Widget pNav(PTab active, {int badge = 0}) => Container(
  margin: const EdgeInsets.fromLTRB(14, 4, 14, 22),
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: K.line),
  ),
  child: Row(
    children: [
      for (final t in PTab.values)
        if (t == active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: P.c, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Icon(t.icon, size: 19, color: Colors.white),
                const SizedBox(width: 6),
                Text(t.label, style: tx(14, w: bold, c: Colors.white)),
              ],
            ),
          )
        else
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Column(
                  children: [
                    Icon(t.icon, size: 21, color: K.faint),
                    const SizedBox(height: 3),
                    Text(t.label, style: tx(11.5, c: K.muted)),
                  ],
                ),
                if (badge > 0 && t == PTab.requests)
                  Positioned(
                    top: -4,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: K.coral, borderRadius: BorderRadius.circular(9)),
                      child: Text('$badge', style: tx(11, w: bold, c: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
    ],
  ),
);

/// A provider screen: content, an optional action bar, and the tab bar.
Widget pPhone({
  required List<Widget> children,
  PTab? tab,
  Widget? action,
  Widget? sheet,
  int badge = 0,
}) => Phone(
  sheet: sheet,
  bottom: (tab == null && action == null)
      ? null
      : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action != null) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: action),
            if (tab != null) pNav(tab, badge: badge) else const SizedBox(height: 18),
          ],
        ),
  children: children,
);

Widget pBtn(String s, {IconData? icon, bool wide = true, Color bg = P.c, Color fg = Colors.white, double v = 16, double fs = 17}) =>
    btn(s, bg: bg, fg: fg, icon: icon, wide: wide, v: v, fs: fs);

Widget pGhost(String s, {IconData? icon, bool wide = true, double v = 15, Color fg = K.muted}) =>
    btn(s, bg: Colors.white, fg: fg, icon: icon, wide: wide, v: v, fs: 15);

Widget pSoft(String s, {Color fg = P.c, Color bg = P.soft}) => softAction(s, fg: fg, bg: bg);

Widget pField(String label, String value, {IconData? icon, bool focused = false, String? suffix, String? note}) => Container(
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: note != null ? K.coral : (focused ? P.c : K.line), width: focused || note != null ? 2 : 1),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: K.muted), const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tx(12.5, c: K.muted)),
                Text(value, style: tx(16.5, w: bold)),
              ],
            ),
          ),
          if (suffix != null) Text(suffix, style: tx(14.5, w: bold, c: K.muted)),
        ],
      ),
      if (note != null) ...[
        gap(8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: K.coralSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.messageSquare, size: 16, color: K.coral),
              const SizedBox(width: 8),
              Expanded(child: Text(note, style: tx(13, w: bold, c: K.coral, h: 1.45))),
            ],
          ),
        ),
      ],
    ],
  ),
);

Widget pNote(String s, {Color c = P.c, Color bg = P.soft, IconData i = LucideIcons.info}) => Container(
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

Widget pToggle(bool on) => Container(
  width: 46,
  height: 28,
  padding: const EdgeInsets.all(3),
  alignment: on ? Alignment.centerLeft : Alignment.centerRight,
  decoration: BoxDecoration(color: on ? P.c : K.line, borderRadius: BorderRadius.circular(999)),
  child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
);

Widget pOption(String s, {String? sub, bool on = false, IconData? icon}) => Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: on ? P.c : K.line, width: on ? 2 : 1),
  ),
  child: Row(
    children: [
      if (icon != null) ...[iconTile(icon, P.c, P.soft, s: 42), const SizedBox(width: 12)],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s, style: tx(15, w: bold)),
            if (sub != null) Text(sub, style: tx(13, c: K.muted, h: 1.4)),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: on ? P.c : K.line, width: on ? 7 : 2),
        ),
      ),
    ],
  ),
);

Widget pChip(String s, {bool on = false, IconData? icon}) => chip(s, on: on, onBg: P.c, fs: 13, icon: icon);

Widget pSteps(List<String> labels, int at) => Container(
  padding: const EdgeInsets.all(6),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: K.line)),
  child: Row(
    children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == at ? P.c : (i < at ? P.soft : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(labels[i], style: tx(12, w: bold, c: i == at ? Colors.white : (i < at ? P.c : K.muted))),
          ),
        ),
    ],
  ),
);

/// Status words used everywhere on the provider side, one colour each.
Widget st(String s) {
  const m = {
    'جديد': (K.coral, K.coralSoft),
    'ينتظر ردك': (K.coral, K.coralSoft),
    'ردّيت': (K.sky, K.skySoft),
    'قبلوا عرضك': (K.saffronInk, K.saffronSoft),
    'ينتظر تأكيدك': (K.saffronInk, K.saffronSoft),
    'محجوز': (K.green, K.greenSoft),
    'مبدئي': (K.lilac, K.lilacSoft),
    'من برا': (P.c, P.soft),
    'تم': (K.green, K.greenSoft),
    'انتهى': (K.muted, K.line),
    'اعتذرت': (K.muted, K.line),
    'ملغي': (K.muted, K.line),
    'جاهز': (K.sky, K.skySoft),
    'تسلّم': (K.green, K.greenSoft),
    'فاضي': (K.green, K.greenSoft),
  };
  final c = m[s] ?? (P.c, P.soft);
  return tag(s, c.$1, c.$2);
}

Widget pTop(String title, String sub, {List<IconData> icons = const []}) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: tx(27, w: bold)), Text(sub, style: tx(14.5, c: K.muted))],
        ),
      ),
      for (final i in icons) ...[
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(i, size: 20, color: K.ink),
        ),
      ],
    ],
  ),
);

/// The provider's identity row: logo letter, name, kind.
Widget pBiz({String l = 'ل', String name = 'استوديو ضوء صنعاء', String kind = 'تصوير · صنعاء · 4 فرق'}) => Row(
  children: [
    Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: P.c, borderRadius: BorderRadius.circular(14)),
      child: Text(l, style: tx(20, w: bold, c: Colors.white)),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(name, style: tx(17, w: bold)), Text(kind, style: tx(13, c: K.muted))],
      ),
    ),
  ],
);

Widget kv(String a, String b, {Color c = K.ink}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 92, child: Text(a, style: tx(13.5, c: K.muted))),
      Expanded(child: Text(b, style: tx(14.5, w: bold, c: c))),
    ],
  ),
);

Widget eff(IconData i, String s, {Color c = K.muted}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(i, size: 18, color: c),
      const SizedBox(width: 10),
      Expanded(child: Text(s, style: tx(14.5, h: 1.45))),
    ],
  ),
);
