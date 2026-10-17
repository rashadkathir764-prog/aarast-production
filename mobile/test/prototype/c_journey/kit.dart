// Throwaway design prototype kit for direction C ("فيروز").
// Not product code: it exists to draw the groom's journey for review.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

const fTaj = 'Tajawal';
const fPlex = 'IBMPlexSansArabic';

class K {
  static const bg = Color(0xFFF2F4F3);
  static const surface = Colors.white;
  static const ink = Color(0xFF13211F);
  static const muted = Color(0xFF55625E);
  static const faint = Color(0xFF8A9592);
  static const line = Color(0xFFE2E7E5);

  static const teal = Color(0xFF0B6E69);
  static const tealDark = Color(0xFF064B47);
  static const tealSoft = Color(0xFFDCEFEC);
  static const tealMid = Color(0xFF7FC3BC);

  static const saffron = Color(0xFFF2A93B);
  static const saffronInk = Color(0xFFA9680F);
  static const saffronSoft = Color(0xFFFCEFD8);

  static const lilac = Color(0xFF6A4FA3);
  static const lilacSoft = Color(0xFFECE6F6);

  static const sky = Color(0xFF2F6E9E);
  static const skySoft = Color(0xFFE0EEF8);

  static const coral = Color(0xFFD9583B);
  static const coralSoft = Color(0xFFFBE5DF);

  static const green = Color(0xFF2E8A5E);
  static const greenSoft = Color(0xFFDDF1E6);
}

TextStyle tx(
  double s, {
  FontWeight w = FontWeight.w400,
  Color c = K.ink,
  double h = 1.35,
  String f = fTaj,
}) => TextStyle(fontFamily: f, fontSize: s, fontWeight: w, color: c, height: h);

const bold = FontWeight.w700;

/// Keeps phone numbers and other LTR runs in order inside RTL text.
String ltr(String s) => '\u2066$s\u2069';

/// The four sections and their colours: a section keeps its colour everywhere.
enum Sec {
  home('الرئيسية', LucideIcons.home, K.teal, K.tealSoft),
  money('المال', LucideIcons.wallet, K.teal, K.tealSoft),
  tasks('المهام', LucideIcons.listChecks, K.saffronInk, K.saffronSoft),
  guests('الضيوف', LucideIcons.users, K.lilac, K.lilacSoft),
  providers('المزودين', LucideIcons.store, K.sky, K.skySoft);

  const Sec(this.label, this.icon, this.color, this.soft);
  final String label;
  final IconData icon;
  final Color color, soft;
}

// ------------------------------------------------------------------ frame

class Phone extends StatelessWidget {
  const Phone({
    super.key,
    required this.children,
    this.nav,
    this.bg = K.bg,
    this.gradient,
    this.bottom,
    this.sheet,
    this.statusLight = false,
    this.pad = true,
  });

  final List<Widget> children;
  final Sec? nav;
  final Color bg;
  final Gradient? gradient;
  final Widget? bottom;
  final Widget? sheet;
  final bool statusLight;
  final bool pad;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(color: bg, gradient: gradient),
      child: Column(
        children: [
          StatusBar(light: statusLight),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...children, const SizedBox(height: 20)],
                ),
              ),
            ),
          ),
          ?bottom,
          if (nav != null) NavBar(active: nav!),
        ],
      ),
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: sheet == null
          ? content
          : Stack(
              children: [
                content,
                Positioned.fill(
                  child: Container(color: K.ink.withValues(alpha: 0.42)),
                ),
                Align(alignment: Alignment.bottomCenter, child: sheet),
              ],
            ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : K.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 6),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Text(
              '9:41',
              style: tx(15, w: bold, c: c, f: fPlex),
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
  }
}

class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.active});
  final Sec active;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 4, 14, 22),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: K.line),
    ),
    child: Row(
      children: [
        for (final s in Sec.values)
          if (s == active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: s.color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(s.icon, size: 19, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: tx(14, w: bold, c: Colors.white),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Icon(s.icon, size: 21, color: K.faint),
                  const SizedBox(height: 3),
                  Text(s.label, style: tx(11.5, c: K.muted)),
                ],
              ),
            ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ parts

Widget gap(double h) => SizedBox(height: h);

BoxDecoration card({Color c = K.surface, double r = 22, Color? border}) =>
    BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(r),
      border: border == null ? null : Border.all(color: border, width: 2),
    );

class Box extends StatelessWidget {
  const Box({
    super.key,
    required this.child,
    this.c = K.surface,
    this.pad = const EdgeInsets.all(16),
    this.r = 22,
    this.border,
  });
  final Widget child;
  final Color c;
  final EdgeInsets pad;
  final double r;
  final Color? border;
  @override
  Widget build(BuildContext context) => Container(
    padding: pad,
    decoration: card(c: c, r: r, border: border),
    child: child,
  );
}

Widget iconTile(
  IconData i,
  Color fg,
  Color bg, {
  double s = 44,
  double r = 14,
}) => Container(
  width: s,
  height: s,
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(r)),
  child: Icon(i, size: s * 0.45, color: fg),
);

Widget btn(
  String label, {
  Color bg = K.teal,
  Color fg = Colors.white,
  IconData? icon,
  bool wide = false,
  double v = 12,
  double fs = 15,
}) => Container(
  width: wide ? double.infinity : null,
  padding: EdgeInsets.symmetric(horizontal: 18, vertical: v),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
  child: Row(
    mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 8),
      ],
      Text(
        label,
        style: tx(fs, w: bold, c: fg),
      ),
    ],
  ),
);

Widget chip(
  String label, {
  Color bg = K.surface,
  Color fg = K.ink,
  bool on = false,
  Color onBg = K.teal,
  IconData? icon,
  double fs = 14,
}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  decoration: BoxDecoration(
    color: on ? onBg : bg,
    borderRadius: BorderRadius.circular(14),
    border: on ? null : Border.all(color: K.line),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: on ? Colors.white : fg),
        const SizedBox(width: 6),
      ],
      Text(
        label,
        style: tx(fs, w: bold, c: on ? Colors.white : fg),
      ),
    ],
  ),
);

Widget tag(String label, Color fg, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
  child: Text(
    label,
    style: tx(12, w: bold, c: fg),
  ),
);

Widget bar(double v, Color fg, {Color bg = K.line, double h = 6}) => ClipRRect(
  borderRadius: BorderRadius.circular(h),
  child: SizedBox(
    height: h,
    child: Row(
      children: [
        Expanded(
          flex: (v * 1000).round(),
          child: Container(color: fg),
        ),
        Expanded(
          flex: ((1 - v) * 1000).round(),
          child: Container(color: bg),
        ),
      ],
    ),
  ),
);

/// Segmented steps bar: [done] filled, the current one in [now] colour.
Widget segments(
  int total,
  int done, {
  Color on = K.teal,
  Color now = K.saffron,
  Color off = K.line,
  double h = 6,
}) => Row(
  children: [
    for (var i = 0; i < total; i++)
      Expanded(
        child: Container(
          height: h,
          margin: EdgeInsetsDirectional.only(end: i == total - 1 ? 0 : 5),
          decoration: BoxDecoration(
            color: i < done
                ? on
                : i == done
                ? now
                : off,
            borderRadius: BorderRadius.circular(h),
          ),
        ),
      ),
  ],
);

/// Money split bar: paid / in hand / gap.
Widget moneyBar(double paid, double have, double gapV, {double h = 10}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: h,
        child: Row(
          children: [
            Expanded(
              flex: (paid * 100).round(),
              child: Container(color: K.teal),
            ),
            const SizedBox(width: 3),
            Expanded(
              flex: (have * 100).round(),
              child: Container(color: K.tealMid),
            ),
            const SizedBox(width: 3),
            Expanded(
              flex: (gapV * 100).round(),
              child: Container(color: K.coral),
            ),
          ],
        ),
      ),
    );

Widget dot(Color c, [double s = 8]) => Container(
  width: s,
  height: s,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);

/// Header for a main tab: big title, a status line, and round actions.
Widget tabHeader(
  String title,
  String status, {
  Sec sec = Sec.home,
  List<IconData> actions = const [],
}) => Padding(
  padding: const EdgeInsets.fromLTRB(6, 8, 6, 14),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tx(28, w: bold)),
            gap(2),
            Text(status, style: tx(15, c: K.muted)),
          ],
        ),
      ),
      for (final a in actions) ...[
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(a, size: 20, color: K.ink),
        ),
      ],
    ],
  ),
);

/// Header for a pushed screen: back arrow and title.
Widget subHeader(String title, {String? sub, Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
  child: Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.arrowRight, size: 20, color: K.ink),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tx(20, w: bold)),
            if (sub != null) Text(sub, style: tx(13.5, c: K.muted)),
          ],
        ),
      ),
      ?trailing,
    ],
  ),
);

/// Pill tabs at the top of a section.
Widget topTabs(List<String> labels, int active, {Color c = K.teal}) =>
    Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == active ? c : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[i],
                  style: tx(
                    13.5,
                    w: bold,
                    c: i == active ? Colors.white : K.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

Widget sectionTitle(String s, {String? action, Color ac = K.teal}) => Padding(
  padding: const EdgeInsets.fromLTRB(6, 20, 6, 10),
  child: Row(
    children: [
      Expanded(
        child: Text(s, style: tx(17, w: bold)),
      ),
      if (action != null)
        Text(
          action,
          style: tx(14, w: bold, c: ac),
        ),
    ],
  ),
);

/// A "next step" card, the single most important action in a section.
Widget nextCard({
  required String eyebrow,
  required String title,
  required String sub,
  required String action,
  String? second,
  IconData icon = LucideIcons.calendarDays,
  Color fg = K.saffronInk,
  Color soft = K.saffronSoft,
  Color actionBg = K.teal,
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
            Text(
              eyebrow,
              style: tx(13, w: bold, c: fg),
            ),
            gap(2),
            Text(title, style: tx(18.5, w: bold)),
            Text(sub, style: tx(14, c: K.muted)),
            gap(14),
            Row(
              children: [
                btn(action, bg: actionBg),
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

/// A row in a white list: icon, title, sub, trailing widget.
Widget listRow({
  required IconData icon,
  required Color fg,
  required Color soft,
  required String title,
  required String sub,
  Widget? trailing,
  double iconSize = 42,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  child: Row(
    children: [
      iconTile(icon, fg, soft, s: iconSize),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tx(15.5, w: bold)),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx(13, c: K.muted),
            ),
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 8), trailing],
    ],
  ),
);

Widget softAction(String s, {Color fg = K.teal, Color bg = K.tealSoft}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        s,
        style: tx(13.5, w: bold, c: fg),
      ),
    );

Widget whiteList(List<Widget> rows, {bool dividers = true}) => Container(
  padding: const EdgeInsets.symmetric(vertical: 6),
  decoration: card(),
  child: Column(
    children: [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0 && dividers)
          const Divider(height: 1, indent: 70, endIndent: 14, color: K.line),
        rows[i],
      ],
    ],
  ),
);

/// Bottom sheet shell.
Widget sheet({
  required String title,
  String? sub,
  required List<Widget> children,
}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
  decoration: const BoxDecoration(
    color: K.bg,
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: K.line,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
      gap(14),
      Text(title, style: tx(22, w: bold)),
      if (sub != null) Text(sub, style: tx(14, c: K.muted)),
      gap(16),
      ...children,
    ],
  ),
);

/// Large input look-alike.
Widget field(
  String label,
  String value, {
  bool big = false,
  IconData? icon,
  bool focused = false,
  String? suffix,
}) => Container(
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: focused ? K.teal : K.line,
      width: focused ? 2 : 1,
    ),
  ),
  child: Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 20, color: K.muted),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tx(12.5, c: K.muted)),
            Text(value, style: tx(big ? 28 : 17, w: bold)),
          ],
        ),
      ),
      if (suffix != null)
        Text(
          suffix,
          style: tx(15, w: bold, c: K.muted),
        ),
    ],
  ),
);

/// The wordmark: اعّرست with a saffron dot.
Widget wordmark({double s = 40, Color c = K.teal}) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'اعّرست',
      style: tx(s, w: bold, c: c, h: 1.1),
    ),
    Padding(
      padding: EdgeInsets.only(top: s * 0.12),
      child: dot(K.saffron, s * 0.22),
    ),
  ],
);

/// Onboarding question scaffold: progress, question, body, primary.
Widget questionScreen({
  required int step,
  required String q,
  String? help,
  required List<Widget> body,
  String primary = 'التالي',
  String? skip,
}) => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: Column(
      children: [
        btn(primary, wide: true, v: 16, fs: 17),
        if (skip != null) ...[
          gap(12),
          Text(
            skip,
            style: tx(15, w: bold, c: K.muted),
          ),
        ],
      ],
    ),
  ),
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.arrowRight, size: 20, color: K.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: segments(4, step, now: K.teal, on: K.teal),
          ),
          const SizedBox(width: 14),
          Text(
            '${step + 1} من 4',
            style: tx(14, w: bold, c: K.muted),
          ),
        ],
      ),
    ),
    gap(34),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(q, style: tx(30, w: bold, h: 1.25)),
    ),
    if (help != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
        child: Text(help, style: tx(16, c: K.muted)),
      ),
    gap(26),
    ...body,
  ],
);
