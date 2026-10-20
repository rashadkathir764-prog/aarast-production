// Admin prototype: the existing admin-web shell (admin-web/src/layout), kept
// as it is — the same nav groups and order, the four admin roles, the
// breadcrumb topbar — with what the audit found missing: the admin's real
// role shown, a queue count per link, in the groom journey's teal.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

class A {
  static const c = Color(0xFF0B6E69);
  static const dark = Color(0xFF064B47);
  static const soft = Color(0xFFDCEFEC);
}

enum Role { superAdmin, operations, moderator, support }

const roleLabel = {
  Role.superAdmin: 'مدير أعلى',
  Role.operations: 'تشغيل',
  Role.moderator: 'إشراف محتوى',
  Role.support: 'دعم',
};

/// One nav link; [roles] is who sees it, from admin-permissions.ts.
class L {
  const L(this.id, this.label, this.icon, this.roles, {this.count, this.isNew = false, this.hot = false, this.v11 = false});
  final String id, label;
  final IconData icon;
  final Set<Role> roles;
  final int? count;
  final bool isNew, hot, v11;
}

const _all = {Role.superAdmin, Role.operations, Role.moderator, Role.support};
const _ops = {Role.superAdmin, Role.operations};
const _opsSup = {Role.superAdmin, Role.operations, Role.support};
const _mod = {Role.superAdmin, Role.moderator};
const _modOps = {Role.superAdmin, Role.operations, Role.moderator};
const _sa = {Role.superAdmin};

// Seven sections: the existing pages keep their place inside them; new
// links are marked «جديد» (first version) or «1.1».
const nav = <(String, List<L>)>[
  ('اليوم', [
    L('inbox', 'الصندوق', LucideIcons.inbox, _all, count: 23, isNew: true, hot: true),
  ]),
  ('السوق', [
    L('market', 'نظرة السوق', LucideIcons.activity, _ops, v11: true),
    L('funnel', 'مسار العريس', LucideIcons.filter, _ops, v11: true),
    L('calendar', 'تقويم الأعراس', LucideIcons.calendarDays, _ops, v11: true),
    L('reports', 'التقارير', LucideIcons.barChart3, _ops),
  ]),
  ('المزودين', [
    L('apps', 'طلبات الانضمام', LucideIcons.userPlus, _all, count: 12),
    L('providers', 'دليل المزودين', LucideIcons.store, _all),
    L('listed', 'ملفات بلا حساب', LucideIcons.bookOpen, _opsSup, isNew: true),
    L('services', 'الخدمات', LucideIcons.package, _opsSup),
  ]),
  ('الناس', [
    L('lookup', 'ابحث برقم', LucideIcons.search, _opsSup, isNew: true),
    L('users', 'المستخدمون', LucideIcons.users, _opsSup),
    L('datareq', 'طلبات البيانات', LucideIcons.fileLock, _opsSup, count: 3, isNew: true),
  ]),
  ('الرقابة', [
    L('reports_c', 'البلاغات', LucideIcons.flag, _mod, count: 3, hot: true),
    L('reviews', 'التقييمات', LucideIcons.star, _modOps, count: 5),
    L('photos', 'صور تحتاج مراجعة', LucideIcons.eyeOff, _mod, count: 4, isNew: true),
    L('bookings', 'الحجوزات والخلافات', LucideIcons.scale, _opsSup, count: 2, isNew: true, hot: true),
    L('fraud', 'إشارات الاحتيال', LucideIcons.shieldAlert, _modOps, v11: true),
  ]),
  ('النظام', [
    L('health', 'صحة المنصة', LucideIcons.heartPulse, _ops, isNew: true),
    L('settings', 'القواعد', LucideIcons.slidersHorizontal, _sa, isNew: true),
    L('catalog', 'الكتالوج', LucideIcons.layoutGrid, _opsSup),
    L('flags', 'الميزات والإعلانات', LucideIcons.toggleRight, _sa, v11: true),
  ]),
  ('الفريق', [
    L('team', 'الأعضاء والأدوار', LucideIcons.shieldCheck, _sa, isNew: true),
    L('audit', 'سجل التدقيق', LucideIcons.history, _sa),
  ]),
];

Widget desk(
  String active, {
  required String crumb,
  required String title,
  String? sub,
  Role role = Role.operations,
  String who = 'نادية',
  List<Widget> actions = const [],
  required List<Widget> body,
}) => Directionality(
  textDirection: TextDirection.rtl,
  child: Container(
    color: K.bg,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 248,
          color: A.dark,
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [wordmark(s: 22, c: Colors.white), const SizedBox(width: 8), Text('لوحة الإدارة', style: tx(13, c: Colors.white60))]),
              ),
              gap(14),
              for (final g in nav)
                if (g.$2.any((l) => l.roles.contains(role))) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                    child: Text(g.$1, style: tx(11.5, w: bold, c: Colors.white38)),
                  ),
                  for (final l in g.$2)
                    if (l.roles.contains(role))
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: l.id == active ? Colors.white12 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Icon(l.icon, size: 17, color: l.id == active ? Colors.white : Colors.white60),
                            const SizedBox(width: 10),
                            Expanded(child: Text(l.label, style: tx(13.5, w: l.id == active ? bold : FontWeight.w400, c: l.id == active ? Colors.white : Colors.white70))),
                            if (l.isNew) Padding(padding: const EdgeInsets.only(left: 6), child: Text('جديد', style: tx(10.5, w: bold, c: K.saffron))),
                            if (l.v11) Padding(padding: const EdgeInsets.only(left: 6), child: Text('1.1', style: tx(10.5, w: bold, c: Colors.white38))),
                            if (l.count != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7),
                                decoration: BoxDecoration(color: l.hot ? K.coral : Colors.white24, borderRadius: BorderRadius.circular(9)),
                                child: Text('${l.count}', style: tx(11.5, w: bold, c: Colors.white)),
                              ),
                          ],
                        ),
                      ),
                ],
              const Spacer(),
              Row(children: [
                avatar(who.characters.first, K.saffron, s: 32),
                const SizedBox(width: 10),
                Expanded(child: Text(who, style: tx(13.5, w: bold, c: Colors.white))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                  child: Text(roleLabel[role]!, style: tx(11.5, w: bold, c: Colors.white70)),
                ),
              ]),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 18, 30, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text('لوحة الإدارة / $crumb', style: tx(12.5, c: K.muted)),
                  const Spacer(),
                  Container(
                    width: 260,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: K.line)),
                    child: Row(children: [const Icon(LucideIcons.search, size: 16, color: K.muted), const SizedBox(width: 8), Text('ابحث برقم أو اسم…', style: tx(13, c: K.faint))]),
                  ),
                ]),
                gap(14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(title, style: tx(26, w: bold)), if (sub != null) Text(sub, style: tx(14, c: K.muted))],
                      ),
                    ),
                    for (final a in actions) ...[const SizedBox(width: 10), a],
                  ],
                ),
                gap(16),
                ...body,
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

Widget panel({required Widget child, EdgeInsets pad = const EdgeInsets.all(16), Color c = Colors.white, Color? border}) => Container(
  padding: pad,
  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16), border: border == null ? null : Border.all(color: border, width: 2)),
  child: child,
);

Widget aBtn(String s, {Color bg = A.c, Color fg = Colors.white, IconData? icon}) => btn(s, bg: bg, fg: fg, icon: icon, v: 10, fs: 14);

Widget table(List<(String, int)> head, List<List<Widget>> rows, {int? hi}) => panel(
  pad: const EdgeInsets.symmetric(vertical: 4),
  child: Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [for (final h in head) Expanded(flex: h.$2, child: Text(h.$1, style: tx(12.5, w: bold, c: K.muted)))]),
      ),
      for (var i = 0; i < rows.length; i++) ...[
        const Divider(height: 1, color: K.line),
        Container(
          color: i == hi ? A.soft : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [for (var j = 0; j < head.length; j++) Expanded(flex: head[j].$2, child: Align(alignment: Alignment.centerRight, child: rows[i][j]))]),
        ),
      ],
    ],
  ),
);

Widget t(String s, {bool b = false, Color c = K.ink, double fs = 14}) => Text(s, style: tx(fs, w: b ? bold : FontWeight.w400, c: c));
Widget t2(String a, String b) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [Text(a, style: tx(14, w: bold)), Text(b, style: tx(12, c: K.muted))],
);

Widget stat(String n, String l, {Color c = K.ink, String? sub}) => Expanded(
  child: panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(n, style: tx(24, w: bold, c: c)), Text(l, style: tx(13.5, w: bold)), if (sub != null) Text(sub, style: tx(12, c: K.muted))],
    ),
  ),
);

Widget chk(bool ok, String s) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(children: [
    Icon(ok ? LucideIcons.checkCircle2 : LucideIcons.alertCircle, size: 17, color: ok ? K.green : K.coral),
    const SizedBox(width: 8),
    Expanded(child: t(s, fs: 13.5)),
  ]),
);

/// A confirmation dialog laid over a page: what will happen, and a reason.
Widget confirm(Widget page, {required String title, required List<String> effects, String? reasonLabel, required String go, Color goC = A.c}) => Stack(
  children: [
    page,
    Positioned.fill(child: Container(color: K.ink.withValues(alpha: 0.42))),
    Center(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: tx(20, w: bold)),
              gap(10),
              for (final e in effects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(padding: EdgeInsets.only(top: 7), child: Icon(LucideIcons.dot, size: 14, color: K.muted)),
                    Expanded(child: t(e, fs: 14)),
                  ]),
                ),
              if (reasonLabel != null) ...[
                gap(10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: A.c, width: 2)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    t(reasonLabel, c: K.muted, fs: 12),
                    t('3 بلاغات تأخير تسليم خلال شهرين', b: true),
                  ]),
                ),
              ],
              gap(16),
              Row(children: [aBtn(go, bg: goC), const SizedBox(width: 10), aBtn('تراجع', bg: A.soft, fg: A.c)]),
            ],
          ),
        ),
      ),
    ),
  ],
);
