// Admin prototype: a desktop frame for the back office (admin-web). Neutral
// slate like the provider side; status colours keep their meaning.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

class A {
  static const c = Color(0xFF2E3B43);
  static const dark = Color(0xFF1C262C);
  static const soft = Color(0xFFE6EBED);
}

enum ASec {
  today('اليوم', LucideIcons.layoutDashboard),
  joins('الانضمام', LucideIcons.userPlus),
  verify('التوثيق', LucideIcons.badgeCheck),
  reports('البلاغات', LucideIcons.flag),
  deposits('خلافات الدفعات', LucideIcons.scale),
  listings('ملفات الدليل', LucideIcons.bookOpen),
  categories('الأقسام', LucideIcons.layoutGrid),
  support('الدعم', LucideIcons.lifeBuoy),
  settings('الإعدادات', LucideIcons.settings),
  log('السجل', LucideIcons.history);

  const ASec(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _counts = {ASec.joins: 12, ASec.verify: 6, ASec.reports: 3, ASec.deposits: 2};

Widget desk(ASec active, {required String title, String? sub, List<Widget> actions = const [], required List<Widget> body}) =>
    Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: K.bg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 236,
              color: A.dark,
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [wordmark(s: 24, c: Colors.white), const SizedBox(width: 8), Text('الإدارة', style: tx(14, c: Colors.white60))])),
                  gap(24),
                  for (final s in ASec.values)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: s == active ? Colors.white12 : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(s.icon, size: 18, color: s == active ? Colors.white : Colors.white60),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.label, style: tx(14.5, w: s == active ? bold : FontWeight.w400, c: s == active ? Colors.white : Colors.white70))),
                          if (_counts[s] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                              decoration: BoxDecoration(color: s == ASec.reports || s == ASec.deposits ? K.coral : Colors.white24, borderRadius: BorderRadius.circular(9)),
                              child: Text('${_counts[s]}', style: tx(12, w: bold, c: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  Row(children: [avatar('ر', K.saffron, s: 34), const SizedBox(width: 10), Text('رشاد · مدير', style: tx(13.5, c: Colors.white70))]),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 26, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(title, style: tx(28, w: bold)), if (sub != null) Text(sub, style: tx(15, c: K.muted))],
                          ),
                        ),
                        for (final a in actions) ...[const SizedBox(width: 10), a],
                      ],
                    ),
                    gap(20),
                    ...body,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

Widget panel({required Widget child, EdgeInsets pad = const EdgeInsets.all(18), Color c = Colors.white, Color? border}) => Container(
  padding: pad,
  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18), border: border == null ? null : Border.all(color: border, width: 2)),
  child: child,
);

Widget aBtn(String s, {Color bg = A.c, Color fg = Colors.white, IconData? icon}) => btn(s, bg: bg, fg: fg, icon: icon, v: 11, fs: 14.5);

/// A table: header row then rows of cells with flex weights.
Widget table(List<(String, int)> head, List<List<Widget>> rows, {int? hi}) => panel(
  pad: const EdgeInsets.symmetric(vertical: 6),
  child: Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(children: [for (final h in head) Expanded(flex: h.$2, child: Text(h.$1, style: tx(13, w: bold, c: K.muted)))]),
      ),
      for (var i = 0; i < rows.length; i++) ...[
        const Divider(height: 1, color: K.line),
        Container(
          color: i == hi ? A.soft : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(children: [for (var j = 0; j < head.length; j++) Expanded(flex: head[j].$2, child: Align(alignment: Alignment.centerRight, child: rows[i][j]))]),
        ),
      ],
    ],
  ),
);

Widget t(String s, {bool b = false, Color c = K.ink, double fs = 14.5}) => Text(s, style: tx(fs, w: b ? bold : FontWeight.w400, c: c));
Widget t2(String a, String b) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a, style: tx(14.5, w: bold)), Text(b, style: tx(12.5, c: K.muted))]);
